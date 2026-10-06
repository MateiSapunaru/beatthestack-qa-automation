*** Settings ***
Documentation       Contract tests for the public sections endpoint, and the
...                 consistency between sections and the articles that claim
...                 them.

Library             Collections
Resource            ../../resources/api/public_api.robot

Suite Setup         Create Public Api Session

Test Tags           api    sections


*** Test Cases ***
Sections Endpoint Responds Successfully
    [Tags]    smoke
    ${response}=    Get Sections Response
    Status Should Be    200    ${response}
    Response Should Be Json    ${response}
    Response Envelope Should Be Successful    ${response}
    Reported Count Should Match Payload    ${response}

Every Section Document Honours Its Contract
    ${response}=    Get Sections Response
    ${body}=    Set Variable    ${response.json()}
    FOR    ${section}    IN    @{body}[data]
        Section Object Should Match Contract    ${section}
    END

Section Slugs Are Unique
    ${slugs}=    Get Section Slugs
    ${unique}=    Remove Duplicates    ${slugs}
    Lists Should Be Equal    ${slugs}    ${unique}    msg=Duplicate section slugs: ${slugs}

Section Order Values Are Usable For Sorting
    [Documentation]    `order` drives the row sequence on the blog index. Two
    ...    sections sharing a value make that sequence depend on
    ...    insertion order, which is not stable.
    ${response}=    Get Sections Response
    ${body}=    Set Variable    ${response.json()}
    ${orders}=    Evaluate    [s['order'] for s in $body['data']]
    ${count}=    Get Length    ${orders}
    Skip If    ${count} < 2    Fewer than two sections exist, so ordering cannot conflict
    ${unique}=    Remove Duplicates    ${orders}
    Lists Should Be Equal    ${orders}    ${unique}    msg=Sections share an order value: ${orders}

Sections Referenced By Articles All Exist
    [Documentation]    Cross-checks the two collections. An article pointing at
    ...    a section that was deleted renders under a heading
    ...    nothing can link to.
    ${blogs}=    Get Published Blogs
    ${section_slugs}=    Get Section Slugs
    ${referenced}=    Evaluate
    ...    sorted({s['slug'] for b in $blogs for s in (b.get('sections') or []) if 'slug' in s})
    FOR    ${slug}    IN    @{referenced}
        List Should Contain Value    ${section_slugs}    ${slug}
        ...    msg=An article references section '${slug}', which the sections endpoint does not serve
    END

Sections Endpoint Responds Within Its Budget
    [Tags]    performance
    ${response}=    Get Sections Response
    Response Should Be Faster Than Sla    ${response}
