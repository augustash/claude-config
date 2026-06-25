# New Relic audit puller

Pull worker-saturation / performance data for a Pantheon site straight from New Relic
(NerdGraph + NRQL) into JSON — for performance investigations, log-audit perf trends, and
exhibits (e.g. proving a worker-exhaustion issue is fixed so a plan can be downsized).

## ⚠️ Credentials live OUTSIDE this repo

This directory ships inside `vendor/augustash/claude-config` and lands in **every** project.
Never put a real `nr.env` (account id / `NRAK-` key / app name) here. Per-site config and
pulled data belong in a site dir somewhere else — e.g. `~/.config/newrelic/<site>/`, or a
gitignored dir in the consuming project. The script takes that dir as an argument, so it can
live anywhere. The local `.gitignore` ignores `nr.env`/`out/`/`*.json` as a backstop only.

## Usage

```bash
# one-time per site (outside this repo):
mkdir -p ~/.config/newrelic/mspairport
cp nr.env.example ~/.config/newrelic/mspairport/nr.env
$EDITOR ~/.config/newrelic/mspairport/nr.env      # fill in account id, NRAK- key, app name

# pull data:
bash nr-pull.sh ~/.config/newrelic/mspairport     # writes JSON to .../mspairport/out/

# build a self-contained HTML report + CSVs from that data:
python3 nr-report.py ~/.config/newrelic/mspairport  # writes out/report.html + out/data-*.csv
```

`nr.env` fields and the full NRQL set are documented in `nr.env.example` and `queries.md`.
`nr-pull.sh` requires `curl` + `jq`; `nr-report.py` requires only Python 3 stdlib (no internet).

## Building a report (`nr-report.py`)

Turns the pulled JSON into a browser-openable `out/report.html` with **inline SVG charts**
(no CDN/internet), CSVs of the daily series, and an auto-computed per-period **median /
worst-day** stats table. Two optional per-site files shape it:

- **`breakpoints.csv`** — `date,label` rows marking deploys/fixes. They draw green markers on
  every chart and split the stats table into periods. See `breakpoints.csv.example`.
- **`intro.html`** — your narrative/analysis, injected above the charts. The tool deliberately
  does **not** auto-write prose — charts and stats are mechanical, the story is yours.

Use **median, not mean**, in any narrative: saturation metrics are spike-driven, so a mean is
dragged up by a few spike-days and overstates the typical rate.

## Logs vs New Relic — which to reach for

They're complementary; pick by the question:

- **Raw server logs** → *what happened / who / exact errors / FPM pool health.* Security
  scanning (per-request IPs and paths), `max_children` saturation, stack traces. New Relic
  cannot replace these — it samples transactions and keeps no per-request access log.
- **New Relic** → *how much / how often / trending which way / which transaction is the
  cost.* Multi-month trends, error rate, percentiles, and APM traces that decompose a slow
  request into DB vs PHP vs external. Far easier than aggregating rotated logs by hand.

For a log audit, keep the logs-first sweep as the spine and add an NRQL pass for the
perf/error-trend portion. Bonus: NRQL aggregates stay server-side, so you pull back
summarized numbers rather than exfiltrating raw log bodies.

## Pantheon-specific gotchas

- Raw `Transaction` events retain **~2 weeks**; the **6-month** history is in `FROM Metric`
  timeslice data (avg/max/count only — no percentile).
- **No worker queue-time** in New Relic (`WebFrontend/QueueTime` empty) — Pantheon nginx
  doesn't emit the request-start header. The direct FPM-saturation signal stays in the logs.
- The script's `probe-*` queries report retention and queue-time availability for a new site.
