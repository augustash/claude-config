# New Relic NRQL reference — Pantheon worker-saturation / performance exhibit

Run via `nr-pull.sh`, or paste into the New Relic Query Builder. NerdGraph wraps NRQL as:

```graphql
{ actor { account(id: <ACCOUNT_ID>) { nrql(query: "<NRQL>") { results } } } }
```
POST to `https://api.newrelic.com/graphql` (EU: `api.eu.newrelic.com`) with header `API-Key: NRAK-…`.

Replace `<APP>` with the APM app name, e.g. `mspairport (live)`.

## Pantheon gotchas (why the queries are split)
- **Raw `Transaction` events retain ~2 weeks.** For longer history use **`FROM Metric`** timeslice data (retained ~6 months).
- **Timeslice metrics support avg/min/max/count but NOT percentile.** Use avg + daily-max for the long arc; reserve `percentile()` for the recent `Transaction` window.
- **Worker queue time is not captured** — `WebFrontend/QueueTime` is empty (Pantheon nginx doesn't emit the request-start header). The direct FPM-saturation signal is the `max_children` log events, not New Relic. (Probe it; see below.)
- Worker exhaustion is **site-wide** (shared pool), so site-wide `HttpDispatcher` is the right lens — no need to isolate one URL.

---

## Long arc — FROM Metric, 180 days
Response time (ms) + throughput, daily. The pileup shows in the **daily max**, not the average.
```sql
SELECT average(newrelic.timeslice.value)*1000 AS avg_ms,
       max(newrelic.timeslice.value)*1000 AS max_ms,
       count(newrelic.timeslice.value) AS throughput
FROM Metric WHERE appName='<APP>' AND metricTimesliceName='HttpDispatcher'
SINCE 180 days ago TIMESERIES 1 day
```
Errors per day:
```sql
SELECT count(newrelic.timeslice.value) AS errors
FROM Metric WHERE appName='<APP>' AND metricTimesliceName='Errors/all'
SINCE 180 days ago TIMESERIES 1 day
```
Cron / background transaction time (ms) per day:
```sql
SELECT average(newrelic.timeslice.value)*1000 AS avg_ms, max(newrelic.timeslice.value)*1000 AS max_ms
FROM Metric WHERE appName='<APP>' AND metricTimesliceName='OtherTransaction/all'
SINCE 180 days ago TIMESERIES 1 day
```

## Recent high-res — FROM Transaction, ~2 weeks (percentiles available)
```sql
SELECT count(*), percentile(duration,50,95,99), max(duration)
FROM Transaction WHERE appName='<APP>'
SINCE 14 days ago TIMESERIES 1 day
```
Error rate:
```sql
SELECT percentage(count(*), WHERE error IS true), count(*)
FROM Transaction WHERE appName='<APP>' SINCE 14 days ago TIMESERIES 1 day
```

## Diagnostics — run these first against a new site
How far back `Transaction` events actually retain (look for the first non-zero week):
```sql
SELECT count(*) FROM Transaction WHERE appName='<APP>' SINCE 180 days ago TIMESERIES 1 week
```
Whether queue-time exists at all (0 ⇒ rely on FPM logs for saturation):
```sql
SELECT count(newrelic.timeslice.value) FROM Metric
WHERE appName='<APP>' AND metricTimesliceName='WebFrontend/QueueTime' SINCE 7 days ago
```
List available timeslice metric names (find the right ones for a given app):
```sql
SELECT uniques(metricTimesliceName, 200) FROM Metric WHERE appName='<APP>' SINCE 1 day ago
```
