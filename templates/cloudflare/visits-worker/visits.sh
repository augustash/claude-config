#!/usr/bin/env bash
#
# Visits Worker: deploy it and read what it counted.
#
#   bash visits.sh <site-dir> deploy               # wrangler deploy <site-dir>/visits-worker/wrangler.jsonc
#   bash visits.sh <site-dir> secret               # set VISITOR_SECRET (random, once per site)
#   bash visits.sh <site-dir> exclude-assets <host> # script-less routes for Drupal asset paths
#   bash visits.sh <site-dir> ai [days]            # visits sent by AI answers, per engine and landing page
#   bash visits.sh <site-dir> sources [days]       # where browser visits came from (referrer / utm)
#   bash visits.sh <site-dir> fetchers [days]      # named bots and AI fetchers, by requests
#   bash visits.sh <site-dir> recent [n]           # last n data points, raw (checking a deploy)
#   bash visits.sh <site-dir> sql '<query>'        # anything else
#
# <site-dir> holds cf.env (CF_API_TOKEN, CF_ZONE_ID, CF_ACCOUNT_ID) and visits-worker/wrangler.jsonc.
# The token needs Zone › Workers Routes Edit, Account › Workers Scripts Edit and
# Account › Account Analytics Read. Analytics Engine keeps three months.
#
# Counts are page views weighted by _sample_interval (Analytics Engine samples at high
# volume); `visitors` is distinct daily visitor hashes, so a person returning on two days
# counts twice. An engine that tags no links and sends no referrer stays invisible: the
# AI figure is a floor.
# Requires: curl, jq, npx (for deploy/secret).

set -euo pipefail
API="https://api.cloudflare.com/client/v4"
die() { printf '%s\n' "$*" >&2; exit 1; }

SITE_DIR="${1:-}"; CMD="${2:-}"
[ -n "$SITE_DIR" ] && [ -n "$CMD" ] || die "usage: bash visits.sh <site-dir> <deploy|secret|exclude-assets|ai|sources|fetchers|recent|sql>"
[ -f "$SITE_DIR/cf.env" ] || die "no cf.env in $SITE_DIR"
# shellcheck disable=SC1091
set -a; . "$SITE_DIR/cf.env"; set +a
[ -n "${CF_ACCOUNT_ID:-}" ] || CF_ACCOUNT_ID=$(curl -s -H "Authorization: Bearer $CF_API_TOKEN" "$API/zones/$CF_ZONE_ID" | jq -r '.result.account.id')
CONFIG="$SITE_DIR/visits-worker/wrangler.jsonc"
# The dataset name, read from the site's wrangler config.
DATASET=$( [ -f "$CONFIG" ] && sed -n 's/.*"dataset": *"\([^"]*\)".*/\1/p' "$CONFIG" | head -1 )

wrangler() { CLOUDFLARE_API_TOKEN="$CF_API_TOKEN" CLOUDFLARE_ACCOUNT_ID="$CF_ACCOUNT_ID" npx --yes wrangler@4 "$@"; }

sql() {
  curl -s -H "Authorization: Bearer $CF_API_TOKEN" "$API/accounts/$CF_ACCOUNT_ID/analytics_engine/sql" --data "$1"
}
# Print a FORMAT JSON result as a table; empty cells become '-' so column(1) keeps them.
table() { jq -r 'if .data then (.meta | map(.name) | @tsv), (.data[] | [.[] | if . == "" then "-" else . end] | @tsv) else . end' | column -t -s $'\t'; }

# An arrival from an answer engine: a browser, tagged by the engine's utm_source or
# arriving with its referrer.
# Nested if(): Analytics Engine's SQL has neither multiIf nor CASE.
AI_SOURCE="if(blob4 IN ('chatgpt.com','openai','chatgpt') OR blob3 IN ('chatgpt.com','chat.openai.com'), 'ChatGPT',
  if(blob4 IN ('perplexity','perplexity.ai') OR blob3 IN ('www.perplexity.ai','perplexity.ai'), 'Perplexity',
  if(blob4 IN ('copilot','copilot.microsoft.com') OR blob3 IN ('copilot.microsoft.com'), 'Copilot',
  if(blob4 IN ('gemini','gemini.google.com') OR blob3 IN ('gemini.google.com'), 'Gemini',
  if(blob4 IN ('claude','claude.ai') OR blob3 IN ('claude.ai'), 'Claude', '')))))"

days() { echo "timestamp > NOW() - INTERVAL '${1:-30}' DAY"; }

case "$CMD" in
  deploy)
    [ -f "$CONFIG" ] || die "no $CONFIG (copy wrangler.example.jsonc there)"
    wrangler deploy --config "$CONFIG" ;;
  secret)
    [ -f "$CONFIG" ] || die "no $CONFIG"
    openssl rand -hex 32 | wrangler secret put VISITOR_SECRET --config "$CONFIG" ;;
  exclude-assets)
    HOST="${3:-}"; [ -n "$HOST" ] || die "usage: exclude-assets <host>"
    for p in sites core modules themes libraries; do
      curl -s -X POST -H "Authorization: Bearer $CF_API_TOKEN" -H 'Content-Type: application/json' \
        "$API/zones/$CF_ZONE_ID/workers/routes" --data "{\"pattern\":\"$HOST/$p/*\"}" \
        | jq -c --arg p "$HOST/$p/*" '{pattern:$p,success,errors}'
    done ;;
  ai)
    sql "SELECT $AI_SOURCE AS engine, blob2 AS landing, SUM(_sample_interval) AS views, COUNT(DISTINCT blob13) AS visitors
         FROM $DATASET WHERE $(days "${3:-}") AND blob8 = 'browser' AND engine != ''
         GROUP BY engine, landing ORDER BY visitors DESC LIMIT 100 FORMAT JSON" | table ;;
  sources)
    sql "SELECT blob3 AS referrer, blob4 AS utm_source, SUM(_sample_interval) AS views, COUNT(DISTINCT blob13) AS visitors
         FROM $DATASET WHERE $(days "${3:-}") AND blob8 = 'browser'
         GROUP BY referrer, utm_source ORDER BY visitors DESC LIMIT 50 FORMAT JSON" | table ;;
  fetchers)
    sql "SELECT blob8 AS class, blob9 AS agent, SUM(_sample_interval) AS requests
         FROM $DATASET WHERE $(days "${3:-}") AND blob8 != 'browser'
         GROUP BY class, agent ORDER BY requests DESC LIMIT 50 FORMAT JSON" | table ;;
  recent)
    sql "SELECT timestamp, blob2 AS path, blob8 AS class, blob9 AS agent, blob10 AS cache, double1 AS status, blob4 AS utm
         FROM $DATASET ORDER BY timestamp DESC LIMIT ${3:-20} FORMAT JSON" | table ;;
  sql)
    sql "${3:?query}" ;;
  *) die "unknown command: $CMD" ;;
esac
