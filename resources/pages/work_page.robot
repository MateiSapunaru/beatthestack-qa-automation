*** Settings ***
Documentation       Page object for the experience timeline (`/work`).

Library             Browser
Resource            common.robot


*** Variables ***
${TIMELINE}                     css=.timeline
${TIMELINE_EYEBROW}             css=.timeline .timeline-eyebrow
${TIMELINE_TITLE}               css=.timeline .timeline-title
${TIMELINE_TRACK}               css=.timeline .timeline-track
${TIMELINE_ENTRY}               css=.timeline article.timeline-entry
${TIMELINE_CURRENT_ENTRY}       css=.timeline article.timeline-entry.is-current
${TIMELINE_CARD}                css=.timeline .timeline-card
${TIMELINE_CARD_TITLE}          css=.timeline .timeline-card-title
${TIMELINE_CARD_ROLE}           css=.timeline .timeline-card-role
${TIMELINE_PERIOD_LABEL}        css=.timeline .timeline-period-label
${TIMELINE_POINTS}              css=.timeline .timeline-points li

# Quoted in a failure message, so it lives next to the locators it describes.
${TIMELINE_TITLE_TEXT}          A sneak peek into my past achievments


*** Keywords ***
Open Work Page
    [Arguments]    ${width}=${DESKTOP_WIDTH}    ${height}=${DESKTOP_HEIGHT}
    Open Page At    /work    ${width}    ${height}
    Wait For Elements State    ${TIMELINE}    visible    ${TIMEOUT}

Work Page Should Be Rendered
    Wait For Elements State    ${TIMELINE_TITLE}    visible    ${TIMEOUT}
    Wait For Elements State    ${TIMELINE_TRACK}    visible    ${TIMEOUT}
    ${cards}=    Get Element Count    ${TIMELINE_CARD}
    Should Be True    ${cards} > 0    msg=The timeline rendered no entries

Every Timeline Entry Should Be Complete
    [Documentation]    Each entry promises a period, a title, a role and at
    ...    least one bullet. Checked across all entries, because a
    ...    data-mapping bug usually shows up on the second one.
    ${incomplete}=    Evaluate JavaScript    ${NONE}
    ...    () => Array.from(document.querySelectorAll('.timeline article.timeline-entry')).map((entry, i) => ({ index: i, period: !!entry.querySelector('.timeline-period-label')?.textContent.trim(), title: !!entry.querySelector('.timeline-card-title')?.textContent.trim(), role: !!entry.querySelector('.timeline-card-role')?.textContent.trim(), points: entry.querySelectorAll('.timeline-points li').length, stack: entry.querySelectorAll('.timeline-stack span').length })).filter((e) => !e.period || !e.title || !e.role || e.points === 0 || e.stack === 0)
    Should Be Empty    ${incomplete}    msg=Incomplete timeline entries: ${incomplete}
