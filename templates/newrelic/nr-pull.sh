#!/usr/bin/env bash
# Pull a New Relic worker-saturation / performance exhibit for a Pantheon site.
#
# Usage:   bash nr-pull.sh <site-dir>
# Example: bash nr-pull.sh ~/.config/newrelic/mspairport
#
# <site-dir> must contain an nr.env (kept OUTSIDE this repo — see README.md) with:
#   NR_ACCOUNT_ID=1234567
#   NR_API_KEY=NRAK-xxxxxxxx
#   NR_APP=mspairport (live)
#   NR_ENDPOINT=https://api.newrelic.com/graphql   # optional; EU: https://api.eu.newrelic.com/graphql
#
# Results are written as JSON to <site-dir>/out/.
# Requires: curl, jq.
set -euo pipefail

SITE_DIR="${1:?usage: nr-pull.sh <site-dir>}"
SITE_DIR="${SITE_DIR%/}"
[ -f "$SITE_DIR/nr.env" ] || { echo "missing $SITE_DIR/nr.env" >&2; exit 1; }
source "$SITE_DIR/nr.env"
: "${NR_ACCOUNT_ID:?}" "${NR_API_KEY:?}" "${NR_APP:?}"
ENDPOINT="${NR_ENDPOINT:-https://api.newrelic.com/graphql}"
OUT="$SITE_DIR/out"; mkdir -p "$OUT"
APP="$NR_APP"

GQL='query($acct: Int!, $q: Nrql!) { actor { account(id: $acct) { nrql(query: $q) { results metadata { timeWindow { begin end } } } } } }'
nr_run() {
  local name="$1" nrql="$2"
  jq -n --arg query "$GQL" --arg q "$nrql" --argjson acct "$NR_ACCOUNT_ID" '{query:$query,variables:{acct:$acct,q:$q}}' \
  | curl -s -X POST "$ENDPOINT" -H "Content-Type: application/json" -H "API-Key: $NR_API_KEY" -d @- \
  | jq '.' > "$OUT/$name.json"
  if jq -e '.errors' "$OUT/$name.json" >/dev/null 2>&1; then
    echo "$name: ERROR $(jq -c '.errors[0].message' "$OUT/$name.json")"
  else
    echo "$name: ok ($(jq '.data.actor.account.nrql.results|length' "$OUT/$name.json") rows)"
  fi
}

echo "== $APP -> $OUT =="

# --- Long arc: FROM Metric (timeslice), 180 days daily. Retained ~6mo; avg/max/count only (no percentile). ---
nr_run hist-response-time "SELECT average(newrelic.timeslice.value)*1000 AS avg_ms, max(newrelic.timeslice.value)*1000 AS max_ms, count(newrelic.timeslice.value) AS throughput FROM Metric WHERE appName='$APP' AND metricTimesliceName='HttpDispatcher' SINCE 180 days ago TIMESERIES 1 day"
nr_run hist-errors        "SELECT count(newrelic.timeslice.value) AS errors FROM Metric WHERE appName='$APP' AND metricTimesliceName='Errors/all' SINCE 180 days ago TIMESERIES 1 day"
nr_run hist-cron          "SELECT average(newrelic.timeslice.value)*1000 AS avg_ms, max(newrelic.timeslice.value)*1000 AS max_ms FROM Metric WHERE appName='$APP' AND metricTimesliceName='OtherTransaction/all' SINCE 180 days ago TIMESERIES 1 day"

# --- Recent high-res: FROM Transaction (raw events, ~2wk retention). Supports percentile. ---
nr_run flights-rt  "SELECT count(*), percentile(duration,50,95,99), max(duration) FROM Transaction WHERE appName='$APP' AND (request.uri LIKE '%/flights%' OR name LIKE '%flights%') SINCE 14 days ago TIMESERIES 1 day"
nr_run error-rate  "SELECT percentage(count(*), WHERE error IS true), count(*) FROM Transaction WHERE appName='$APP' SINCE 14 days ago TIMESERIES 1 day"
nr_run throughput  "SELECT rate(count(*),1 minute), average(duration) FROM Transaction WHERE appName='$APP' SINCE 14 days ago TIMESERIES 6 hours"

# --- Diagnostics: how far back each store actually retains, and whether queue-time exists ---
nr_run probe-retention "SELECT count(*) FROM Transaction WHERE appName='$APP' SINCE 180 days ago TIMESERIES 1 week"
nr_run probe-queuetime "SELECT count(newrelic.timeslice.value) FROM Metric WHERE appName='$APP' AND metricTimesliceName='WebFrontend/QueueTime' SINCE 7 days ago"

echo "Done -> $OUT/"
