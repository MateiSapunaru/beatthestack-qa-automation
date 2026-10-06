*** Settings ***
Documentation       Browser lifecycle plus the site chrome (header, navigation)
...                 and the document-level assertions every page shares.
...
...                 One browser process per suite, one fresh context per test:
...                 contexts are cheap and isolated, so tests never inherit
...                 each other's cookies, storage or scroll position.

Library             Collections
Library             String
Library             Browser
Resource            ../config/environments.robot


*** Variables ***
# --- Site chrome -------------------------------------------------------------
${HEADER}                       css=header.header
${LOGO_LINK}                    css=header.header a.logo
${NAV}                          css=header.header nav.nav
${NAV_LINKS}                    css=header.header a.nav-link
${NAV_WORK}                     css=header.header a.nav-link:text-is("Who am I")
${NAV_BLOG}                     css=header.header a.nav-link:text-is("Blog")
${ACTIVE_NAV_LINK}              css=header.header a.nav-link.active

# --- Document metadata -------------------------------------------------------
${CANONICAL_LINK}               css=head link[rel="canonical"]
${META_DESCRIPTION}             css=head meta[name="description"]
${META_ROBOTS}                  css=head meta[name="robots"]
${JSON_LD}                      css=head script#seo-structured-data
${H1}                           css=h1


*** Keywords ***
# =============================================================================
# Lifecycle
# =============================================================================

Start Browser Session
    [Documentation]    Suite setup. Starts one browser for the whole suite.
    New Browser    ${BROWSER}    headless=${HEADLESS}
    Set Browser Timeout    ${TIMEOUT}

Open Page At
    [Documentation]    Opens ${path} in a clean context. A cold load like this
    ...    is also what proves deep links work: the request is
    ...    served from the origin, not by the client-side router.
    [Arguments]    ${path}=${EMPTY}    ${width}=${DESKTOP_WIDTH}    ${height}=${DESKTOP_HEIGHT}
    ${viewport}=    Create Dictionary    width=${width}    height=${height}
    New Context    viewport=${viewport}
    New Page    ${BASE_URL}${path}
    Wait For Elements State    ${HEADER}    visible    ${TIMEOUT}

Open Page At Raw Url
    [Documentation]    Same as `Open Page At` but without waiting for the
    ...    header, for URLs that are expected to be rejected.
    [Arguments]    ${path}    ${width}=${DESKTOP_WIDTH}    ${height}=${DESKTOP_HEIGHT}
    ${viewport}=    Create Dictionary    width=${width}    height=${height}
    New Context    viewport=${viewport}
    New Page    ${BASE_URL}${path}

Close Page Session
    [Documentation]    Test teardown. Captures evidence before throwing the
    ...    context away, so a CI failure arrives with a screenshot.
    ...
    ...    The screenshot is guarded because a test that failed
    ...    while navigating may have no page left to photograph,
    ...    and an exploding teardown would mask the real failure.
    ...    Closing ALL contexts keeps tests that open several (a
    ...    loop over routes, a viewport matrix) from leaking any.
    Run Keyword And Ignore Error
    ...    Run Keyword If Test Failed    Take Screenshot    fullPage=${TRUE}
    Close Context    ALL

# =============================================================================
# Navigation
# =============================================================================

Current Path Should Be
    [Documentation]    Compares only the path component: query strings and the
    ...    host are irrelevant to routing assertions.
    [Arguments]    ${expected}
    ${url}=    Get Url
    ${path}=    Evaluate    urllib.parse.urlsplit($url).path    modules=urllib.parse
    Should Be Equal    ${path}    ${expected}
    ...    msg=Expected to be on '${expected}' but the browser is on '${url}'

Navigate Via Header To
    [Documentation]    Clicks a header link and waits for the route to settle.
    [Arguments]    ${link}    ${expected_path}
    Click    ${link}
    Wait Until Keyword Succeeds    5x    0.5s    Current Path Should Be    ${expected_path}

Active Nav Link Should Be
    [Arguments]    ${expected_text}
    ${text}=    Get Text    ${ACTIVE_NAV_LINK}
    Should Be Equal    ${text}    ${expected_text}
    # aria-current is what a screen reader actually announces, so the visual
    # highlight alone is not enough.
    ${aria}=    Get Attribute    ${ACTIVE_NAV_LINK}    aria-current
    Should Be Equal    ${aria}    page

# =============================================================================
# Document metadata
# =============================================================================

Page Title Should Be
    [Arguments]    ${expected}
    ${title}=    Get Title
    Should Be Equal    ${title}    ${expected}

