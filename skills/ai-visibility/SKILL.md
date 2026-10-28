---
name: ai-visibility
description: Track whether a client's brand shows up when buyers ask AI answer engines (ChatGPT, Google/Gemini, Copilot, Perplexity) about what they sell, at a weekly cadence, and turn the result into site and off-site changes. Use when setting up AI or "GEO/AEO" visibility tracking for a site, running a round, reading a round's report, or deciding what to change to show up in AI answers. NOT classic rank tracking (use Search Console), and NOT a content-generation exercise — the method explicitly refuses doorway pages per market.
allowed-tools: Read, Write, Edit, Glob, Grep, Bash
---

# AI answer-engine visibility

**The job:** ask the engines a fixed set of buyer questions every week, score each answer the
same way, and act on what the answers cite. The runner is
[templates/ai-visibility/run.py](../../templates/ai-visibility/run.py) (stdlib Python).

## How an answer is built, and which part we can move

An AI answer draws on two things. **Trained knowledge** — what the web said about a brand when
the model was trained; moves only with new model releases, months to a year. **Live
retrieval** — for product questions the engine searches, reads the top results, and writes from
them; moves within weeks of a change. The tracker mostly measures retrieval. An ungrounded
engine (Gemini without search) is the read on trained knowledge.

What moves retrieval, roughly in order:

1. **Third-party sources.** Engines trust distributor pages, roundups, forums and datasheets over
   a maker describing itself. The cited-domains list per segment is the off-site to-do list.
2. **Crawlability.** Check first: robots.txt, Cloudflare's AI-crawler blocking (on by default
   for new zones since mid-2025), and a fetch of the homepage as OAI-SearchBot, PerplexityBot,
   ClaudeBot and GPTBot. Nothing else matters if they're blocked.
3. **Classic SEO.** Retrieval is a search; authority still counts.
4. **Machine-readable product truth.** Product/ProductGroup schema with specs, certifications
   (`hasCertification`) and applications, mirrored in visible page text. Datasheets and
   manuals as **text-searchable PDFs** — engines cite them directly (see
   [pdf-vector-text-ocr](../../memory/seo/pdf-vector-text-ocr.md); `--skip-text` lies).
5. **Entity clarity.** Organization schema with `sameAs` (LinkedIn, Wikidata, Google Business
   Profile, distributor listings), description, founding date; one consistent brand name
   off-site. Run the branded "What is <brand>?" query first: if the engine doesn't know the
   company, that outranks everything else.

**Refuse doorway pages.** "One page per market" is the reflex every marketing playbook reaches
for, and Google penalizes it as scaled content abuse (March 2024). Mark what the product is
suitable for in the product data instead. A buyer's question about a market is answered by
the product's own data, not by a page written to rank.

**Paid placement exists around answers** (ChatGPT ads in the free tier, Google ads in AI
Overviews), not inside them. Don't sell it as buying the recommendation.

## Accounts and secrets — nothing in this package

Everything tied to a person's or client's account stays on the developer's machine:

- **API keys:** `~/.config/ai-visibility/<site>.env` (`site` from the project's
  `queries.json`), falling back to `~/.config/ai-visibility/keys.env`, or `$AI_VISIBILITY_KEYS`.
  `chmod 600`. Keys: `OPENAI_API_KEY`, `GEMINI_API_KEY`, `PERPLEXITY_API_KEY`. The runner reads
  them and never prints them. **Never ask the developer to paste a key into chat** — have them
  `open -e` the file, or use `read -s`.
- **One key per client per provider** (OpenAI projects, Perplexity API groups, a Google Cloud
  project per client) so each client's spend is separately billable. The report's Usage section
  gives token totals per engine.
- **No auto-recharge anywhere.** OpenAI: auto recharge off plus a project budget. Perplexity:
  auto top-up off. Google Cloud cannot hard-cap; set budget alerts.
- **Browser engines** (Copilot, logged-out ChatGPT) run in the `firefox-solo` profile, which
  persists. It runs headless, so to sign in: kill the solo Firefox, open its profile visibly
  (`firefox --no-remote --profile ~/.firefox-devtools-mcp/solo-*/firefox_devtools_mcp_profile
  <url>`), let the developer sign in, **⌘Q** (closing the window leaves the app running), then
  the next MCP call relaunches it headless with the login. A Microsoft login made through
  "Continue with Google" lands on the sign-in page again; clicking that button re-enters
  silently from the saved Google session.
