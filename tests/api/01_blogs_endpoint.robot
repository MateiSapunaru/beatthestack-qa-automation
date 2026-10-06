*** Settings ***
Documentation       Contract tests for the public blog endpoints.
...
...                 Read-only by design: the system under test is a live site,
...                 so nothing here can change its state.

Library             Collections
Resource            ../../resources/api/public_api.robot
Resource            ../../resources/config/test_data.robot

Suite Setup         Create Public Api Session

Test Tags           api    blogs


*** Variables ***
# The fields an unauthenticated caller is expected to receive. Anything outside
# this set is a change to the public surface and is flagged for review.
@{PUBLIC_BLOG_FIELDS}
...                             _id    title    slug    content    excerpt
...                             coverImage    readTime    labels    sections
...                             isPublished    isFeatured    publishedAt
...                             viewCount    createdAt    updatedAt    __v


*** Test Cases ***
Blog Collection Responds Successfully
    [Tags]    smoke
    ${response}=    Get Blogs Response
    Status Should Be    200    ${response}
    Response Should Be Json    ${response}
    Response Envelope Should Be Successful    ${response}

Reported Count Matches The Returned Documents
    [Documentation]    A `count` that disagrees with the length of `data` is
    ...    the classic off-by-one in a paginated handler, and a
    ...    client that trusts `count` breaks silently.
    ${response}=    Get Blogs Response
    Reported Count Should Match Payload    ${response}

Every Blog Document Honours Its Contract
    [Documentation]    Types as well as presence. A `readTime` that arrives as
    ...    "5" instead of 5 still renders, then breaks the first
    ...    piece of arithmetic anyone does with it.
    [Tags]    smoke
    ${blogs}=    Get Published Blogs
    Should Not Be Empty    ${blogs}    msg=The API published no blogs, so there is nothing to validate
    FOR    ${blog}    IN    @{blogs}
        Blog Object Should Match Contract    ${blog}
    END

Slugs Are Unique Across The Collection
    [Documentation]    The slug is the public identifier a URL is built from.
    ...    Two documents sharing one makes an article unreachable.
    ${slugs}=    Get Published Slugs
    ${unique}=    Remove Duplicates    ${slugs}
    Lists Should Be Equal    ${slugs}    ${unique}
    ...    msg=Duplicate slugs in the collection: ${slugs}

Blog Is Retrievable By Its Slug
    [Tags]    smoke
    ${slugs}=    Get Published Slugs
    FOR    ${slug}    IN    @{slugs}
        ${response}=    Get Blog Response    ${slug}
        ${body}=    Set Variable    ${response.json()}
        Should Be Equal    ${body}[data][slug]    ${slug}
        ...    msg=Requesting '${slug}' returned '${body}[data][slug]'
        Blog Object Should Match Contract    ${body}[data]
    END

Blog Is Retrievable By Its Id And Matches The Slug Lookup
    [Documentation]    The endpoint accepts either identifier. Both paths must
    ...    reach the same document, or the two routes have
    ...    drifted apart.
    ${blogs}=    Get Published Blogs
    FOR    ${blog}    IN    @{blogs}
        ${by_id}=    Get Blog Response    ${blog}[_id]
        ${body}=    Set Variable    ${by_id.json()}
        Should Be Equal    ${body}[data][slug]    ${blog}[slug]
        Should Be Equal    ${body}[data][_id]    ${blog}[_id]
    END

Unknown Slug Is Rejected With Not Found
    ${response}=    Get Blog Response    ${MISSING_ARTICLE_SLUG}    expected_status=404
    ${body}=    Set Variable    ${response.json()}
    Should Not Be True    ${body}[success]

Unknown Slug Response Does Not Leak Internals
    [Documentation]    An error may say what failed; it may not hand out stack
    ...    traces, build paths or driver internals to anonymous
    ...    callers.
    [Tags]    security
    ${response}=    Get Blog Response    ${MISSING_ARTICLE_SLUG}    expected_status=404
    Response Should Not Leak Internals    ${response}

Malformed Object Id Is Handled As A Miss Not An Error
    [Documentation]    A 24-character hex string that is not a real id, and a
    ...    string that is not an id at all, must both come back
    ...    404. A 500 here means an unguarded cast reached the
    ...    driver.
    [Template]    Identifier Should Be Rejected With Not Found
    000000000000000000000000
    not-a-valid-object-id
    000000000000000000000000000000

Collection Responds Within Its Budget
    [Tags]    performance
    ${response}=    Get Blogs Response
    Response Should Be Faster Than Sla    ${response}

Single Blog Responds Within Its Budget
    [Tags]    performance
    ${slugs}=    Get Published Slugs
    ${response}=    Get Blog Response    ${slugs}[0]
    Response Should Be Faster Than Sla    ${response}

Api Responses Are Kept Out Of The Search Index
    [Documentation]    JSON endpoints indexed as pages are duplicate, useless
    ...    search results. The header is applied upstream of the
    ...    application, so this verifies the delivery layer's
    ...    response policy and not only the handler.
    [Tags]    seo
    ${response}=    Get Blogs Response
    ${header}=    Get From Dictionary    ${response.headers}    X-Robots-Tag
    Should Contain    ${header}    noindex

Public Documents Carry Only Their Agreed Fields
    [Documentation]    An allowlist rather than a denylist. The site records
    ...    per-visitor geolocation behind an authenticated stats
    ...    endpoint, so the question is not whether today's known
    ...    leak is absent but whether anything unexpected has
    ...    appeared on the public surface at all.
    ...
    ...    A new legitimate field makes this fail on purpose: a
    ...    change to what an unauthenticated caller receives is
    ...    exactly the change worth reviewing by hand.
    [Tags]    security    contract
    ${blogs}=    Get Published Blogs
    ${unexpected}=    Evaluate
    ...    sorted({k for b in $blogs for k in b} - set($PUBLIC_BLOG_FIELDS))
    Should Be Empty    ${unexpected}
    ...    msg=Public blog documents expose field(s) outside the agreed contract: ${unexpected}

Public Listing Contains Only Published Documents
    [Documentation]    An anonymous read is forced to `isPublished: true` by
    ...    the handler. A draft appearing here would publish
    ...    unfinished writing to everyone.
    [Tags]    security
    ${blogs}=    Get Published Blogs
    ${drafts}=    Evaluate    [b['slug'] for b in $blogs if not b.get('isPublished')]
    Should Be Empty    ${drafts}    msg=Unpublished documents are visible anonymously: ${drafts}


*** Keywords ***
Identifier Should Be Rejected With Not Found
    [Arguments]    ${identifier}
    ${response}=    Get Blog Response    ${identifier}    expected_status=404
    Response Should Not Leak Internals    ${response}
