*** Settings ***
Documentation       Authorisation on the write and analytics endpoints.
...
...                 Every request here is expected to be refused, which is
...                 exactly why these tests are safe to point at a live site:
...                 authorisation runs before any handler touches the
...                 database, so a rejected call changes nothing. No request
...                 carries a payload that could be persisted if that
...                 assumption were ever wrong.

Library             Collections
Library             String
Resource            ../../resources/api/public_api.robot
Resource            ../../resources/config/test_data.robot

Suite Setup         Create Public Api Session

Test Tags           api    security    authorization


*** Test Cases ***
Write Endpoints Refuse Anonymous Callers
    [Documentation]    Every mutating route must demand a token. One route
    ...    registered without the middleware is all it takes to
    ...    turn the whole content store into a public write
    ...    surface.
    [Tags]    smoke
    FOR    ${endpoint}    IN    @{PROTECTED_WRITE_ENDPOINTS}
        ${method}    ${path}=    Split String    ${endpoint}    separator=|
        ${response}=    Run Keyword    ${method} On Session    ${API_SESSION}    ${path}
        ...    expected_status=401
        ${body}=    Set Variable    ${response.json()}
        Should Not Be True    ${body}[success]
        Should Contain    ${body}[message]    token
    END

Analytics Endpoints Refuse Anonymous Callers
    [Documentation]    Per-article and global geography statistics are
    ...    operator data, not public content.
    FOR    ${path}    IN    @{PROTECTED_READ_ENDPOINTS}
        ${response}=    GET On Session    ${API_SESSION}    ${path}    expected_status=401
        ${body}=    Set Variable    ${response.json()}
        Should Not Be True    ${body}[success]
    END

Forged Tokens Are Refused
    [Documentation]    Covers the signature-verification failure modes that
    ...    matter: a string that is not a JWT, a token signed
    ...    with the wrong key, and an `alg: none` token whose
    ...    payload claims to be an admin. A library configured to
    ...    accept `none` would hand that last one full access.
    ...
    ...    The application answers 403 rather than 401 here: the
    ...    token was present and parsed, it just did not verify.
    [Tags]    jwt
    FOR    ${token}    IN    @{INVALID_TOKENS}
        ${headers}=    Create Dictionary    Authorization=Bearer ${token}
        ${response}=    POST On Session    ${API_SESSION}    /blogs    headers=${headers}
        ...    expected_status=403
        ${body}=    Set Variable    ${response.json()}
        Should Not Be True    ${body}[success]
    END

Forged Tokens Are Refused On Every Write Endpoint
    [Documentation]    The same forged token tried against each mutating route,
    ...    because middleware is wired per route and one missing
    ...    `authenticateToken` is invisible from any other route.
    [Tags]    jwt
    ${headers}=    Create Dictionary
    ...    Authorization=Bearer eyJhbGciOiJub25lIiwidHlwIjoiSldUIn0.eyJzdWIiOiJhZG1pbiJ9.
    FOR    ${endpoint}    IN    @{PROTECTED_WRITE_ENDPOINTS}
        ${method}    ${path}=    Split String    ${endpoint}    separator=|
        ${response}=    Run Keyword    ${method} On Session    ${API_SESSION}    ${path}
        ...    headers=${headers}    expected_status=403
        ${body}=    Set Variable    ${response.json()}
        Should Not Be True    ${body}[success]
    END

A Malformed Authorization Header Does Not Authenticate
    [Documentation]    The handler reads the token by splitting on whitespace.
    ...    A header with no scheme, an unknown scheme or nothing
    ...    after the scheme must fail closed rather than
    ...    producing an empty token that passes.
    [Template]    Authorization Header Should Not Authenticate
    Bearer
    Basic YWRtaW46YWRtaW4=
    bearer
    Token abc
    ${EMPTY}

Rejected Writes Do Not Leak Internals
    [Tags]    hardening
    ${response}=    POST On Session    ${API_SESSION}    /blogs    expected_status=401
    Response Should Not Leak Internals    ${response}

Rejected Writes Do Not Hand Back A Session
    [Documentation]    A refused request has no business setting a cookie or
    ...    returning a token of any kind.
    [Tags]    hardening
    ${response}=    POST On Session    ${API_SESSION}    /blogs    expected_status=401
    ${cookies}=    Evaluate    $response.headers.get('Set-Cookie')
    Should Be Equal    ${cookies}    ${NONE}    msg=A refused write returned Set-Cookie: ${cookies}
    ${credential_keys}=    Evaluate
    ...    sorted(k for k in $response.json() if k.lower() in ('token', 'accesstoken', 'refreshtoken', 'jwt'))
    Should Be Empty    ${credential_keys}
    ...    msg=A refused write returned credential field(s): ${credential_keys}

Public Reads Ignore An Invalid Token Instead Of Failing
    [Documentation]    The read routes use optional authentication: a bad token
    ...    must be dropped and the request served as anonymous.
    ...    Answering 500 instead would let any caller take the
    ...    public listing down with one malformed header.
    ${headers}=    Create Dictionary    Authorization=Bearer not-a-jwt
    ${response}=    GET On Session    ${API_SESSION}    /blogs    headers=${headers}
    ...    expected_status=200
    Response Envelope Should Be Successful    ${response}

An Invalid Token Does Not Widen What A Read Returns
    [Documentation]    The anonymous and bad-token responses must be
    ...    byte-for-byte the same set of documents. A difference
    ...    would mean the failed verification still left some
    ...    elevated state behind.
    ${anonymous}=    Get Blogs Response
    ${headers}=    Create Dictionary    Authorization=Bearer not-a-jwt
    ${with_token}=    GET On Session    ${API_SESSION}    /blogs    headers=${headers}
    ...    expected_status=200
    ${a}=    Evaluate    sorted(b['slug'] for b in $anonymous.json()['data'])
    ${b}=    Evaluate    sorted(b['slug'] for b in $with_token.json()['data'])
    Lists Should Be Equal    ${a}    ${b}
    ...    msg=An unverifiable token changed the result set: ${a} vs ${b}


*** Keywords ***
Authorization Header Should Not Authenticate
    [Arguments]    ${header_value}
    ${headers}=    Create Dictionary    Authorization=${header_value}
    ${response}=    POST On Session    ${API_SESSION}    /blogs    headers=${headers}
    ...    expected_status=any
    Should Be True    ${response.status_code} in (401, 403)
    ...    msg=Authorization header '${header_value}' produced ${response.status_code}, not a refusal
