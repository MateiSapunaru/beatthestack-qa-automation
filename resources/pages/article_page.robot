*** Settings ***
Documentation       Page object for a single article (`/blog/<slug>`).

Library             Collections
Library             Browser
Resource            common.robot


*** Variables ***
${ARTICLE_PAGE}                 css=.blog-article-page
${ARTICLE_LOADING}              css=.blog-article-page .blog-loading
${ARTICLE_BACK_BUTTON}          css=.blog-article-page button.blog-article-back
${ARTICLE_TITLE}                css=.blog-article-page .blog-article-hero h1
${ARTICLE_META}                 css=.blog-article-page .blog-article-meta
${ARTICLE_EXCERPT}              css=.blog-article-page .blog-article-excerpt
${ARTICLE_LABEL}                css=.blog-article-page .blog-article-label
${ARTICLE_BODY}                 css=.blog-article-page .blog-article-body
${ARTICLE_PARAGRAPH}            css=.blog-article-page .blog-article-body p
${ARTICLE_COVER_IMAGE}          css=.blog-article-page .blog-article-hero-image img


*** Keywords ***
Open Article
    [Arguments]    ${slug}    ${width}=${DESKTOP_WIDTH}    ${height}=${DESKTOP_HEIGHT}
    Open Page At    /blog/${slug}    ${width}    ${height}
    Article Should Be Loaded

Article Should Be Loaded
    Wait For Elements State    ${ARTICLE_PAGE}    visible    ${TIMEOUT}
    Wait For Elements State    ${ARTICLE_LOADING}    detached    ${TIMEOUT}
    Wait For Elements State    ${ARTICLE_TITLE}    visible    ${TIMEOUT}

Get Article Title
    ${text}=    Get Text    ${ARTICLE_TITLE}
    RETURN    ${text}

Article Body Should Have Content
    [Documentation]    The body arrives as author-supplied HTML, so "rendered"
    ...    means real paragraphs with real text, not an empty
    ...    container that happens to exist.
    ${paragraphs}=    Get Element Count    ${ARTICLE_PARAGRAPH}
    Should Be True    ${paragraphs} > 0    msg=The article body rendered no paragraphs
    ${length}=    Evaluate JavaScript    ${NONE}
    ...    () => document.querySelector('.blog-article-page .blog-article-body').textContent.trim().length
    Should Be True    ${length} > 200
    ...    msg=The article body holds only ${length} characters of text

Article Body Should Not Contain Executable Markup
    [Documentation]    Article HTML is stored content rendered into the page.
    ...    A <script> or an inline event handler surviving into
    ...    the body would be a stored-XSS sink.
    ${dangerous}=    Evaluate JavaScript    ${NONE}
    ...    () => { const body = document.querySelector('.blog-article-page .blog-article-body'); const scripts = body.querySelectorAll('script, iframe, object, embed').length; const handlers = Array.from(body.querySelectorAll('*')).filter((el) => Array.from(el.attributes).some((a) => a.name.startsWith('on'))).length; return { scripts, handlers }; }
    Should Be Equal As Integers    ${dangerous}[scripts]    0
    ...    msg=The article body rendered ${dangerous}[scripts] executable element(s)
    Should Be Equal As Integers    ${dangerous}[handlers]    0
    ...    msg=The article body rendered ${dangerous}[handlers] inline event handler(s)

Go Back To Blog
    Click    ${ARTICLE_BACK_BUTTON}
    Wait Until Keyword Succeeds    5x    0.5s    Current Path Should Be    /blog

Article Structured Data Should Describe
    [Documentation]    Validates the JSON-LD against schema.org/Article for the
    ...    fields that actually affect a rich result.
    [Arguments]    ${slug}    ${title}
    ${data}=    Get Structured Data
    Should Be Equal    ${data}[@type]    Article
    Should Be Equal    ${data}[@context]    https://schema.org
    Should Be Equal    ${data}[headline]    ${title}
    Should Be Equal    ${data}[mainEntityOfPage][@id]    ${BASE_URL}/blog/${slug}
    Dictionary Should Contain Key    ${data}    datePublished
    Dictionary Should Contain Key    ${data}    publisher
