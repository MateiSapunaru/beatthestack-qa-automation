*** Settings ***
Documentation       Page object for the not-found view and the two
...                 "content is missing" states that are not the 404 view:
...                 an article that does not resolve, and a section that
...                 does not exist.

Library             Browser
Resource            common.robot


*** Variables ***
${NOT_FOUND_PAGE}               css=.not-found-page
${NOT_FOUND_CODE}               css=.not-found-page .not-found-code
${NOT_FOUND_TITLE}              css=.not-found-page h1
${NOT_FOUND_TEXT}               css=.not-found-page .not-found-text
${NOT_FOUND_BLOG_BUTTON}        css=.not-found-page a.not-found-btn.primary
${NOT_FOUND_HOME_BUTTON}        css=.not-found-page a.not-found-btn:not(.primary)

# The article route renders an error panel rather than the 404 view when the
# slug is well-formed but resolves to nothing.
${ARTICLE_ERROR}                css=.blog-article-page .blog-error
${ARTICLE_ERROR_BACK}           css=.blog-article-page .blog-error button

# A section page with no matching section has its own empty state.
${SECTION_EMPTY_TITLE}          css=.blog-page .blog-page-hero h1


*** Keywords ***
Not Found Page Should Be Shown
    [Documentation]    A single-page app cannot return a 404 status, so the
    ...    view plus a noindex robots tag is the whole contract.
    Wait For Elements State    ${NOT_FOUND_PAGE}    visible    ${TIMEOUT}
    ${code}=    Get Text    ${NOT_FOUND_CODE}
    Should Be Equal    ${code}    404
    Wait For Elements State    ${NOT_FOUND_BLOG_BUTTON}    visible    ${TIMEOUT}

Article Error Should Be Shown
    Wait For Elements State    ${ARTICLE_ERROR}    visible    ${TIMEOUT}

Section Empty State Should Be Shown
    Wait For Elements State    ${SECTION_EMPTY_TITLE}    visible    ${TIMEOUT}
    ${title}=    Get Text    ${SECTION_EMPTY_TITLE}
    Should Contain    ${title}    doesn't exist
