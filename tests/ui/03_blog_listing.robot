*** Settings ***
Documentation       The blog index: what it renders, and whether what it
...                 renders agrees with what the API serves.
...
...                 Expectations are read from the API at run time rather than
...                 hardcoded, which turns these into cross-layer consistency
...                 checks: a listing that silently drops or duplicates an
...                 article fails, while publishing a new one does not.

Library             Collections
Resource            ../../resources/api/public_api.robot
Resource            ../../resources/pages/common.robot
Resource            ../../resources/pages/blog_page.robot

Suite Setup         Run Keywords    Start Browser Session
...                 AND    Create Public Api Session
Test Teardown       Close Page Session

Test Tags           ui    blog


*** Variables ***
# The listing paginates after this many non-featured articles.
${POSTS_PER_PAGE}               ${6}


*** Test Cases ***
Blog Index Renders Its Listing
    [Tags]    smoke
    Open Blog Page
    ${cards}=    Get Rendered Card Count
    Should Be True    ${cards} > 0    msg=The blog index rendered no article cards

Article Counter Agrees With The Api
    [Documentation]    The "Showing N articles" counter is the page's own claim
    ...    about how much content it has. It must match the
    ...    number of documents the API actually serves.
    Open Blog Page
    ${expected}=    Get Published Slugs
    ${expected_count}=    Get Length    ${expected}
    ${shown}=    Get Toolbar Article Count
    Should Be Equal As Integers    ${shown}    ${expected_count}
    ...    msg=The listing claims ${shown} article(s) but the API serves ${expected_count}

Every Rendered Card Links To A Real Article
    [Documentation]    Guards against a card linking to a slug that no longer
    ...    resolves — a dead internal link, which is both a user
    ...    and a crawl-budget problem.
    Open Blog Page
    ${published}=    Get Published Slugs
    ${rendered}=    Get All Card Slugs
    Should Not Be Empty    ${rendered}    msg=No cards exposed a slug
    FOR    ${slug}    IN    @{rendered}
        List Should Contain Value    ${published}    ${slug}
        ...    msg=A card links to '/blog/${slug}', which the API does not serve
    END

Every Published Article Appears In The Listing
    [Documentation]    The other direction: an article the API publishes but
    ...    the listing never shows is invisible to readers.
    Open Blog Page
    ${published}=    Get Published Slugs
    ${rendered}=    Get All Card Slugs
    FOR    ${slug}    IN    @{published}
        List Should Contain Value    ${rendered}    ${slug}
        ...    msg=Published article '${slug}' is missing from the listing
    END

Every Card Shows Its Date Title And Read Time
    Open Blog Page
    Every Card Should Carry Its Metadata

Card Titles Link To Their Article Path
    Open Blog Page
    ${mismatched}=    Evaluate JavaScript    ${NONE}
    ...    () => Array.from(document.querySelectorAll('.blog-page a.blog-card-title-link')).map((a) => new URL(a.href)).filter((u) => !/^\\/blog\\/[a-z0-9]+(?:-[a-z0-9]+)*$/.test(u.pathname)).map((u) => u.pathname)
    Should Be Empty    ${mismatched}    msg=Card links that are not valid article paths: ${mismatched}

Grid Shows At Most One Page Of Articles
    [Documentation]    Pagination is only visible once there is enough content,
    ...    so the assertion is on the invariant, not on a fixed
    ...    number: the grid never renders more than a page.
    Open Blog Page
    ${in_grid}=    Get Grid Card Count
    Should Be True    ${in_grid} <= ${POSTS_PER_PAGE}
    ...    msg=The grid rendered ${in_grid} cards, more than one page of ${POSTS_PER_PAGE}

At Most One Article Is Featured
    Open Blog Page
    ${featured}=    Get Element Count    ${FEATURED_CARD}
    Should Be True    ${featured} <= 1    msg=${featured} articles are marked as featured
    IF    ${featured} == 1
        Wait For Elements State    ${FEATURED_BADGE}    visible    ${TIMEOUT}
        ${badge}=    Get Text    ${FEATURED_BADGE}
        Should Be Equal    ${badge}    Featured
    END

Search Finds An Article By Its Exact Title
    Open Blog Page
    ${blogs}=    Get Published Blogs
    ${title}=    Set Variable    ${blogs}[0][title]
    Search Articles For    ${title}
    ${titles}=    Get All Card Titles
    List Should Contain Value    ${titles}    ${title}
    ...    msg=Searching for '${title}' did not surface that article

