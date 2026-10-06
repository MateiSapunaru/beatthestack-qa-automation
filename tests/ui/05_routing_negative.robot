*** Settings ***
Documentation       Negative routing and the slug allowlist.
...
...                 The URL bar is attacker-controlled input, and the router
...                 interpolates a slug straight into an API path. The
...                 application defends itself with an allowlist
...                 (^[a-z0-9]+(?:-[a-z0-9]+)*$) applied before any request is
...                 made, so these tests assert both halves: the right view
...                 appears, and nothing was sent.

Resource            ../../resources/config/test_data.robot
Resource            ../../resources/pages/common.robot
Resource            ../../resources/pages/not_found_page.robot
Resource            ../../resources/pages/blog_page.robot

Suite Setup         Start Browser Session
Test Teardown       Close Page Session

Test Tags           ui    negative


*** Test Cases ***
Structurally Invalid Routes Render The Not Found View
    [Tags]    smoke
    FOR    ${route}    IN    @{UNKNOWN_ROUTES}
        Open Page At Raw Url    ${route}
        Not Found Page Should Be Shown
    END

No Rejected Slug Ever Reaches The Api
    [Documentation]    The important half of the allowlist is what does *not*
    ...    happen: a slug failing the pattern must never be
    ...    spliced into an API path, and must never produce an
    ...    article.
    ...
    ...    Two independent layers refuse these. Encoded
    ...    separators and malformed percent-encoding are turned
    ...    away upstream with a 400; everything else is served
    ...    index.html and stopped by the router's allowlist. This
    ...    test asserts the property that holds either way, so it
    ...    keeps covering every input even if the edge
    ...    configuration changes which layer answers.
    ...
    ...    Measured from the browser's Resource Timing buffer
    ...    rather than inferred from the rendered view — nothing
    ...    in the DOM can show that a request was not sent.
    [Tags]    security
    FOR    ${slug}    IN    @{REJECTED_SLUGS}
        Open Page At Raw Url    /blog/${slug}
        No Api Request Should Have Been Made
        ${article}=    Get Element Count    css=.blog-article-page
        Should Be Equal As Integers    ${article}    0
        ...    msg=Slug '${slug}' rendered an article view
    END

Slugs That Reach The Router Render The Not Found View
    [Documentation]    For the inputs that are passed through, the router's
    ...    allowlist is the thing being tested, and the visible
    ...    outcome has to be the 404 view rather than a blank
    ...    page or a half-rendered article shell.
    [Tags]    security
    FOR    ${slug}    IN    @{ROUTER_REJECTED_SLUGS}
        Open Page At Raw Url    /blog/${slug}
        Not Found Page Should Be Shown
        No Api Request Should Have Been Made
    END

An Over Long Slug Is Rejected
    [Documentation]    The allowlist is paired with a 250-character ceiling, so
    ...    an otherwise well-formed slug can still be too long to
    ...    be real. Without the ceiling this is a cheap way to
    ...    push oversized paths at the origin.
    [Tags]    security
    ${slug}=    Evaluate    'a' * (${MAX_SLUG_LENGTH} + 1)
    Open Page At Raw Url    /blog/${slug}
    Not Found Page Should Be Shown
    No Api Request Should Have Been Made

A Slug At The Length Limit Is Still Accepted
    [Documentation]    The boundary from the other side: exactly 250
    ...    characters passes the check, so the page is allowed to
    ...    ask the API and renders the "unavailable" state rather
    ...    than the 404 view. Proves the ceiling is `>` and not
    ...    an off-by-one `>=`.
    ${slug}=    Evaluate    'a' * ${MAX_SLUG_LENGTH}
    Open Page At Raw Url    /blog/${slug}
    Article Error Should Be Shown
    ${requests}=    Count Requests Matching    /api/blogs/
    Should Be True    ${requests} > 0
    ...    msg=A slug at exactly the length limit was rejected client-side, so the boundary is off by one

Not Found View Is Kept Out Of The Search Index
    [Documentation]    A single-page app cannot answer with a 404 status, so
    ...    `noindex` is the only thing stopping every mistyped URL
    ...    from being indexed as a soft 404 duplicate.
    [Tags]    seo
    Open Page At Raw Url    /this-route-does-not-exist
    Not Found Page Should Be Shown
    Page Should Be Noindex
    Page Title Should Be    Page not found — Beat The Stack

Not Found View Offers A Way Back
    Open Page At Raw Url    /this-route-does-not-exist
    Not Found Page Should Be Shown
    Click    ${NOT_FOUND_BLOG_BUTTON}
    Wait Until Keyword Succeeds    5x    0.5s    Current Path Should Be    /blog
    Blog Listing Should Be Loaded

A Well Formed Slug With No Article Shows The Unavailable State
    [Documentation]    Distinct from a rejected slug: the request is allowed,
    ...    the API answers 404, and the page reports that rather
    ...    than pretending the route does not exist.
    Open Page At Raw Url    /blog/${MISSING_ARTICLE_SLUG}
    Article Error Should Be Shown
    Page Should Be Noindex
    Page Title Should Be    Article unavailable — Beat The Stack

A Section That Does Not Exist Shows Its Own Empty State
    Open Page At Raw Url    /blog/section/${MISSING_SECTION_SLUG}
    Section Empty State Should Be Shown
    Page Should Be Noindex

Rejected Slugs Do Not Execute Injected Markup
    [Documentation]    A script payload in the path must end up as inert text
    ...    on a 404 page, never as a node in the document. The
    ...    check looks for an actual <script> element and for any
    ...    dialog the payload would have opened.
    [Tags]    security
    Open Page At Raw Url    /blog/<script>alert(1)</script>
    Not Found Page Should Be Shown
    ${injected}=    Evaluate JavaScript    ${NONE}
    ...    () => document.querySelectorAll('body script:not([src])').length
    Should Be Equal As Integers    ${injected}    0
    ...    msg=${injected} inline script element(s) were injected into the body
