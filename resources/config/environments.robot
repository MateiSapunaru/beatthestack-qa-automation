*** Settings ***
Documentation       Environment configuration for the whole suite.
...
...                 Nothing here is hardcoded in a test: every value can be
...                 overridden from the command line, which is what lets the
...                 same suite run against staging or a local build.
...
...                 Example:
...                 | robot --variable BASE_URL:http://localhost:5173 --variable HEADLESS:False tests/


*** Variables ***
# --- System under test -------------------------------------------------------
${BASE_URL}                     https://beatthestack.dev
${API_URL}                      ${BASE_URL}/api

# --- Browser -----------------------------------------------------------------
${BROWSER}                      chromium
${HEADLESS}                     ${TRUE}
# Browser Library auto-waits, so this is a ceiling for genuinely slow
# responses, not a sleep that every test pays for.
${TIMEOUT}                      15s

# --- Viewports ---------------------------------------------------------------
${DESKTOP_WIDTH}                ${1440}
${DESKTOP_HEIGHT}               ${900}
${TABLET_WIDTH}                 ${768}
${TABLET_HEIGHT}                ${1024}
${MOBILE_WIDTH}                 ${375}
${MOBILE_HEIGHT}                ${812}

# --- Non-functional thresholds -----------------------------------------------
# Deliberately generous: these exist to catch a regression into seconds, not to
# benchmark the hosting. A tight budget on a cached, edge-served response in CI
# is a flaky test, not a useful one.
${API_MAX_RESPONSE_MS}          ${2500}

# --- Contracts ---------------------------------------------------------------
# The same slug allowlist the application enforces in two independent places
# (frontend router and backend sitemap builder). Tests assert against it rather
# than against a snapshot of today's content.
${SLUG_CORE}                    [a-z0-9]+(?:-[a-z0-9]+)*
${SLUG_PATTERN}                 ^${SLUG_CORE}$
${MAX_SLUG_LENGTH}              ${250}
