*** Settings ***
Documentation       The two documents crawlers fetch from fixed paths, and the
...                 one property that makes them safe to serve.
...
...                 Both are built by the backend and served at the site root
...                 rather than under /api, so they are reachable by anyone.
...                 Their URLs are built from pinned configuration rather than
...                 from the request's own `Host`, which is what stops a
...                 forged header from rewriting the canonical host of every
...                 entry — an SEO-poisoning vector this suite probes directly.

Library             Collections
Library             String
Library             XML
Library             RequestsLibrary
Resource            ../../resources/api/public_api.robot

Suite Setup         Run Keywords    Create Site Session    AND    Create Public Api Session

Test Tags           seo


*** Variables ***
${SITE_SESSION}                 site
@{STATIC_SITEMAP_PATHS}         /    /work    /blog
# The enumerated values sitemaps.org allows for <changefreq>.
@{VALID_CHANGEFREQS}            always    hourly    daily    weekly    monthly    yearly    never


*** Test Cases ***
# =============================================================================
# robots.txt
# =============================================================================

Robots Document Is Served As Plain Text
    [Tags]    smoke
    ${response}=    GET On Session    ${SITE_SESSION}    /robots.txt    expected_status=200
    ${content_type}=    Get From Dictionary    ${response.headers}    Content-Type
    Should Contain    ${content_type}    text/plain
    ${nosniff}=    Get From Dictionary    ${response.headers}    X-Content-Type-Options
    Should Be Equal    ${nosniff}    nosniff

Robots Document Allows The Public Site And Closes The Rest
    ${body}=    Get Robots Text
    Should Contain    ${body}    User-agent: *
    Should Contain    ${body}    Allow: /
    Should Contain    ${body}    Disallow: /api/
    Should Contain    ${body}    Disallow: /admin

Robots Document Points At The Sitemap By Absolute Url
    [Documentation]    The sitemap directive has to be an absolute URL on the
    ...    canonical host: a relative path there is ignored.
    ${body}=    Get Robots Text
    Should Contain    ${body}    Sitemap: ${BASE_URL}/sitemap.xml

Robots Document Is Cacheable
    ${response}=    GET On Session    ${SITE_SESSION}    /robots.txt    expected_status=200
    ${cache}=    Get From Dictionary    ${response.headers}    Cache-Control
    Should Contain    ${cache}    max-age=${EMPTY}

# =============================================================================
# sitemap.xml
# =============================================================================

Sitemap Is Served As Xml
    [Tags]    smoke
    ${response}=    GET On Session    ${SITE_SESSION}    /sitemap.xml    expected_status=200
    ${content_type}=    Get From Dictionary    ${response.headers}    Content-Type
    Should Contain    ${content_type}    xml
    ${nosniff}=    Get From Dictionary    ${response.headers}    X-Content-Type-Options
    Should Be Equal    ${nosniff}    nosniff

Sitemap Is Well Formed And Not Empty
    [Tags]    smoke
    ${root}=    Get Sitemap Root
    Should Be Equal    ${root.tag}    urlset
    ${urls}=    Get Elements    ${root}    url
    Should Not Be Empty    ${urls}    msg=The sitemap declares no URLs

Every Sitemap Entry Is Absolute And On The Canonical Host
    [Documentation]    A relative or off-host `<loc>` is either ignored or,
    ...    worse, hands the ranking to another domain.
    ${locations}=    Get Sitemap Locations
    FOR    ${location}    IN    @{locations}
        Should Start With    ${location}    ${BASE_URL}/
        ...    msg='${location}' is not an absolute URL on ${BASE_URL}
    END

Every Sitemap Path Is A Route The Site Actually Serves
    [Documentation]    The sitemap is a list of promises. Each entry must be a
    ...    known static route, an article path or a section path,
    ...    with a slug satisfying the public allowlist.
    ${locations}=    Get Sitemap Locations
    FOR    ${location}    IN    @{locations}
        ${path}=    Evaluate    urllib.parse.urlsplit($location).path    modules=urllib.parse
        Sitemap Path Should Be Routable    ${path}
    END