Search Tolerates A Typo
    [Documentation]    The search box matches fuzzily (Levenshtein distance,
    ...    widening with word length). A single transposed
    ...    character must still find the article.
    Open Blog Page
    ${blogs}=    Get Published Blogs
    ${title}=    Set Variable    ${blogs}[0][title]
    ${first_word}=    Evaluate    $title.split()[0]
    ${typo}=    Evaluate    $first_word[:-2] + $first_word[-1] + $first_word[-2]
    Search Articles For    ${typo}
    ${titles}=    Get All Card Titles
    List Should Contain Value    ${titles}    ${title}
    ...    msg=Fuzzy search did not recover from the typo '${typo}' (expected '${title}')

Search With No Matches Shows The Empty State
    Open Blog Page
    Search Articles For    zzzznonexistentqueryzzzz
    Wait For Elements State    ${EMPTY_INLINE}    visible    ${TIMEOUT}
    ${shown}=    Get Toolbar Article Count
    Should Be Equal As Integers    ${shown}    0

Clearing The Search Restores The Full Listing
    Open Blog Page
    ${before}=    Get Toolbar Article Count
    Search Articles For    zzzznonexistentqueryzzzz
    ${during}=    Get Toolbar Article Count
    Should Be Equal As Integers    ${during}    0
    Clear Article Search
    ${after}=    Get Toolbar Article Count
    Should Be Equal As Integers    ${after}    ${before}
    ...    msg=Clearing the search left ${after} article(s) instead of the original ${before}

Label Filter Narrows The Listing To The Right Articles
    [Documentation]    An article can carry several labels while a card shows
    ...    only the first, so the displayed label proves nothing.
    ...    The API is the source of truth: how many documents
    ...    carry this label is how many the page must show.
    Open Blog Page
    ${labels}=    Get Available Labels
    ${label_count}=    Get Length    ${labels}
    Skip If    ${label_count} == 0    No labels are in use on the site right now
    ${label}=    Set Variable    ${labels}[0]
    ${blogs}=    Get Published Blogs
    # The label is substituted as a literal rather than passed as `$label`:
    # inside a comprehension, `eval` gives the inner scope no access to the
    # locals Robot Framework injects, so only the outermost iterable can use
    # the `$name` form.
    ${expected}=    Evaluate
    ...    len([b for b in $blogs if '${label}'.lower() in [l.lower() for l in (b.get('labels') or [])]])
    Filter By Label    ${label}
    ${active}=    Get Text    ${ACTIVE_LABEL_FILTER}
    Should Be Equal    ${active}    ${label}
    Wait Until Keyword Succeeds    5x    0.5s    Toolbar Count Should Be    ${expected}

All Labels Resets The Filter
    Open Blog Page
    ${labels}=    Get Available Labels
    ${label_count}=    Get Length    ${labels}
    Skip If    ${label_count} == 0    No labels are in use on the site right now
    ${before}=    Get Toolbar Article Count
    Filter By Label    ${labels}[0]
    Click    ${LABEL_FILTER_ALL}
    Wait Until Keyword Succeeds    5x    0.5s    Toolbar Count Should Be    ${before}

Section Rows Link To Their Own Listing Page
    [Documentation]    Each topic row on the index has a standalone, indexable
    ...    page. The row heading is the link to it.
    Open Blog Page
    ${rows}=    Get Element Count    ${SECTION_ROW}
    Skip If    ${rows} == 0    The site currently groups no articles into sections
    ${section_slugs}=    Get Section Slugs
    ${href}=    Get Property    ${FIRST_SECTION_TITLE_LINK}    pathname
    ${slug}=    Evaluate    $href.rsplit('/', 1)[-1]
    List Should Contain Value    ${section_slugs}    ${slug}
    ...    msg=A section row links to '/blog/section/${slug}', which the API does not serve
    Click    ${FIRST_SECTION_TITLE_LINK}
    Wait Until Keyword Succeeds    5x    0.5s    Current Path Should Be    /blog/section/${slug}

Section Page Shows That Section And Its Articles
    ${section_slugs}=    Get Section Slugs
    ${section_count}=    Get Length    ${section_slugs}
    Skip If    ${section_count} == 0    The site has no sections right now
    ${slug}=    Set Variable    ${section_slugs}[0]
    Open Section Page    ${slug}
    Page Should Have Exactly One H1
    ${heading}=    Get Text    ${BLOG_HERO_TITLE}
    Should Not Be Empty    ${heading}
    ${cards}=    Get Rendered Card Count
    Should Be True    ${cards} > 0    msg=Section '${slug}' rendered no articles


*** Keywords ***
Toolbar Count Should Be
    [Arguments]    ${expected}
    ${actual}=    Get Toolbar Article Count
    Should Be Equal As Integers    ${actual}    ${expected}
