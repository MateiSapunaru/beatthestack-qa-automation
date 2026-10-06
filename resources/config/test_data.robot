*** Settings ***
Documentation       Static test data. Content-dependent values (slugs, titles,
...                 counts) are deliberately absent — those are read from the
...                 API at runtime so the suite does not go red every time an
...                 article is published.


*** Variables ***
# --- Routes that must always exist -------------------------------------------
@{PUBLIC_ROUTES}                /    /work    /blog

# --- Inputs the slug allowlist must reject -----------------------------------
# The frontend router filters every URL segment through
# ^[a-z0-9]+(?:-[a-z0-9]+)*$ before interpolating it into an API path. Each
# entry below targets a different way that check could be written wrongly.
#
# Percent-encoded separators matter here: a browser normalises a literal
# "/blog/../../api/auth" away before the request leaves, so the traversal only
# reaches the router at all when the separators are encoded.
#
# Every one of these must be refused, but not all of them by the same layer —
# see @{ROUTER_REJECTED_SLUGS} below.
@{REJECTED_SLUGS}
...                             ..%2F..%2Fapi%2Fauth    # path traversal into the auth endpoint
...                             %2E%2E%2Fsections    # encoded dot-dot segment
...                             Asynchronous-NodeJS    # uppercase
...                             article_with_underscore    # underscore is not a separator
...                             article--double-dash    # empty label between separators
...                             -leading-dash
...                             trailing-dash-
...                             article%20with%20spaces
...                             <script>alert(1)</script>    # reflected-XSS probe
...                             %E0%A4%A    # malformed percent-encoding
...                             ..%5C..%5Cwindows    # backslash traversal

# The subset that reaches the application. The three left out
# (..%2F..%2Fapi%2Fauth, %E0%A4%A, ..%5C..%5Cwindows) carry encoded separators
# or malformed percent-encoding and are refused upstream with a 400, so the
# router never sees them and there is no 404 view to assert on. They are still
# covered by the invariant that holds at both layers: no API request is issued
# and no article is rendered.
@{ROUTER_REJECTED_SLUGS}
...                             %2E%2E%2Fsections
...                             Asynchronous-NodeJS
...                             article_with_underscore
...                             article--double-dash
...                             -leading-dash
...                             trailing-dash-
...                             article%20with%20spaces
...                             <script>alert(1)</script>

# --- Routes that must resolve to the not-found view --------------------------
# Structurally unroutable paths. A *well-formed* path pointing at content that
# does not exist is a different case and has its own tests: the article route
# renders an "unavailable" state and the section route its own empty state,
# neither of which is the 404 view.
@{UNKNOWN_ROUTES}
...                             /this-route-does-not-exist
...                             /blog/a/b/c    # too many segments
...                             /blog/section/a/b    # section takes exactly one slug
...                             /work/extra    # /work takes no child route
...                             /admin    # the console lives on its own host

# A syntactically valid slug with no document behind it.
${MISSING_ARTICLE_SLUG}         article-that-was-never-published
${MISSING_SECTION_SLUG}         section-that-was-never-created

# --- Write endpoints that must stay closed to anonymous callers --------------
# Only the method and path: the suite never sends a body that could be
# persisted, because the point is that authorisation rejects the call first.
@{PROTECTED_WRITE_ENDPOINTS}
...                             POST|/blogs
...                             PUT|/blogs/000000000000000000000000
...                             DELETE|/blogs/000000000000000000000000
...                             POST|/sections
...                             PUT|/sections/000000000000000000000000
...                             DELETE|/sections/000000000000000000000000

@{PROTECTED_READ_ENDPOINTS}
...                             /blogs/stats/geography
...                             /blogs/000000000000000000000000/stats/geography

# --- Tokens that must never authenticate -------------------------------------
@{INVALID_TOKENS}
...                             not-a-jwt
...                             eyJhbGciOiJub25lIiwidHlwIjoiSldUIn0.eyJzdWIiOiJhZG1pbiJ9.    # alg:none
...                             eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJzdWIiOiJhZG1pbiJ9.bad-signature