Sitemap Contains No Duplicate Entries
    ${locations}=    Get Sitemap Locations
    ${unique}=    Remove Duplicates    ${locations}
    Lists Should Be Equal    ${locations}    ${unique}
    ...    msg=The sitemap repeats entries, which splits ranking signals across identical URLs

Sitemap Lists Every Static Route
    ${locations}=    Get Sitemap Locations
    FOR    ${path}    IN    @{STATIC_SITEMAP_PATHS}
        List Should Contain Value    ${locations}    ${BASE_URL}${path}
        ...    msg=Static route '${path}' is missing from the sitemap
    END

Sitemap Lists Every Published Article
    [Documentation]    Cross-layer: the sitemap is built from the database, so
    ...    an article the API publishes but the sitemap omits
    ...    will not be discovered.
    [Tags]    smoke
    ${locations}=    Get Sitemap Locations
    ${slugs}=    Get Published Slugs
    FOR    ${slug}    IN    @{slugs}
        List Should Contain Value    ${locations}    ${BASE_URL}/blog/${slug}
        ...    msg=Published article '${slug}' is missing from the sitemap
    END

Sitemap Lists No Article That Is Not Published
    [Documentation]    The other direction. A sitemap entry for a draft invites
    ...    a crawler to a page the API will refuse.
    ${locations}=    Get Sitemap Locations
    ${slugs}=    Get Published Slugs
    FOR    ${location}    IN    @{locations}
        ${path}=    Evaluate    urllib.parse.urlsplit($location).path    modules=urllib.parse
        ${is_article}=    Evaluate
        ...    $path.startswith('/blog/') and not $path.startswith('/blog/section/')
        IF    ${is_article}
            ${slug}=    Evaluate    $path[len('/blog/'):]
            List Should Contain Value    ${slugs}    ${slug}
            ...    msg=The sitemap advertises '/blog/${slug}', which the API does not publish
        END
    END

Every Sitemap Url Is Reachable
    [Documentation]    Walks the whole sitemap. A 404 or a redirect in here
    ...    spends crawl budget on nothing.
    ${locations}=    Get Sitemap Locations
    FOR    ${location}    IN    @{locations}
        ${response}=    GET    ${location}    expected_status=200
        Should Be Equal As Integers    ${response.status_code}    200
    END

Sitemap Metadata Is Within Its Allowed Ranges
    [Documentation]    `priority` outside 0.0–1.0 and a `changefreq` outside
    ...    the enumerated set make the document invalid against
    ...    the sitemaps.org schema.
    ${root}=    Get Sitemap Root
    ${urls}=    Get Elements    ${root}    url
    FOR    ${url}    IN    @{urls}
        ${priority}=    Get Optional Child Text    ${url}    priority
        IF    $priority is not None
            Should Be True    0.0 <= ${priority} <= 1.0
            ...    msg=priority '${priority}' is outside the 0.0-1.0 range
        END
        ${changefreq}=    Get Optional Child Text    ${url}    changefreq
        IF    $changefreq is not None
            List Should Contain Value    ${VALID_CHANGEFREQS}    ${changefreq}
            ...    msg=changefreq '${changefreq}' is not one of the values sitemaps.org defines
        END
        ${lastmod}=    Get Optional Child Text    ${url}    lastmod
        IF    $lastmod is not None    Timestamp Should Be Iso 8601    ${lastmod}
    END

Sitemap Ignores A Forged Host Header
    [Documentation]    The one security property of this document. If entries
    ...    were built from the request's own host, anyone could
    ...    make the site advertise a sitemap full of URLs on a
    ...    domain they control — and a crawler that fetched it
    ...    would attribute the content there.
    ...
    ...    `X-Forwarded-Host` is the realistic vector: it survives
    ...    a proxy hop, which `Host` does not.
    [Tags]    security
    [Template]    Sitemap Should Ignore Header
    X-Forwarded-Host    evil.example.com
    X-Forwarded-Host    beatthestack.dev.evil.example.com
    X-Original-URL    //evil.example.com/sitemap.xml
    X-Forwarded-Proto    http
    X-Host    evil.example.com

