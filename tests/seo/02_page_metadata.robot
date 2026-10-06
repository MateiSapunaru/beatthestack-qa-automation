*** Settings ***
Documentation       Per-route document metadata: title, description, canonical
...                 URL, Open Graph, Twitter card and JSON-LD.
...
...                 All of it is applied client-side after the route renders.
...                 Google executes JavaScript, so this indexes correctly —
...                 but social scrapers generally do not, which means link
...                 previews fall back to the static metadata in index.html.
...                 These tests therefore describe what a crawler that runs
...                 JavaScript sees; the scraper gap is recorded in the README
...                 as a limitation of the approach rather than a defect in
...                 its implementation.

Library             Collections
Resource            ../../resources/pages/common.robot
Resource            ../../resources/pages/blog_page.robot
Resource            ../../resources/pages/work_page.robot

Suite Setup         Start Browser Session
Test Teardown       Close Page Session

Test Tags           seo    metadata


*** Variables ***
${SITE_NAME}                    Beat The Stack
${DEFAULT_TITLE}                Beat The Stack — Backend engineering and infrastructure
${DEFAULT_IMAGE}                ${BASE_URL}/brand_large.png

${OG_TITLE}                     css=head meta[property="og:title"]
${OG_DESCRIPTION}               css=head meta[property="og:description"]
${OG_URL}                       css=head meta[property="og:url"]
${OG_TYPE}                      css=head meta[property="og:type"]
${OG_IMAGE}                     css=head meta[property="og:image"]
${OG_SITE_NAME}                 css=head meta[property="og:site_name"]
${TWITTER_CARD}                 css=head meta[name="twitter:card"]
${TWITTER_TITLE}                css=head meta[name="twitter:title"]
${TWITTER_IMAGE}                css=head meta[name="twitter:image"]


*** Test Cases ***
Each Route Publishes Its Own Title And Canonical Url
    [Documentation]    Without this every route shares the one static title
    ...    from index.html, and every page competes with itself
    ...    for the same search result.
    [Tags]    smoke
    [Template]    Route Metadata Should Be
    /    ${DEFAULT_TITLE}    ${BASE_URL}/
    /work    Who am I — ${SITE_NAME}    ${BASE_URL}/work
    /blog    Blog — ${SITE_NAME}    ${BASE_URL}/blog

Each Route Publishes A Distinct Description
    [Documentation]    Duplicate descriptions across routes are treated as a
    ...    signal that the pages are duplicates.
    ${descriptions}=    Create List
    FOR    ${route}    IN    /    /work    /blog
        Open Page At    ${route}
        ${description}=    Get Meta Content    ${META_DESCRIPTION}
        Should Not Be Equal    ${description}    ${NONE}
        ...    msg=Route '${route}' publishes no meta description
        ${length}=    Get Length    ${description}
        Should Be True    50 <= ${length} <= 320
        ...    msg=Route '${route}' has a ${length}-character description, outside the useful range
        Append To List    ${descriptions}    ${description}
    END
    ${unique}=    Remove Duplicates    ${descriptions}
    Lists Should Be Equal    ${descriptions}    ${unique}
    ...    msg=Routes share a meta description: ${descriptions}

Public Routes Are Left Indexable
    [Template]    Route Should Be Indexable
    /
    /work
    /blog

Open Graph Tags Are Complete On Every Public Route
    [Documentation]    A missing og:image or og:url turns a shared link into a
    ...    bare text post. All five are required for a card.
    [Template]    Open Graph Should Be Complete
    /
    /work
    /blog

Twitter Card Tags Are Complete On Every Public Route
    [Template]    Twitter Card Should Be Complete
    /
    /work
    /blog

Open Graph Url Agrees With The Canonical Url
    [Documentation]    Two different answers to "what is this page's address"
    ...    is how a shared link and an indexed link end up as
    ...    separate entries for the same content.
    [Template]    Open Graph Url Should Match Canonical
    /
    /work
    /blog

Landing Page Publishes Website Structured Data
    Open Page At    /
    ${data}=    Get Structured Data
    Should Be Equal    ${data}[@type]    WebSite
    Should Be Equal    ${data}[@context]    https://schema.org
    Should Be Equal    ${data}[name]    ${SITE_NAME}
    Should Be Equal    ${data}[url]    ${BASE_URL}

