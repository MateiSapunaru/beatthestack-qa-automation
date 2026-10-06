*** Settings ***
Documentation       The blog collection accepts `published`, `search`,
...                 `sortBy`, `sortOrder`, `limit` and `skip` from anonymous
...                 callers, so every one of them is attacker-reachable input.
...
...                 Two things are being tested. That the parameters do what
...                 they say — and that hostile or nonsensical values degrade
...                 into a plain 200 rather than a 500, because an endpoint
...                 that can be made to throw from the query string is an
...                 availability problem before it is anything else.

Library             Collections
Resource            ../../resources/api/public_api.robot

Suite Setup         Create Public Api Session

Test Tags           api    blogs    query-parameters


*** Test Cases ***
Drafts Are Refused To Anonymous Callers
    [Documentation]    `?published=false` is the one parameter value that asks
    ...    for unpublished content. It has to be refused outright
    ...    rather than quietly serving the published set, which
    ...    would hide the hole until someone looked at the data.
    [Tags]    smoke    security
    ${response}=    GET On Session    ${API_SESSION}    /blogs    params=published=false
    ...    expected_status=401
    ${body}=    Set Variable    ${response.json()}
    Should Not Be True    ${body}[success]
    Should Contain    ${body}[message]    Authentication required

Explicitly Requesting Published Content Matches The Default
    ${default}=    Get Blogs Response
    ${explicit}=    GET On Session    ${API_SESSION}    /blogs    params=published=true
    ...    expected_status=200
    ${a}=    Evaluate    sorted(b['slug'] for b in $default.json()['data'])
    ${b}=    Evaluate    sorted(b['slug'] for b in $explicit.json()['data'])
    Lists Should Be Equal    ${a}    ${b}

Limit Caps The Number Of Documents Returned
    ${response}=    GET On Session    ${API_SESSION}    /blogs    params=limit=1
    ...    expected_status=200
    ${body}=    Set Variable    ${response.json()}
    Should Be Equal As Integers    ${body}[count]    1
    Reported Count Should Match Payload    ${response}

Skip Past The End Returns An Empty Collection
    [Documentation]    Empty, not an error, and still a well-formed envelope —
    ...    a client paging to the end must not have to special
    ...    case the last request.
    ${response}=    GET On Session    ${API_SESSION}    /blogs    params=skip=99999
    ...    expected_status=200
    ${body}=    Set Variable    ${response.json()}
    Should Be Equal As Integers    ${body}[count]    0
    Should Be Empty    ${body}[data]
    Response Envelope Should Be Successful    ${response}

Search Narrows The Collection
    ${all}=    Get Published Slugs
    ${total}=    Get Length    ${all}
    ${response}=    GET On Session    ${API_SESSION}    /blogs    params=search=zzzznomatchzzzz
    ...    expected_status=200
    ${body}=    Set Variable    ${response.json()}
    Should Be Equal As Integers    ${body}[count]    0
    ...    msg=A search for nonsense returned ${body}[count] of ${total} document(s), so the term was ignored

Search Treats A Query Operator As Literal Text
    [Documentation]    The search term reaches a database query. Passing an
    ...    operator document as the value is the standard NoSQL
    ...    injection probe: `{"$ne": ""}` matches everything if
    ...    the string is interpolated into the query instead of
    ...    being bound as a value.
    [Tags]    security    injection
    [Template]    Search Term Should Not Match Everything
    {"$ne": ""}
    {"$gt": ""}
    {"$regex": ".*"}
    [$ne]=

Malformed Numeric Parameters Degrade Gracefully
    [Documentation]    `limit` and `skip` go through `parseInt`, which yields
    ...    NaN for anything non-numeric. The endpoint must shrug
    ...    that off, not pass NaN down to the driver.
    [Template]    Query Should Respond Successfully
    limit=abc
    limit=-5
    limit=0
    limit=1e9
    skip=-1
    skip=abc

Unknown Sort Parameters Degrade Gracefully
    [Documentation]    `sortBy` names a field to sort on, straight from the
    ...    query string. A dangerous value must be ignored rather
    ...    than reaching the driver or polluting a prototype.
    [Tags]    security
    [Template]    Query Should Respond Successfully
    sortOrder=bogus
    sortBy=__proto__
    sortBy=constructor
    sortBy=this.password
    sortBy=title&sortOrder=asc

Unknown Parameters Are Ignored
    [Documentation]    An unrecognised parameter must not change the response.
    ...    Silently honouring one is how undocumented behaviour
    ...    gets depended on.
    ${default}=    Get Blogs Response
    ${noisy}=    GET On Session    ${API_SESSION}    /blogs
    ...    params=unexpected=1&isPublished=false&admin=true    expected_status=200
    ${a}=    Evaluate    sorted(b['slug'] for b in $default.json()['data'])
    ${b}=    Evaluate    sorted(b['slug'] for b in $noisy.json()['data'])
    Lists Should Be Equal    ${a}    ${b}
    ...    msg=Unrecognised parameters changed the result set: ${a} vs ${b}

Sorting Is Applied When Requested
    ${response}=    GET On Session    ${API_SESSION}    /blogs
    ...    params=sortBy=title&sortOrder=asc    expected_status=200
    ${titles}=    Evaluate    [b['title'] for b in $response.json()['data']]
    ${count}=    Get Length    ${titles}
    Skip If    ${count} < 2    Fewer than two documents exist, so ordering cannot be observed
    ${sorted}=    Evaluate    sorted($titles)
    Lists Should Be Equal    ${titles}    ${sorted}
    ...    msg=Ascending sort by title returned ${titles}


*** Keywords ***
Query Should Respond Successfully
    [Documentation]    The endpoint answers 200 with a valid envelope. What the
    ...    parameter is interpreted as does not matter; that it
    ...    cannot be used to provoke a 500 does.
    [Arguments]    ${query}
    ${response}=    GET On Session    ${API_SESSION}    /blogs    params=${query}
    ...    expected_status=200
    Response Envelope Should Be Successful    ${response}
    Reported Count Should Match Payload    ${response}

Search Term Should Not Match Everything
    [Arguments]    ${term}
    ${all}=    Get Published Slugs
    ${total}=    Get Length    ${all}
    ${params}=    Create Dictionary    search=${term}
    ${response}=    GET On Session    ${API_SESSION}    /blogs    params=${params}
    ...    expected_status=200
    ${body}=    Set Variable    ${response.json()}
    Should Be True    ${body}[count] < ${total}
    ...    msg=The term '${term}' matched all ${total} document(s), so it was interpreted as a query operator rather than text
