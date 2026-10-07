# Beat The Stack — QA Automation

[![tests](https://github.com/MateiSapunaru/beatthestack-qa-automation/actions/workflows/tests.yml/badge.svg)](https://github.com/MateiSapunaru/beatthestack-qa-automation/actions/workflows/tests.yml)

An end-to-end test suite in **Robot Framework** against a production website,
[beatthestack.dev](https://beatthestack.dev) — a technical blog with a
single-page front end, a read API and a published sitemap.

The suite covers three layers — browser, HTTP API, and the documents crawlers
read — and **found three real defects** on the live site, documented below.

> **Black box, by design.** This repository holds tests and nothing else. The
> application is a third party's and its source is not here, not vendored, and
> not required: every expectation is established through the same public
> interfaces any other visitor has — rendered DOM, HTTP responses, and the
> site's own API. That is the constraint a QA engineer joining an existing
> product usually works under, so it is the one the suite is written for.

> **Read-only, by design.** The target is somebody's live site, so nothing here
> can change its state. Every request is a `GET`, every browser action is
> navigation. The write endpoints are exercised only to prove that
> authorisation refuses them *before* any handler runs, and those requests
> deliberately carry no payload that could be persisted if that assumption were
> ever wrong.

---

## Results

```
128 tests  ·  123 passed  ·  0 failed  ·  5 skipped
```

Four of the five skips are open defects, kept as live tests rather than deleted
(see [Defects found](#defects-found)). The fifth is conditional: it needs two
sections to exist before section ordering can conflict, and the site currently
has one.

| Layer | Suite | Tests | What it covers |
|---|---|---:|---|
| UI | `tests/ui/01_navigation.robot` | 10 | Routing, real `href`s, browser back/forward, cold loads of deep links, legacy `#/` redirects, scroll reset |
| UI | `tests/ui/02_static_content.robot` | 10 | Landing page and experience timeline content, heading structure, link safety, images |
| UI | `tests/ui/03_blog_listing.robot` | 16 | Listing against the API, cards, fuzzy search, label filter, pagination bound, section rows |
| UI | `tests/ui/04_blog_article.robot` | 9 | Every published article: content, metadata, JSON-LD, labels, images, XSS sinks |
| UI | `tests/ui/05_routing_negative.robot` | 10 | Slug allowlist, path traversal, over-long slugs, boundary, 404 and "unavailable" states |
| UI | `tests/ui/06_responsive.robot` | 8 | 375 / 768 / 1440 px: overflow, nav reachability, card stacking, tap targets, text size |
| API | `tests/api/01_blogs_endpoint.robot` | 14 | Response contract and field types, slug uniqueness, lookup by slug and by id, 404s, field allowlist |
| API | `tests/api/02_sections_endpoint.robot` | 6 | Section contract, slug and order uniqueness, cross-collection referential integrity |
| API | `tests/api/03_authorization.robot` | 9 | Anonymous writes, forged and `alg:none` JWTs, malformed `Authorization`, optional-auth reads |
| API | `tests/api/04_query_parameters.robot` | 10 | Draft protection, paging, NoSQL-injection probes, hostile `sortBy`, graceful degradation |
| SEO | `tests/seo/01_sitemap_and_robots.robot` | 16 | `robots.txt`, sitemap validity and reachability, cross-layer completeness, host-header poisoning |
| SEO | `tests/seo/02_page_metadata.robot` | 10 | Per-route title, canonical, Open Graph, Twitter card, JSON-LD, metadata after client-side navigation |

Tags allow slicing the run: `smoke`, `security`, `accessibility`, `seo`,
`performance`, `negative`, `contract`, `injection`, `jwt`, `known-issue`.

---

## Defects found

Each is kept as a real test, tagged `known-issue` and `robot:skip-on-failure`.
Robot Framework then reports the test as **skipped** with the original failure
attached, so an open defect stays visible in every report without failing the
build — and the test turns into a genuine pass the moment it is fixed. Nothing
is commented out.

### BTS-1 · `/work` has no `<h1>` · *accessibility, SEO*

The page renders no top-level heading at all. Its first heading is the `<h2>`
"A sneak peek into my past achievments", so the heading hierarchy starts at
level 2 and skips level 1.

Screen readers let users navigate by heading level, and a document whose
outline has no root is harder to move through (WCAG 2.1 SC 1.3.1). It also
leaves the page without the element search engines weigh most heavily, even
though the route does set a correct `<title>` and description. The landing
page's own source carries a comment explaining that it was given an `<h1>` for
exactly this reason — `/work` was not.

*Covered by:* `Work Page Has A Top Level Heading`,
`Heading Hierarchy Should Not Skip A Level`

### BTS-2 · Tap targets below the minimum size at phone width · *accessibility*

At a 375 px viewport:

| Control | Measured | Required |
|---|---|---|
| Header nav links ("Who am I", "Blog") | 62×20, 29×20 | 24×24 |
| Card "Read" links | 53×18 | 24×24 |
| Label filter buttons | ~86×31 | 24×24 ✓ (44×44 ✗) |
| Carousel buttons | 40×40 | 24×24 ✓ (44×44 ✗) |

Figures are from Chromium on Windows. Font metrics differ by platform, so the
same controls measure a few pixels smaller on the Linux CI runner — which
changes the numbers, not the verdict. The test asserts the threshold rather
than these values, so it holds on either.

WCAG 2.2 SC 2.5.8 (Level AA) sets the floor at 24×24 CSS pixels. The first two
rows are under it. The criterion does exempt a target spaced far enough from
its neighbours, which may cover the two header links; it does not cover the
per-card "Read" links, which sit directly beneath the card title link.

*Covered by:* `Interactive Controls Meet The Minimum Tap Target Size`

### BTS-3 · Populated sections are missing from the sitemap · *SEO*

A section listing page is real and indexable: it renders an article, sets its
own canonical URL and carries no `robots` meta tag. It does not appear in
`sitemap.xml`.

Comparing the public API against the sitemap shows why. A section is omitted
whenever no explicit article ordering has been saved for it — but ordering and
membership are two different things, and membership is what the page renders
from. A section that holds articles but whose order was never customised
therefore looks empty to the sitemap and is dropped. That is the state the live
site is in: one section, one published article in it, zero sitemap entries
for it.

The omission rule reads a different signal from the one the page renders from.
The test derives its expectation from article membership, so it passes as soon
as the two agree.

*Covered by:* `Sections That Render Articles Appear In The Sitemap`

### BTS-4 · Typo in the `/work` heading · *content, cosmetic*

"A sneak peek into my past **achievments**" → "achievements". Found by reading,
not by a test; a spell-check assertion against prose would be noise.

---

## What the suite confirmed is solid

Worth stating, because a test report that only lists problems is not a report:

- **Slug handling.** Eleven hostile slugs — encoded path traversal, malformed
  percent-encoding, a `<script>` payload, backslash traversal, case and
  separator variations — are all refused, by two independent layers. Three are
  rejected upstream with a 400 and never reach the application; the rest are
  stopped by the router's allowlist *before* any API request is issued, which
  the suite verifies from the browser's Resource Timing buffer rather than
  inferring from the rendered page.
- **Injection resistance.** `?search={"$ne":""}`, `{"$gt":""}` and
  `{"$regex":".*"}` are all treated as literal text and match nothing. Hostile
  `sortBy` values (`__proto__`, `constructor`, `this.password`) and malformed
  numerics (`limit=abc`, `skip=-1`) degrade to a plain 200 — no endpoint could
  be made to throw from the query string.
- **Authorisation.** Every write route refuses anonymous callers with 401, and
  forged tokens — including an `alg: none` token claiming to be an admin — with
  403. An unverifiable token on a public read is dropped rather than erroring,
  and returns byte-for-byte the anonymous result set.
- **Draft protection.** `?published=false` is refused with 401 rather than
  silently serving the published set.
- **Sitemap integrity.** Entry URLs are built from pinned configuration, not
  the request. A forged `X-Forwarded-Host`, `X-Host` or `X-Original-URL` does
  not change a single `<loc>` — the SEO-poisoning vector is closed.
- **Metadata.** Every route publishes its own title, description, canonical
  URL, Open Graph set and Twitter card, and they survive client-side
  navigation rather than going stale after an in-app click.

---

## Design notes

**Expectations are derived, not hardcoded.** The suite reads the article list,
slugs, titles, labels and sections from the API at run time and asserts the
rendered page against them. Publishing a new article does not break a single
test; a listing that drops, duplicates or mislabels one does. This also makes
several tests genuine cross-layer consistency checks — the listing against the
API, the sitemap against the database, section rows against the sections
endpoint.

**Page objects, with locators in one place.** `resources/pages/` holds a file
per page: locators as variables, intent as keywords. Tests read as statements
about behaviour and contain no CSS. `resources/api/` does the same for HTTP,
including the response-contract keywords.

**Asserting what did *not* happen.** The most valuable test here reads
`performance.getEntriesByType('resource')` to prove that a rejected slug
produced no API request at all. No amount of DOM inspection can show that.

**Open defects stay in the suite.** `robot:skip-on-failure` is Robot
Framework's own mechanism for a known failure: the test runs, fails, and is
reported as skipped with the failure text attached. The defect is visible in
every report, the build stays green, and the test starts passing on its own
when the bug is fixed.

**Flakiness is designed out, not retried away.** Browser Library auto-waits, so
there is not a single blind `Sleep` for a page to settle. The two deliberate
waits are documented: 400 ms for the search box's own debounce, and a retried
check for cover images, because the largest is over half a megabyte and
measuring once reports a still-decoding image as a broken one. That particular
false positive is why the suite reports three defects and not four.

---

## Running it

Requires Python 3.11+ and Node 20+ (Browser Library drives Playwright).

```bash
python -m venv .venv
.venv/Scripts/python -m pip install -r requirements.txt
.venv/Scripts/rfbrowser init chromium
```

```bash
robot --outputdir results tests/
```

On Windows, `./run.ps1` wraps the same command and pins `PYTHONIOENCODING`,
which some shells export in a form Robot Framework cannot parse.

Useful variations:

```bash
robot --outputdir results --include smoke tests/
robot --outputdir results --include security tests/
robot --outputdir results --variable HEADLESS:False tests/ui
robot --outputdir results --variable BASE_URL:http://localhost:5173 tests/
robocop check
```

Every environment value — base URL, browser, timeouts, viewports, thresholds —
lives in `resources/config/environments.robot` and can be overridden with
`--variable`, so the same suite points at local, staging or production without
an edit.

Results land in `results/`: `report.html` for the summary, `log.html` for
step-by-step detail with a full-page screenshot attached to every failure.

---

## Continuous integration

`.github/workflows/tests.yml` runs on every push and pull request, and nightly
at 06:00 UTC. Because the target is a live site, the nightly run is real
monitoring: it catches a regression that was deployed rather than committed.

The workflow lints with Robocop, caches the Playwright browsers against the
resolved Browser Library version, runs the suite, uploads `results/` as an
artifact on success *and* failure, and publishes the report to GitHub Pages
from `main`.

> Publishing the report needs Pages enabled once, under
> **Settings → Pages → Source: GitHub Actions**.

---

## Layout

```
resources/
  config/
    environments.robot    URLs, browser, timeouts, viewports, thresholds, the shared slug pattern
    test_data.robot       Hostile slugs, unroutable paths, protected endpoints, forged tokens
  pages/
    common.robot          Browser lifecycle, site chrome, metadata and network helpers
    home_page.robot       Landing page
    work_page.robot       Experience timeline
    blog_page.robot       Blog index and section listings
    article_page.robot    Single article
    not_found_page.robot  404 view and the two "content missing" states
  api/
    public_api.robot      Sessions, read keywords, response contracts, SLA and leakage checks
tests/
  ui/    6 suites    Browser behaviour
  api/   4 suites    HTTP contract and authorisation
  seo/   2 suites    Crawler-facing documents and per-route metadata
```

---

## Scope and limitations

- The site's admin console is out of scope: exercising it needs credentials
  this suite deliberately does not have.
- Link previews are not asserted. Metadata is applied client-side; search
  engines execute JavaScript and index it correctly, but most social scrapers
  do not, so a shared link still shows the static `index.html` metadata.
  Closing that gap needs server-side meta injection, which is a product change
  rather than a test gap — the suite describes what a JavaScript-executing
  crawler sees and says so.
- Visual regression is not covered. Pixel comparison against a site this suite
  does not control would report every design change as a failure.
- Load and stress testing is out of scope, deliberately: it is somebody's
  production site.

---

*Test suite by [Matei Săpunaru](https://github.com/MateiSapunaru). The
application under test belongs to a third party and its source is not included
in, or required by, this repository.*
