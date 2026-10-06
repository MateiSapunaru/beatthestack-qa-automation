*** Settings ***
Documentation       Page object for the landing page (`/`).

Library             Browser
Resource            common.robot


*** Variables ***
${HERO}                         css=section.hero
${HERO_TITLE}                   css=section.hero h1.hero-title
${HERO_DESCRIPTION}             css=section.hero p.hero-description
${AVATAR}                       css=section.hero .avatar-container
${SOCIAL_LINKS}                 css=section.hero .social-links
${SOCIAL_LINK}                  css=section.hero .social-links a.social-link
${CTA_PRIMARY}                  css=.cta-buttons a.cta-primary
${CTA_SECONDARY}                css=.cta-buttons a.cta-secondary

${EXPECTED_HERO_TITLE}          Backend engineering, taken apart.
${EXPECTED_DOCUMENT_TITLE}      Beat The Stack — Backend engineering and infrastructure


*** Keywords ***
Open Home Page
    [Arguments]    ${width}=${DESKTOP_WIDTH}    ${height}=${DESKTOP_HEIGHT}
    Open Page At    /    ${width}    ${height}
    Wait For Elements State    ${HERO}    visible    ${TIMEOUT}

Home Page Should Be Rendered
    Wait For Elements State    ${HERO_TITLE}    visible    ${TIMEOUT}
    Wait For Elements State    ${HERO_DESCRIPTION}    visible    ${TIMEOUT}
    Wait For Elements State    ${AVATAR}    visible    ${TIMEOUT}
    Wait For Elements State    ${CTA_PRIMARY}    visible    ${TIMEOUT}
    Wait For Elements State    ${CTA_SECONDARY}    visible    ${TIMEOUT}

Get Hero Title
    ${text}=    Get Text    ${HERO_TITLE}
    RETURN    ${text}

Cta Should Link To
    [Documentation]    Checks the real `href`, not just the click behaviour.
    ...    These are the links a crawler follows to discover the
    ...    rest of the site, so a click handler alone is not enough.
    [Arguments]    ${cta}    ${expected_path}
    ${href}=    Get Property    ${cta}    pathname
    Should Be Equal    ${href}    ${expected_path}