Structured Data Does Not Survive Into A Route Without Any
    [Documentation]    The JSON-LD block is replaced per route. If a stale one
    ...    lingered, /work would describe itself with the
    ...    landing page's markup.
    Open Page At    /
    ${count}=    Get Element Count    ${JSON_LD}
    Should Be Equal As Integers    ${count}    1
    Navigate Via Header To    ${NAV_WORK}    /work
    Wait Until Keyword Succeeds    5x    0.5s    Structured Data Should Be Absent

Canonical Url Ignores Query Strings And Trailing Noise
    [Documentation]    Canonical URLs are built from pinned configuration and
    ...    the route, never from `window.location`. A tracking
    ...    parameter must not create a second canonical URL for
    ...    the same page.
    [Tags]    security
    Open Page At Raw Url    /blog?utm_source=newsletter&utm_campaign=test
    Blog Listing Should Be Loaded
    Canonical Url Should Be    ${BASE_URL}/blog

Metadata Survives A Client Side Navigation
    [Documentation]    Metadata is applied by an effect on route change, so a
    ...    client-side navigation has to update it as thoroughly
    ...    as a cold load. Stale metadata after an in-app click
    ...    is the characteristic single-page-app failure.
    Open Page At    /
    Page Title Should Be    ${DEFAULT_TITLE}
    Navigate Via Header To    ${NAV_BLOG}    /blog
    Wait Until Keyword Succeeds    5x    0.5s    Page Title Should Be    Blog — ${SITE_NAME}
    Canonical Url Should Be    ${BASE_URL}/blog
    Navigate Via Header To    ${NAV_WORK}    /work
    Wait Until Keyword Succeeds    5x    0.5s    Page Title Should Be    Who am I — ${SITE_NAME}
    Canonical Url Should Be    ${BASE_URL}/work


*** Keywords ***
Route Metadata Should Be
    [Arguments]    ${route}    ${expected_title}    ${expected_canonical}
    Open Page At    ${route}
    Page Title Should Be    ${expected_title}
    Canonical Url Should Be    ${expected_canonical}

Route Should Be Indexable
    [Arguments]    ${route}
    Open Page At    ${route}
    Page Should Be Indexable

Open Graph Should Be Complete
    [Arguments]    ${route}
    Open Page At    ${route}
    FOR    ${selector}    IN    ${OG_TITLE}    ${OG_DESCRIPTION}    ${OG_URL}    ${OG_TYPE}
    ...    ${OG_IMAGE}    ${OG_SITE_NAME}
        ${content}=    Get Meta Content    ${selector}
        Should Not Be Equal    ${content}    ${NONE}
        ...    msg=Route '${route}' is missing '${selector}'
        Should Not Be Empty    ${content}    msg=Route '${route}' has an empty '${selector}'
    END
    ${declared_site_name}=    Get Meta Content    ${OG_SITE_NAME}
    Should Be Equal    ${declared_site_name}    ${SITE_NAME}
    # Absolute, because a scraper resolves og:image without a base URL. The
    # static routes all fall back to the brand image.
    ${image}=    Get Meta Content    ${OG_IMAGE}
    Should Be Equal    ${image}    ${DEFAULT_IMAGE}
    ...    msg=Route '${route}' declares og:image '${image}' instead of the absolute default

Twitter Card Should Be Complete
    [Arguments]    ${route}
    Open Page At    ${route}
    ${card}=    Get Meta Content    ${TWITTER_CARD}
    Should Be Equal    ${card}    summary_large_image
    FOR    ${selector}    IN    ${TWITTER_TITLE}    ${TWITTER_IMAGE}
        ${content}=    Get Meta Content    ${selector}
        Should Not Be Empty    ${content}    msg=Route '${route}' is missing '${selector}'
    END

Open Graph Url Should Match Canonical
    [Arguments]    ${route}
    Open Page At    ${route}
    ${canonical}=    Get Attribute    ${CANONICAL_LINK}    href
    ${og_url}=    Get Meta Content    ${OG_URL}
    Should Be Equal    ${og_url}    ${canonical}
    ...    msg=Route '${route}': og:url is '${og_url}' but the canonical is '${canonical}'

Structured Data Should Be Absent
    ${count}=    Get Element Count    ${JSON_LD}
    Should Be Equal As Integers    ${count}    0
    ...    msg=A JSON-LD block from the previous route is still in the document
