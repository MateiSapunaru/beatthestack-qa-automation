*** Settings ***
Documentation       Content and structure of the two static pages: the landing
...                 page and the experience timeline. Everything here is
...                 rendered from code rather than from the API, so these are
...                 the assertions that can safely be exact.

Resource            ../../resources/pages/common.robot
Resource            ../../resources/pages/home_page.robot
Resource            ../../resources/pages/work_page.robot

Suite Setup         Start Browser Session
Test Teardown       Close Page Session

Test Tags           ui    content


*** Test Cases ***
Landing Page Renders Every Hero Element
    [Tags]    smoke
    Open Home Page
    Home Page Should Be Rendered
    ${description}=    Get Text    ${HERO_DESCRIPTION}
    Should Contain    ${description}    distributed systems
    Should Contain    ${description}    Backend/DevOps engineer

Landing Page Headline Is The Only Top Level Heading
    [Documentation]    One <h1> per document, carrying the page's subject.
    Open Home Page
    Page Should Have Exactly One H1
    ${h1}=    Get Text    ${H1}
    Should Be Equal    ${h1}    ${EXPECTED_HERO_TITLE}

Landing Page Calls To Action Carry Their Labels
    Open Home Page
    ${primary}=    Get Text    ${CTA_PRIMARY}
    Should Be Equal    ${primary}    What I've Shipped
    ${secondary}=    Get Text    ${CTA_SECONDARY}
    Should Be Equal    ${secondary}    Read the Deep Dives

Landing Page Social Links Open Off Site Safely
    [Documentation]    A link to another origin that opens in a new tab needs
    ...    rel="noopener": without it the destination gets a
    ...    handle on this window through `window.opener`.
    Open Home Page
    Wait For Elements State    ${SOCIAL_LINKS}    visible    ${TIMEOUT}
    ${count}=    Get Element Count    ${SOCIAL_LINK}
    Should Be True    ${count} > 0    msg=No social links rendered
    ${unsafe}=    Evaluate JavaScript    ${NONE}
    ...    () => Array.from(document.querySelectorAll('.social-links a.social-link')).filter((a) => a.target === '_blank' && !a.rel.includes('noopener')).map((a) => a.href)
    Should Be Empty    ${unsafe}    msg=Links open a new tab without rel=noopener: ${unsafe}

Landing Page Images Actually Load
    [Documentation]    An <img> that 404s still satisfies "is visible", so the
    ...    decoded dimensions are what prove the asset arrived.
    Open Home Page
    Wait Until Images Have Loaded    section.hero img

Work Page Renders The Experience Timeline
    [Tags]    smoke
    Open Work Page
    Work Page Should Be Rendered

Work Page Timeline Entries Are Complete
    Open Work Page
    Every Timeline Entry Should Be Complete

Work Page Marks Exactly One Entry As Current
    [Documentation]    The timeline highlights the present role. Two highlights
    ...    or none is a data defect that no amount of CSS shows.
    Open Work Page
    ${current}=    Get Element Count    ${TIMELINE_CURRENT_ENTRY}
    Should Be Equal As Integers    ${current}    1
    ...    msg=Expected exactly one current timeline entry, found ${current}

Work Page Has A Top Level Heading
    [Documentation]    *Known defect — see README, finding BTS-1.*
    ...
    ...    /work renders no <h1> at all: its first heading is the
    ...    <h2> "A sneak peek into my past achievments". That
    ...    breaks the heading hierarchy a screen reader navigates
    ...    by (WCAG 2.1 SC 1.3.1) and leaves the page without the
    ...    one element search engines weigh most heavily — even
    ...    though the route does set a document title.
    ...
    ...    The test is kept and tagged `robot:skip-on-failure`, so
    ...    it reports as skipped instead of failing the run while
    ...    the defect is open, and flips to a genuine pass the
    ...    moment an <h1> is added.
    [Tags]    accessibility    seo    known-issue    robot:skip-on-failure
    Open Work Page
    # Counted directly rather than through `Page Should Have Exactly One H1`:
    # that keyword waits for a heading to appear, which here means burning the
    # full timeout to report "zero" as a timeout instead of as a count.
    ${count}=    Get Element Count    ${H1}
    Should Be Equal As Integers    ${count}    1
    ...    msg=/work renders ${count} <h1> element(s); its first heading is the <h2> "${TIMELINE_TITLE_TEXT}"

Heading Hierarchy Should Not Skip A Level
    [Documentation]    *Known defect — see README, finding BTS-1.*
    ...
    ...    Same root cause as above, stated as the rule it breaks:
    ...    the first heading on a page must be an <h1>, and levels
    ...    must not jump on the way down.
    [Tags]    accessibility    known-issue    robot:skip-on-failure
    Open Work Page
    ${levels}=    Evaluate JavaScript    ${NONE}
    ...    () => Array.from(document.querySelectorAll('h1,h2,h3,h4,h5,h6')).map((h) => Number(h.tagName[1]))
    Should Not Be Empty    ${levels}    msg=The page renders no headings at all
    Should Be Equal As Integers    ${levels}[0]    1
    ...    msg=The first heading on the page is an h${levels}[0], not an h1
    ${skips}=    Evaluate
    ...    [(a, b) for a, b in zip($levels, $levels[1:]) if b - a > 1]
    Should Be Empty    ${skips}    msg=Heading levels jump by more than one: ${skips}