Sections That Render Articles Appear In The Sitemap
    [Documentation]    *Known defect — see README, finding BTS-3.*
    ...
    ...    Section pages are canonical and explicitly indexable:
    ...    a section listing renders an article, sets its own
    ...    canonical URL and carries no robots tag. A section is
    ...    nevertheless omitted from the sitemap when no explicit
    ...    article ordering has been saved for it, on the grounds
    ...    that an empty section is a thin page.
    ...
    ...    But ordering and membership are two different things,
    ...    and membership is what the page renders from. A section
    ...    that holds articles but whose order was never
    ...    customised therefore looks empty to the sitemap and is
    ...    dropped, which is the state the live site is in.
    ...
    ...    Expectations here are derived from article membership,
    ...    so this passes the moment the check reads the same
    ...    signal the page renders from.
    [Tags]    known-issue    robot:skip-on-failure
    ${locations}=    Get Sitemap Locations
    ${blogs}=    Get Published Blogs
    ${populated}=    Evaluate
    ...    sorted({s['slug'] for b in $blogs for s in (b.get('sections') or []) if 'slug' in s})
    Should Not Be Empty    ${populated}
    ...    msg=No section currently holds a published article, so there is nothing to assert
    FOR    ${slug}    IN    @{populated}
        List Should Contain Value    ${locations}    ${BASE_URL}/blog/section/${slug}
        ...    msg=Section '${slug}' renders published articles but is missing from the sitemap
    END


*** Keywords ***
Get Robots Text
    ${response}=    GET On Session    ${SITE_SESSION}    /robots.txt    expected_status=200
    RETURN    ${response.text}

Get Sitemap Root
    [Arguments]    &{headers}
    ${response}=    GET On Session    ${SITE_SESSION}    /sitemap.xml    expected_status=200
    ...    headers=${headers}
    ${root}=    Parse Xml    ${response.text}
    RETURN    ${root}

Get Sitemap Locations
    [Documentation]    Every `<loc>` in document order. Robot Framework's XML
    ...    library strips namespaces, so the sitemaps.org default
    ...    namespace does not have to appear in the paths above.
    [Arguments]    &{headers}
    ${root}=    Get Sitemap Root    &{headers}
    ${elements}=    Get Elements    ${root}    url/loc
    ${locations}=    Evaluate    [e.text.strip() for e in $elements]
    RETURN    ${locations}

Get Optional Child Text
    [Arguments]    ${element}    ${child}
    ${found}=    Get Elements    ${element}    ${child}
    ${count}=    Get Length    ${found}
    IF    ${count} == 0    RETURN    ${NONE}
    ${text}=    Evaluate    $found[0].text.strip()
    RETURN    ${text}

Sitemap Path Should Be Routable
    [Documentation]    A sitemap entry is either one of the static routes or an
    ...    article or section path whose slug satisfies the same
    ...    allowlist the application enforces. The pattern is
    ...    built from the shared slug fragment so the two cannot
    ...    drift apart.
    [Arguments]    ${path}
    ${is_static}=    Evaluate    $path in $STATIC_SITEMAP_PATHS
    IF    ${is_static}    RETURN
    Should Match Regexp    ${path}    ^/blog/(?:section/)?${SLUG_CORE}$
    ...    msg=The sitemap advertises '${path}', which is neither a static route nor a valid article or section path

Sitemap Should Ignore Header
    [Arguments]    ${header}    ${value}
    ${headers}=    Create Dictionary    ${header}=${value}    User-Agent=${USER_AGENT}
    ${locations}=    Get Sitemap Locations    &{headers}
    Should Not Be Empty    ${locations}
    FOR    ${location}    IN    @{locations}
        Should Start With    ${location}    ${BASE_URL}/
        ...    msg=With ${header}: ${value}, the sitemap advertised '${location}'
    END
