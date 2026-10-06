*** Settings ***
Documentation       Responsive layout across phone, tablet and desktop widths.
...
...                 These are the checks that are worth automating: a
...                 horizontal scrollbar, chrome that disappears, tap targets
...                 too small to hit, text too small to read. Whether the
...                 design *looks* right at each width is a human judgement and
...                 stays out of here.

Resource            ../../resources/pages/common.robot
Resource            ../../resources/pages/home_page.robot
Resource            ../../resources/pages/blog_page.robot

Suite Setup         Start Browser Session
Test Teardown       Close Page Session

Test Tags           ui    responsive


*** Test Cases ***
Landing Page Fits Every Viewport
    [Documentation]    Content wider than the viewport forces sideways
    ...    scrolling, which on a phone is the difference between
    ...    a usable page and an unusable one.
    [Template]    Page Should Fit Viewport
    /    ${MOBILE_WIDTH}    ${MOBILE_HEIGHT}
    /    ${TABLET_WIDTH}    ${TABLET_HEIGHT}
    /    ${DESKTOP_WIDTH}    ${DESKTOP_HEIGHT}

Blog Index Fits Every Viewport
    [Template]    Page Should Fit Viewport
    /blog    ${MOBILE_WIDTH}    ${MOBILE_HEIGHT}
    /blog    ${TABLET_WIDTH}    ${TABLET_HEIGHT}
    /blog    ${DESKTOP_WIDTH}    ${DESKTOP_HEIGHT}

Work Page Fits Every Viewport
    [Template]    Page Should Fit Viewport
    /work    ${MOBILE_WIDTH}    ${MOBILE_HEIGHT}
    /work    ${TABLET_WIDTH}    ${TABLET_HEIGHT}
    /work    ${DESKTOP_WIDTH}    ${DESKTOP_HEIGHT}

Navigation Stays Reachable On A Phone
    [Documentation]    Narrow layouts are where navigation usually gets hidden
    ...    behind a menu that was never built. Both links have to
    ...    stay visible and clickable at 375px.
    [Tags]    smoke
    Open Page At    /    ${MOBILE_WIDTH}    ${MOBILE_HEIGHT}
    Wait For Elements State    ${NAV}    visible    ${TIMEOUT}
    Wait For Elements State    ${NAV_WORK}    visible    ${TIMEOUT}
    Wait For Elements State    ${NAV_BLOG}    visible    ${TIMEOUT}
    Navigate Via Header To    ${NAV_BLOG}    /blog

Calls To Action Stay Visible On A Phone
    Open Page At    /    ${MOBILE_WIDTH}    ${MOBILE_HEIGHT}
    Wait For Elements State    ${CTA_PRIMARY}    visible    ${TIMEOUT}
    Wait For Elements State    ${CTA_SECONDARY}    visible    ${TIMEOUT}

Article Cards Stack Into A Single Column On A Phone
    [Documentation]    At 375px the cards must sit one above the other. Two
    ...    cards sharing a row at that width means each is about
    ...    170px across, which is not a readable card.
    Open Page At    /blog    ${MOBILE_WIDTH}    ${MOBILE_HEIGHT}
    Blog Listing Should Be Loaded
    ${widest}=    Evaluate JavaScript    ${NONE}
    ...    () => Math.max(...Array.from(document.querySelectorAll('.blog-page .blog-posts-grid article.blog-card')).map((c) => c.getBoundingClientRect().width), 0)
    Should Be True    ${widest} > ${MOBILE_WIDTH} * 0.6
    ...    msg=The widest card is only ${widest}px across in a ${MOBILE_WIDTH}px viewport, so the grid did not collapse to one column

Interactive Controls Meet The Minimum Tap Target Size
    [Documentation]    *Known defect — see README, finding BTS-2.*
    ...
    ...    WCAG 2.2 SC 2.5.8 (Level AA) sets the floor at 24x24
    ...    CSS pixels. At 375px wide the header navigation links
    ...    measure 20px tall and each card's "Read" link 18px, so
    ...    both are under it. The label filters (31px) and the
    ...    carousel buttons (40px) clear AA but miss the 44x44
    ...    that SC 2.5.5 asks for at AAA.
    ...
    ...    The criterion does allow an undersized target that is
    ...    spaced far enough from its neighbours, which may cover
    ...    the two header links; it does not cover the "Read"
    ...    links, which sit directly under the card title link.
    ...    Tagged `robot:skip-on-failure` so the open defect is
    ...    reported without failing the run.
    [Tags]    accessibility    known-issue    robot:skip-on-failure
    Open Page At    /blog    ${MOBILE_WIDTH}    ${MOBILE_HEIGHT}
    Blog Listing Should Be Loaded
    ${small}=    Evaluate JavaScript    ${NONE}
    ...    () => Array.from(document.querySelectorAll('.blog-page button, .blog-page a.blog-card-link, .blog-page a.blog-card-title-link, header.header a.nav-link')).filter((el) => { const r = el.getBoundingClientRect(); return r.width > 0 && (r.width < 24 || r.height < 24); }).map((el) => ({ text: el.textContent.trim().slice(0, 30), width: Math.round(el.getBoundingClientRect().width), height: Math.round(el.getBoundingClientRect().height) }))
    Should Be Empty    ${small}    msg=Controls below the 24x24px minimum target size: ${small}

Body Text Is Readable Without Zooming
    [Documentation]    Anything under 12px is effectively unreadable on a
    ...    phone and is a common consequence of a desktop-first
    ...    stylesheet that forgot one breakpoint.
    [Tags]    accessibility
    Open Page At    /    ${MOBILE_WIDTH}    ${MOBILE_HEIGHT}
    ${tiny}=    Evaluate JavaScript    ${NONE}
    ...    () => Array.from(document.querySelectorAll('p, li, a, span, h1, h2, h3')).filter((el) => el.textContent.trim().length > 20 && parseFloat(getComputedStyle(el).fontSize) < 12).map((el) => ({ tag: el.tagName, size: getComputedStyle(el).fontSize, text: el.textContent.trim().slice(0, 40) }))
    Should Be Empty    ${tiny}    msg=Text rendered below 12px: ${tiny}


*** Keywords ***
Page Should Fit Viewport
    [Arguments]    ${path}    ${width}    ${height}
    Open Page At    ${path}    ${width}    ${height}
    # Routes that render from fetched data need their content in place before
    # the measurement means anything. The placeholder is only present on those
    # routes, and waiting for it to detach is a no-op on the rest.
    Wait For Elements State    css=.blog-loading    detached    ${TIMEOUT}
    Page Should Not Scroll Horizontally
