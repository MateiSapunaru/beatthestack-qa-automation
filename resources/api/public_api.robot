*** Settings ***
Documentation       Keywords for the public read API and for the contract its
...                 responses must honour.
...
...                 Every keyword here is read-only. The system under test is
...                 somebody's live site, so the suite never sends a request
...                 that could persist anything: write endpoints are exercised
...                 only to prove that authorisation rejects them first.

Library             Collections
Library             String
Library             RequestsLibrary
Resource            ../config/environments.robot


*** Variables ***
${API_SESSION}                  btts
# Identifies the suite in the origin's access logs, so traffic from these runs
# is attributable rather than looking like a stray bot.
${USER_AGENT}                   beatthestack-qa-automation/1.0 (+robotframework)


*** Keywords ***
# =============================================================================
# Session
# =============================================================================

Create Public Api Session
    [Documentation]    Suite setup for the API suites. TLS verification stays
    ...    on: a test suite that disables it cannot notice a
    ...    certificate regression.
    ${headers}=    Create Dictionary    User-Agent=${USER_AGENT}
    Create Session    ${API_SESSION}    ${API_URL}    headers=${headers}    verify=${TRUE}

Create Site Session
    [Documentation]    A session rooted at the site origin rather than /api,
    ...    for documents served outside the API prefix.
    ${headers}=    Create Dictionary    User-Agent=${USER_AGENT}
    Create Session    site    ${BASE_URL}    headers=${headers}    verify=${TRUE}

# =============================================================================
# Reads
# =============================================================================

Get Blogs Response
    [Arguments]    ${expected_status}=200
    ${response}=    GET On Session    ${API_SESSION}    /blogs    expected_status=${expected_status}
    RETURN    ${response}

Get Blog Response
    [Arguments]    ${identifier}    ${expected_status}=200
    ${response}=    GET On Session    ${API_SESSION}    /blogs/${identifier}
    ...    expected_status=${expected_status}
    RETURN    ${response}

Get Sections Response
    [Arguments]    ${expected_status}=200
    ${response}=    GET On Session    ${API_SESSION}    /sections    expected_status=${expected_status}
    RETURN    ${response}

Get Published Blogs
    [Documentation]    The `data` array of GET /blogs, as a list of dicts.
    ...    Tests derive their expectations from this instead of
    ...    hardcoding today's content.
    ${response}=    Get Blogs Response
    ${body}=    Set Variable    ${response.json()}
    ${blogs}=    Set Variable    ${body}[data]
    RETURN    ${blogs}

Get Published Slugs
    ${blogs}=    Get Published Blogs
    ${slugs}=    Evaluate    [blog['slug'] for blog in $blogs]
    RETURN    ${slugs}

Get Section Slugs
    ${response}=    Get Sections Response
    ${body}=    Set Variable    ${response.json()}
    ${slugs}=    Evaluate    [section['slug'] for section in $body['data']]
    RETURN    ${slugs}

# =============================================================================
# Response contract
# =============================================================================

Response Should Be Json
    [Arguments]    ${response}
    ${content_type}=    Get From Dictionary    ${response.headers}    Content-Type
    Should Contain    ${content_type}    application/json

Response Envelope Should Be Successful
    [Documentation]    Every successful read is wrapped in
    ...    { success, count, data } — the envelope is part of the
    ...    contract, not an implementation detail.
    [Arguments]    ${response}
    ${body}=    Set Variable    ${response.json()}
    Dictionary Should Contain Key    ${body}    success
    Should Be True    ${body}[success]    msg=Response reports success=False
    Dictionary Should Contain Key    ${body}    data
    Should Be True    isinstance($body['data'], list)    msg='data' is not a list

Reported Count Should Match Payload
    [Documentation]    A `count` that disagrees with `len(data)` is the classic
    ...    pagination bug, and it is invisible unless asserted.
    [Arguments]    ${response}
    ${body}=    Set Variable    ${response.json()}
    ${length}=    Get Length    ${body}[data]
    Should Be Equal As Integers    ${body}[count]    ${length}
    ...    msg=count=${body}[count] but data holds ${length} item(s)

Blog Object Should Match Contract
    [Documentation]    Field-by-field contract for one blog document. Checks
    ...    types, not just presence: a `readTime` arriving as a
    ...    string still renders, then breaks any arithmetic on it.
    [Arguments]    ${blog}
    FOR    ${field}    IN    _id    title    slug    content    publishedAt    readTime
        Dictionary Should Contain Key    ${blog}    ${field}
        ...    msg=A blog document is missing the required field '${field}'
    END
    Should Be True    isinstance($blog['title'], str) and len($blog['title']) > 0
    ...    msg=title is not a non-empty string
    Should Be True    isinstance($blog['content'], str) and len($blog['content']) > 0
    ...    msg=content is not a non-empty string
    Should Be True    isinstance($blog['readTime'], int) and $blog['readTime'] > 0
    ...    msg=readTime is not a positive integer: ${blog}[readTime]
    Should Match Regexp    ${blog}[slug]    ${SLUG_PATTERN}
    ...    msg=Slug '${blog}[slug]' does not satisfy the public slug allowlist
    Should Match Regexp    ${blog}[_id]    ^[0-9a-f]{24}$
    ...    msg='${blog}[_id]' is not a 24-character hex ObjectId
    Timestamp Should Be Iso 8601    ${blog}[publishedAt]

Section Object Should Match Contract
    [Arguments]    ${section}
    FOR    ${field}    IN    _id    name    slug    order
        Dictionary Should Contain Key    ${section}    ${field}
    END
    Should Be True    isinstance($section['name'], str) and len($section['name']) > 0
    Should Match Regexp    ${section}[slug]    ${SLUG_PATTERN}
    ...    msg=Section slug '${section}[slug]' does not satisfy the public slug allowlist

Timestamp Should Be Iso 8601
    [Documentation]    Fails on anything `datetime.fromisoformat` cannot read,
    ...    which is the practical definition of a timestamp a
    ...    client can parse.
    [Arguments]    ${value}
    ${parsed}=    Evaluate
    ...    datetime.datetime.fromisoformat($value.replace('Z', '+00:00'))    modules=datetime
    Should Not Be Equal    ${parsed}    ${NONE}

# =============================================================================
# Non-functional
# =============================================================================

Response Should Be Faster Than Sla
    [Arguments]    ${response}    ${max_ms}=${API_MAX_RESPONSE_MS}
    ${elapsed}=    Evaluate    round($response.elapsed.total_seconds() * 1000)
    Should Be True    ${elapsed} < ${max_ms}
    ...    msg=Response took ${elapsed} ms, over the ${max_ms} ms budget

Response Should Not Leak Internals
    [Documentation]    An error body may say what went wrong; it may not hand
    ...    out stack traces, file paths or driver internals.
    [Arguments]    ${response}
    ${body}=    Convert To Lower Case    ${response.text}
    FOR    ${marker}    IN    traceback    node_modules    at object.    .ts:    .js:    mongoerror    econnrefused
        Should Not Contain    ${body}    ${marker}
        ...    msg=Error body leaks internal detail ('${marker}'): ${response.text}
    END
