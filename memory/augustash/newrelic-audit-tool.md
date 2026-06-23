---
name: New Relic audit tool
description: NerdGraph NRQL puller (templates/newrelic/) for Pantheon perf/worker-saturation exhibits; FROM Metric retains ~6mo vs Transaction ~2wk, no queue-time metric (use FPM max_children logs); complements raw-log audits
type: reference
---

`templates/newrelic/nr-pull.sh` pulls a worker-saturation / performance exhibit for a Pantheon site over NerdGraph (NRQL via GraphQL POST to `api.newrelic.com/graphql`, header `API-Key: NRAK-…`). Per-site creds (account id, User key, app name) go in an `nr.env` that **must live outside this repo** (e.g. `~/.config/newrelic/<site>/`) — the package ships to every project, so a real key here would propagate. Full reference: `templates/newrelic/queries.md` and `README.md`.

**Pantheon New Relic gotchas (why the queries are shaped as they are):**
- **Raw `Transaction` events retain only ~2 weeks.** The 6-month history lives in **`FROM Metric`** timeslice data (`HttpDispatcher` = web RT/throughput, `Errors/all`, `OtherTransaction/all` = cron). Timeslice supports avg/min/max/count but **not percentile** — use avg + daily-max for the long arc, `Transaction` percentiles only for the recent window.
- **Worker queue time is not captured** (`WebFrontend/QueueTime` empty; Pantheon nginx doesn't emit the request-start header). You cannot measure FPM queue depth in New Relic — the direct worker-saturation signal is the **FPM `max_children` log events**. Worker pileup shows in New Relic indirectly as a blown-out daily **max** response time + error-rate spike (the median stays fine).
- Worker exhaustion is **site-wide** (shared pool) — site-wide `HttpDispatcher` is the right lens; no need to isolate one URL.

**Logs vs New Relic for audits:** raw logs = what happened / who / exact errors / FPM pool health (security scan, max_children, stack traces — New Relic can't replace these). New Relic = how much / how often / trending / which transaction is the cost (multi-month trends, error rate, percentiles, APM traces). Use both; reach for NRQL for the perf/error-trend portion of a log audit that's painful to aggregate from rotated logs. NRQL aggregates stay server-side, which suits the "never exfiltrate log contents" rule.
