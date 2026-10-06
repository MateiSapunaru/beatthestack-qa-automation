*** Settings ***
Documentation       Single-article pages.
...
...                 Every published article is exercised, not just a sample:
...                 the list comes from the API, so a newly published piece is
...                 covered the next time the suite runs without anyone
...                 editing a test.

Library             Collections
Resource            ../../resources/api/public_api.robot
Resource            ../../resources/pages/common.robot
Resource            ../../resources/pages/blog_page.robot
Resource            ../../resources/pages/article_page.robot

Suite Setup         Run Keywords    Start Browser Session
...                 AND    Create Public Api Session
Test Teardown       Close Page Session

Test Tags           ui    article


*** Test Cases ***
Article Opens From The Listing
    [Tags]    smoke
    Open Blog Page
    ${blogs}=    Get Published Blogs
    ${title}=    Set Variable    ${blogs}[0][title]
    ${slug}=    Set Variable    ${blogs}[0][slug]
    Open Article By Title    ${title}
    Wait Until Keyword Succeeds    5x    0.5s    Current Path Should Be    /blog/${slug}
    Article Should Be Loaded
    ${heading}=    Get Article Title
    Should Be Equal    ${heading}    ${title}

Every Published Article Renders Its Own Content
    [Documentation]    Data-driven over everything the API publishes. The
    ...    heading must match the stored title and the body must
    ...    hold real prose, which is what catches an article that
    ...    "loads" into an empty shell.
    [Tags]    smoke
    ${blogs}=    Get Published Blogs
    FOR    ${blog}    IN    @{blogs}
        Open Article    ${blog}[slug]
        Page Should Have Exactly One H1
        ${heading}=    Get Article Title
        Should Be Equal    ${heading}    ${blog}[title]
        ...    msg=Article '${blog}[slug]' shows the heading '${heading}' but the API stores '${blog}[title]'
        Article Body Should Have Content
    END

Article Metadata Matches The Stored Document
    [Documentation]    Per-article title, description and canonical are what
    ...    make each piece indexable on its own rather than every
    ...    article sharing the landing page's metadata.
    [Tags]    seo
    ${blogs}=    Get Published Blogs
    FOR    ${blog}    IN    @{blogs}
        Open Article    ${blog}[slug]
        Page Title Should Be    ${blog}[title] — Beat The Stack
        Canonical Url Should Be    ${BASE_URL}/blog/${blog}[slug]
        Page Should Be Indexable
    END

Article Publishes Schema Org Structured Data
    [Documentation]    JSON-LD is what turns a result into a rich result. It
    ...    has to be valid JSON and describe this article, not a
    ...    stale one from the previously viewed route.
    [Tags]    seo
    ${blogs}=    Get Published Blogs
    FOR    ${blog}    IN    @{blogs}
        Open Article    ${blog}[slug]
        Article Structured Data Should Describe    ${blog}[slug]    ${blog}[title]
    END

Article Labels Match The Stored Labels
    ${blogs}=    Get Published Blogs
    FOR    ${blog}    IN    @{blogs}
        ${expected}=    Evaluate    $blog.get('labels') or []
        ${count}=    Get Length    ${expected}
        IF    ${count} > 0
            Open Article    ${blog}[slug]
            ${rendered}=    Evaluate JavaScript    ${NONE}
            ...    () => Array.from(document.querySelectorAll('.blog-article-page .blog-article-label')).map((el) => el.textContent.trim())
            Lists Should Be Equal    ${rendered}    ${expected}    ignore_order=${TRUE}
            ...    msg=Article '${blog}[slug]' renders labels ${rendered} but stores ${expected}
        END
    END

Article Body Renders Content As Text Not As Code
    [Documentation]    Article bodies are stored HTML written by an author with
    ...    admin access. Rendering them must not reintroduce a
    ...    script sink: a surviving <script>, <iframe> or inline
    ...    on* handler would be stored XSS against every reader.
    [Tags]    security
    ${blogs}=    Get Published Blogs
    FOR    ${blog}    IN    @{blogs}
        Open Article    ${blog}[slug]
        Article Body Should Not Contain Executable Markup
    END

Article Images Load Successfully
    [Documentation]    Cover art is served from a separate host and the largest
    ...    of these is comfortably over half a megabyte, so the
    ...    check is retried rather than taken once: measuring the
    ...    moment the heading appears reports a still-decoding
    ...    image as a broken one.
    ${blogs}=    Get Published Blogs
    FOR    ${blog}    IN    @{blogs}
        Open Article    ${blog}[slug]
        Wait Until Images Have Loaded    .blog-article-page img
    END

Back To Blog Returns To The Listing
    ${slugs}=    Get Published Slugs
    Open Article    ${slugs}[0]
    Go Back To Blog
    Blog Listing Should Be Loaded

Article Heading Does Not Leak Markup From Its Title
    [Documentation]    Titles are author-supplied and are written into the
    ...    document through the DOM rather than innerHTML. If any
    ...    title ever rendered as markup, the heading would hold
    ...    child elements instead of plain text.
    [Tags]    security
    ${blogs}=    Get Published Blogs
    FOR    ${blog}    IN    @{blogs}
        Open Article    ${blog}[slug]
        ${children}=    Evaluate JavaScript    ${NONE}
        ...    () => document.querySelector('.blog-article-page .blog-article-hero h1').children.length
        Should Be Equal As Integers    ${children}    0
        ...    msg=The heading of '${blog}[slug]' contains ${children} child element(s), so its title was parsed as markup
    END
