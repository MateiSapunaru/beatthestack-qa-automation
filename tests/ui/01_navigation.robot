*** Settings ***
Documentation       Routing and navigation.
...
...                 The site ships a hand-written history router instead of a
...                 routing library, so the behaviour a library would provide
...                 for free is exactly what needs covering: real hrefs, the
...                 browser's own back and forward buttons, cold loads of deep
...                 links, and the redirect that keeps pre-existing hash links
...                 alive.

Resource            ../../resources/config/test_data.robot
Resource            ../../resources/pages/common.robot
Resource            ../../resources/pages/home_page.robot
Resource            ../../resources/pages/blog_page.robot

Suite Setup         Start Browser Session
Test Teardown       Close Page Session

Test Tags           ui    navigation


*** Variables ***
# A bare "#" starts a comment in Robot Framework, so the fragment character
# has to be escaped once here and referenced everywhere else.
${HASH}                         \#


*** Test Cases ***
Landing Page Loads With Its Hero
    [Documentation]    The smoke test: if this fails, nothing else matters.
    [Tags]    smoke
    Open Home Page
    Home Page Should Be Rendered
    ${title}=    Get Hero Title
    Should Be Equal    ${title}    ${EXPECTED_HERO_TITLE}

Header Links Navigate To Work And Blog
    [Tags]    smoke
    Open Home Page
    Navigate Via Header To    ${NAV_WORK}    /work
    Active Nav Link Should Be    Who am I
    Navigate Via Header To    ${NAV_BLOG}    /blog
    Active Nav Link Should Be    Blog

Logo Returns To The Landing Page
    Open Blog Page
    Click    ${LOGO_LINK}
    Wait Until Keyword Succeeds    5x    0.5s    Current Path Should Be    /
    Home Page Should Be Rendered

Header Navigation Links Expose Real Hrefs
    [Documentation]    Client-side navigation must not cost the site its
    ...    crawlable links: a crawler reads `href`, never a click
    ...    handler, and middle-click depends on it too.
    Open Home Page
    ${work_href}=    Get Property    ${NAV_WORK}    pathname
    Should Be Equal    ${work_href}    /work
    ${blog_href}=    Get Property    ${NAV_BLOG}    pathname
    Should Be Equal    ${blog_href}    /blog

Landing Page Calls To Action Link To Work And Blog
    Open Home Page
    Cta Should Link To    ${CTA_PRIMARY}    /work
    Cta Should Link To    ${CTA_SECONDARY}    /blog
    Click    ${CTA_SECONDARY}
    Wait Until Keyword Succeeds    5x    0.5s    Current Path Should Be    /blog
    Blog Listing Should Be Loaded

Browser Back And Forward Follow The Route
    [Documentation]    A hand-rolled router has to listen for `popstate`
    ...    itself. Without that the URL changes while the view
    ...    stays put — the defect this test exists for.
    Open Home Page
    Navigate Via Header To    ${NAV_BLOG}    /blog
    Go Back
    Wait Until Keyword Succeeds    5x    0.5s    Current Path Should Be    /
    Home Page Should Be Rendered
    Go Forward
    Wait Until Keyword Succeeds    5x    0.5s    Current Path Should Be    /blog
    Blog Listing Should Be Loaded

Every Public Route Survives A Cold Load
    [Documentation]    Loading a deep link directly exercises the rewrite that
    ...    serves index.html for extensionless paths. Without it
    ...    these URLs 404 for anyone arriving from a search result
    ...    or a shared link.
    [Tags]    smoke
    FOR    ${route}    IN    @{PUBLIC_ROUTES}
        Open Page At    ${route}
        Current Path Should Be    ${route}
        Wait For Elements State    ${HEADER}    visible    ${TIMEOUT}
        ${not_found}=    Get Element Count    css=.not-found-page
        Should Be Equal As Integers    ${not_found}    0
        ...    msg=A cold load of '${route}' rendered the not-found view
    END

Legacy Hash Links Redirect To Their Path Equivalents
    [Documentation]    The site used to route on the fragment (#/blog/slug).
    ...    Fragments never reach the server, so those URLs were
    ...    invisible to crawlers; links shared while they were
    ...    live still have to land somewhere canonical.
    [Template]    Legacy Hash Should Redirect To
    \#work    /work
    \#/work    /work
    \#/blog    /blog

Unrecognised Legacy Hash Falls Back To The Landing Page
    Open Page At Raw Url    /${HASH}/not-a-real-route
    Wait Until Keyword Succeeds    5x    0.5s    Current Path Should Be    /
    Home Page Should Be Rendered

A New Route Starts At The Top Of The Page
    [Documentation]    Scroll position is per-document in a single-page app, so
    ...    it has to be reset deliberately or the next page opens
    ...    halfway down.
    Open Blog Page
    Scroll To    ${NONE}    bottom
    ${before}=    Evaluate JavaScript    ${NONE}    () => window.scrollY
    Should Be True    ${before} > 0    msg=The page could not be scrolled, so the test proves nothing
    Click    ${LOGO_LINK}
    Wait Until Keyword Succeeds    5x    0.5s    Current Path Should Be    /
    Wait Until Keyword Succeeds    5x    0.5s    Scroll Position Should Be At Top


*** Keywords ***
Legacy Hash Should Redirect To
    [Arguments]    ${fragment}    ${expected_path}
    Open Page At Raw Url    /${fragment}
    Wait Until Keyword Succeeds    5x    0.5s    Current Path Should Be    ${expected_path}
    ${url}=    Get Url
    Should Not Contain    ${url}    ${HASH}    msg=The fragment survived the redirect: ${url}

Scroll Position Should Be At Top
    ${position}=    Evaluate JavaScript    ${NONE}    () => window.scrollY
    Should Be True    ${position} <= 1    msg=The new route opened ${position}px down the page