Page Title Should Contain
    [Arguments]    ${expected}
    ${title}=    Get Title
    Should Contain    ${title}    ${expected}

Get Meta Content
    [Documentation]    Returns the `content` of a <meta> tag, or ${NONE} when
    ...    the tag is absent — the application removes `robots`
    ...    rather than setting it to `index`, so absence is meaningful.
    [Arguments]    ${selector}
    ${count}=    Get Element Count    ${selector}
    IF    ${count} == 0    RETURN    ${NONE}
    ${content}=    Get Attribute    ${selector}    content
    RETURN    ${content}

Canonical Url Should Be
    [Arguments]    ${expected}
    ${href}=    Get Attribute    ${CANONICAL_LINK}    href
    Should Be Equal    ${href}    ${expected}

Page Should Have Exactly One H1
    [Documentation]    Exactly one top-level heading per page: more than one is
    ...    an accessibility and SEO defect, zero is worse.
    ...
    ...    Waits for the heading first, because routes that render
    ...    from fetched data show a loading placeholder before
    ...    their <h1> exists — counting straight away would be
    ...    testing the race, not the page.
    Wait For Elements State    ${H1}    visible    ${TIMEOUT}
    ${count}=    Get Element Count    ${H1}
    Should Be Equal As Integers    ${count}    1
    ...    msg=Expected exactly one <h1> on the page, found ${count}

Page Should Be Indexable
    [Documentation]    No robots meta tag at all, which is what "index this"
    ...    looks like for this application.
    ${robots}=    Get Meta Content    ${META_ROBOTS}
    Should Be Equal    ${robots}    ${NONE}
    ...    msg=Page carries robots='${robots}' but should be indexable

Page Should Be Noindex
    ${robots}=    Get Meta Content    ${META_ROBOTS}
    Should Not Be Equal    ${robots}    ${NONE}    msg=Page is missing its robots meta tag
    Should Contain    ${robots}    noindex

Get Structured Data
    [Documentation]    Returns the JSON-LD block as a dictionary.
    ${raw}=    Get Property    ${JSON_LD}    textContent
    ${data}=    Evaluate    json.loads($raw)    modules=json
    RETURN    ${data}

# =============================================================================
# Network observation
# =============================================================================

Count Requests Matching
    [Documentation]    Number of subresource requests the page has made whose
    ...    URL contains ${fragment}, read from the Resource Timing
    ...    buffer. Used to assert that a request was *not* made,
    ...    which no amount of DOM inspection can show.
    [Arguments]    ${fragment}
    ${count}=    Evaluate JavaScript    ${NONE}
    ...    () => performance.getEntriesByType('resource').filter((e) => e.name.includes('${fragment}')).length
    RETURN    ${count}

No Api Request Should Have Been Made
    [Documentation]    Guards the router's allowlist: a rejected slug must be
    ...    turned away client-side, never forwarded into an API path.
    ${count}=    Count Requests Matching    /api/
    Should Be Equal As Integers    ${count}    0
    ...    msg=The page issued ${count} request(s) to /api/ for a URL that should have been rejected before any request

# =============================================================================
# Layout
# =============================================================================

All Images Should Have Loaded
    [Documentation]    An <img> that 404s still satisfies "is visible", so the
    ...    decoded width is what proves the asset arrived.
    ...
    ...    Scoped to a selector so the caller can wait on one
    ...    region, and retried by the caller because a large
    ...    photograph is routinely still decoding when the rest
    ...    of the page is interactive — measuring once would test
    ...    the network, not the markup.
    [Arguments]    ${selector}=img
    ${broken}=    Evaluate JavaScript    ${NONE}
    ...    () => Array.from(document.querySelectorAll('${selector}')).filter((img) => !img.complete || img.naturalWidth === 0).map((img) => img.currentSrc || img.src)
    Should Be Empty    ${broken}    msg=Images did not load: ${broken}

Wait Until Images Have Loaded
    [Arguments]    ${selector}=img    ${attempts}=15x    ${interval}=1s
    Wait Until Keyword Succeeds    ${attempts}    ${interval}
    ...    All Images Should Have Loaded    ${selector}

Page Should Not Scroll Horizontally
    [Documentation]    A horizontal scrollbar at any supported width is a
    ...    responsive-layout defect. One pixel of tolerance absorbs
    ...    sub-pixel rounding in the layout engine.
    ${overflow}=    Evaluate JavaScript    ${NONE}
    ...    () => document.documentElement.scrollWidth - document.documentElement.clientWidth
    Should Be True    ${overflow} <= 1
    ...    msg=Document is ${overflow}px wider than the viewport