- Turn off personalization in every account (ChatGPT memory and chat history, Copilot
  Settings → Personalization, Gemini Keep activity, Perplexity memory). A tracking account that
  remembers earlier brand questions biases every answer toward the brand.

## Engines

| Engine | Route | Notes |
|---|---|---|
| OpenAI | API, Responses + `web_search` | Pin a dated snapshot. One web-search answer ran ~20–40k tokens; use a mini model for weekly volume, a flagship monthly. The `*-chat-latest` aliases lag ChatGPT's real default. |
| Gemini | API | A **new free key gets zero Search-grounding quota** (429) — grounding needs billing. Ungrounded is free but the **free tier is 20 requests per day per model** — a full round needs billing; until then run one pass of ≤20 queries. It is the trained-knowledge read. `gemini-flash-latest` 429'd where the pinned model worked; older models 404 "no longer available to new users". Pin, and expect 503 "high demand" (the runner retries). |
| Perplexity | API, `sonar` | Pay-as-you-go from a free account. Pro ($20/mo) is the consumer app, not needed. Logged-out web asks you to sign up. |
| Copilot | Manual, monthly | No consumer API; the Azure "Grounding with Bing" route is a stand-in, not worth the setup. Driven from automation it throws "Verify you are human" on the first question — don't click through a bot check. The developer runs ~10 queries by hand and `ingest`s the answers. It also ignores `?q=`. |
| ChatGPT web | Browser, logged out | `chatgpt.com/?q=` answers with sources; spot-check that the API matches. |
| Google AI Overviews | SerpApi (paid, small free tier) | Direct Google from automation hits the "unusual traffic" captcha. |
| Grok, Claude, Meta AI | Browser, monthly | Low reach for B2B buyers; promote to weekly only if they diverge. |

Enterprise assistants (M365 Copilot, ChatGPT Enterprise, Gemini for Workspace) search the same
web as their consumer versions; what they add is the buyer's own files — which is where a
text-searchable datasheet earns its keep.

## The query set

Per project at `docs/seo/ai-visibility/queries.json`: `site`, `brand` (name, regex patterns,
domains), `competitors`, `engines` (pinned models), `runs`, and three segments scored
separately because different levers move them:

- **technical** — what a qualified buyer types: specs, standards, certifications. Moved mostly
  by the site.
- **generic** — "best X for Y". Moved mostly off-site. Track it; don't chase it with pages.
- **branded** — scored for **accuracy** (`expect` / `reject` regexes), not mention: catches the
  engine confusing the brand with something else, or quoting retired products.

Keep queries fixed between rounds; a changed query is a new series. Brand patterns must exclude
collisions (DMX vs the DMX512 lighting protocol).

## A round

```
python3 vendor/augustash/claude-config/templates/ai-visibility/run.py run    --dir docs/seo/ai-visibility
python3 vendor/augustash/claude-config/templates/ai-visibility/run.py report --dir docs/seo/ai-visibility
```

`--limit 2 --runs 1` for a smoke test. Browser engines: drive the query in firefox-solo, save
the answer text, then `run.py ingest --engine copilot --query-id t01 --run 1 --text-file f
--url <cited> ...` so it is scored by the same function as the API rows.

Every site or off-site change goes in `docs/seo/ai-visibility/changelog.md` with its date.
Effects lag one to four weeks (re-crawl); without the log no movement can be attributed.

## Reading the report

Per segment and engine: **mention rate** (headline), **site cited**, **share of voice** (brand ÷
all brand mentions — guards against everyone rising), **accuracy** (branded), competitors named,
top cited domains. Δ is bolded only past two standard errors; at ~240 answers a segment, under
~6 points is noise. Act on a bolded move or a three-week trend, never one round.

Measure weekly; change at whatever pace the work allows — weekly changes blur attribution.

## Corrections log

- 2026-10-28 (DMX): treated `ocrmypdf --skip-text` exiting clean as "already searchable"; four
  manuals had vector-outline body text and gained 8–13× extractable text under `--redo-ocr`.
