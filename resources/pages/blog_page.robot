*** Settings ***
Documentation       Page object for the blog index (`/blog`) and for a single
...                 section listing (`/blog/section/<slug>`).

Library             Collections
Library             String
Library             Browser
Resource            common.robot


*** Variables ***
${BLOG_PAGE}                    css=.blog-page
${BLOG_LOADING}                 css=.blog-page .blog-loading
${BLOG_ERROR}                   css=.blog-page .blog-error
${BLOG_EMPTY}                   css=.blog-page .blog-empty
${BLOG_HERO_TITLE}              css=.blog-page .blog-page-hero h1
${BLOG_TOOLBAR}                 css=.blog-page .blog-page-toolbar
${BLOG_TOOLBAR_COUNT}           css=.blog-page .blog-page-toolbar strong

# --- Controls ----------------------------------------------------------------
${SEARCH_INPUT}                 css=.blog-page .blog-search input
${LABEL_FILTERS}                css=.blog-page button.blog-label-filter
${LABEL_FILTER_ALL}             css=.blog-page button.blog-label-filter:text-is("All Labels")
${ACTIVE_LABEL_FILTER}          css=.blog-page button.blog-label-filter.active

# --- Cards -------------------------------------------------------------------
${CARD}                         css=.blog-page article.blog-card
${CARD_IN_GRID}                 css=.blog-page .blog-posts-grid article.blog-card
${CARD_TITLE_LINK}              css=.blog-page article.blog-card a.blog-card-title-link
${FEATURED_CARD}                css=.blog-page .blog-featured-section article.blog-card.featured
${FEATURED_BADGE}               css=.blog-page .blog-featured-section .blog-card-badge
${EMPTY_INLINE}                 css=.blog-page .blog-empty-inline

# --- Section rows ------------------------------------------------------------
${SECTION_ROW}                  css=.blog-page .blog-sections .blog-section
${SECTION_ROW_TITLE_LINK}       css=.blog-page .blog-sections a.blog-section-title-link
# Browser Library runs selectors in strict mode, so anything used with Click or
# Get Property has to resolve to exactly one element.
${FIRST_SECTION_TITLE_LINK}     css=.blog-page .blog-sections a.blog-section-title-link >> nth=0

# --- Pagination --------------------------------------------------------------
${PAGINATION}                   css=.blog-page nav.blog-pagination
${PAGINATION_NEXT}              css=.blog-page nav.blog-pagination button.blog-pagination-btn:text-is("Next")
${PAGINATION_PREV}              css=.blog-page nav.blog-pagination button.blog-pagination-btn:text-is("Previous")
${PAGINATION_ACTIVE_PAGE}       css=.blog-page nav.blog-pagination button.blog-pagination-page.active

# The page debounces the search box by 400 ms; waiting a little longer than
# that keeps the assertion deterministic without polling the DOM blindly.
${SEARCH_DEBOUNCE}              0.8s


*** Keywords ***
Open Blog Page
    [Arguments]    ${width}=${DESKTOP_WIDTH}    ${height}=${DESKTOP_HEIGHT}
    Open Page At    /blog    ${width}    ${height}
    Blog Listing Should Be Loaded

Open Section Page
    [Arguments]    ${slug}
    Open Page At    /blog/section/${slug}
    Wait For Elements State    ${BLOG_PAGE}    visible    ${TIMEOUT}

Blog Listing Should Be Loaded
    [Documentation]    Waits out the loading placeholder, then asserts the
    ...    listing rendered rather than the error or empty state.
    Wait For Elements State    ${BLOG_PAGE}    visible    ${TIMEOUT}
    Wait For Elements State    ${BLOG_LOADING}    detached    ${TIMEOUT}
    ${errors}=    Get Element Count    ${BLOG_ERROR}
    Should Be Equal As Integers    ${errors}    0    msg=The blog listing rendered its error state
    Wait For Elements State    ${BLOG_HERO_TITLE}    visible    ${TIMEOUT}

Get Rendered Card Count
    ${count}=    Get Element Count    ${CARD}
    RETURN    ${count}

Get Grid Card Count
    ${count}=    Get Element Count    ${CARD_IN_GRID}
    RETURN    ${count}

Get Toolbar Article Count
    [Documentation]    The "Showing N articles" counter, as an integer.
    ${text}=    Get Text    ${BLOG_TOOLBAR_COUNT}
    ${count}=    Convert To Integer    ${text}
    RETURN    ${count}

Get All Card Slugs
    [Documentation]    The slug each card links to, taken from the anchor's
    ...    pathname so it reflects the real href a crawler sees.
    ${slugs}=    Evaluate JavaScript    ${NONE}
    ...    () => Array.from(document.querySelectorAll('.blog-page a.blog-card-title-link')).map((a) => new URL(a.href).pathname.replace('/blog/', ''))
    RETURN    ${slugs}

Get All Card Titles
    ${titles}=    Evaluate JavaScript    ${NONE}
    ...    () => Array.from(document.querySelectorAll('.blog-page a.blog-card-title-link')).map((a) => a.textContent.trim())
    RETURN    ${titles}

Search Articles For
    [Arguments]    ${query}
    Fill Text    ${SEARCH_INPUT}    ${query}
    Sleep    ${SEARCH_DEBOUNCE}    reason=the search box is debounced by 400 ms

Clear Article Search
    Fill Text    ${SEARCH_INPUT}    ${EMPTY}
    Sleep    ${SEARCH_DEBOUNCE}    reason=the search box is debounced by 400 ms

Filter By Label
    [Arguments]    ${label}
    Click    css=.blog-page button.blog-label-filter:text-is("${label}")

Get Available Labels
    ${labels}=    Evaluate JavaScript    ${NONE}
    ...    () => Array.from(document.querySelectorAll('.blog-page button.blog-label-filter')).map((b) => b.textContent.trim()).filter((t) => t !== 'All Labels')
    RETURN    ${labels}

Open Article By Title
    [Documentation]    An article assigned to a section is rendered twice on
    ...    the index: once in "Latest Articles" and once in its
    ...    section row. Both links go to the same place, so the
    ...    first match is the right one to click.
    [Arguments]    ${title}
    Click    css=.blog-page a.blog-card-title-link:text-is("${title}") >> nth=0

Every Card Should Carry Its Metadata
    [Documentation]    Every card must show a date, a read time, a titled link
    ...    and a description. Checked across all cards at once:
    ...    asserting it for the first card only would let a
    ...    mapping bug on later items through.
    ${incomplete}=    Evaluate JavaScript    ${NONE}
    ...    () => Array.from(document.querySelectorAll('.blog-page article.blog-card')).map((card, i) => ({ index: i, date: !!card.querySelector('.blog-card-date')?.textContent.trim(), readTime: !!card.querySelector('.blog-card-time')?.textContent.trim(), title: !!card.querySelector('a.blog-card-title-link')?.textContent.trim(), description: !!card.querySelector('.blog-card-description')?.textContent.trim() })).filter((c) => !c.date || !c.readTime || !c.title || !c.description)
    Should Be Empty    ${incomplete}    msg=Cards with missing metadata: ${incomplete}
