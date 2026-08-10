#!/usr/bin/env bash
#
# Cloudflare WAF custom-rule puller / applier.
#
#   bash cf-rules.sh <site-dir> show          # ordered table of the custom rules
#   bash cf-rules.sh <site-dir> pull          # raw JSON -> <site-dir>/out/
#   bash cf-rules.sh <site-dir> lists         # account IP lists + their items
#   bash cf-rules.sh <site-dir> backup        # timestamped snapshot of the ruleset
#   bash cf-rules.sh <site-dir> apply <file>  # PUT an edited rules array (atomic, reorders)
#   bash cf-rules.sh <site-dir> audit [since] [before]
#                                             # who changed what, when (default: last 7 days)
#
# `audit` answers the question this tool actually gets reached for during an incident:
# not "what are the rules now" but "what changed, and did it change when the breakage
# started". Point it at the hour traffic died. It only sees changes made on YOUR side —
# a Cloudflare-pushed managed-ruleset or bot-scoring change leaves no entry here, so an
# empty result means "nobody here touched it", not "nothing changed".
#
# <site-dir> holds cf.env and receives out/. Prefer a gitignored dir in the site itself
# (.cloudflare/) over a parallel ~/.config tree — see cf.env.example. It must never be
# inside vendor/augustash/claude-config, which ships to every project.
# Requires: curl, jq.

set -euo pipefail

API="https://api.cloudflare.com/client/v4"

die() { printf '%s\n' "$*" >&2; exit 1; }

SITE_DIR="${1:-}"
CMD="${2:-show}"
[ -n "$SITE_DIR" ] || die "usage: bash cf-rules.sh <site-dir> [show|pull|lists|backup|audit|apply <file>]"
[ -d "$SITE_DIR" ] || die "no such dir: $SITE_DIR"
[ -f "$SITE_DIR/cf.env" ] || die "no cf.env in $SITE_DIR (copy cf.env.example there and fill it in)"

command -v jq >/dev/null || die "jq is required"

# shellcheck disable=SC1091
set -a; . "$SITE_DIR/cf.env"; set +a
[ -n "${CF_API_TOKEN:-}" ] || die "CF_API_TOKEN not set in $SITE_DIR/cf.env"
[ -n "${CF_ZONE_ID:-}" ]   || die "CF_ZONE_ID not set in $SITE_DIR/cf.env"

OUT="$SITE_DIR/out"; mkdir -p "$OUT"

cf() { # cf <method> <path> [body]
  local method="$1" path="$2" body="${3:-}"
  if [ -n "$body" ]; then
    curl -sS -X "$method" "$API$path" \
      -H "Authorization: Bearer $CF_API_TOKEN" \
      -H "Content-Type: application/json" \
      --data "$body"
  else
    curl -sS -X "$method" "$API$path" -H "Authorization: Bearer $CF_API_TOKEN"
  fi
}

check() { # check <json> <what>
  echo "$1" | jq -e '.success == true' >/dev/null 2>&1 && return 0
  printf 'API error (%s):\n' "$2" >&2
  echo "$1" | jq -r '.errors[]? | "  [\(.code)] \(.message)"' >&2 2>/dev/null || echo "$1" >&2
  exit 1
}

# Token sanity — catches the single most common setup mistake before anything else.
verify() {
  local r; r="$(cf GET /user/tokens/verify)"
  if ! echo "$r" | jq -e '.success == true' >/dev/null 2>&1; then
    printf 'Token rejected by Cloudflare.\n' >&2
    echo "$r" | jq -r '.errors[]? | "  [\(.code)] \(.message)"' >&2 2>/dev/null || true
    printf '\nCloudflare API tokens are 40 chars [A-Za-z0-9_-]; yours is %s.\n' \
      "${#CF_API_TOKEN}" >&2
    printf 'If that is not 40 you likely copied the token ID rather than the token value.\n' >&2
    exit 1
  fi
}

# The custom-rules ruleset is the entrypoint whose phase is http_request_firewall_custom.
# Its id is stable per zone but must be discovered, not hardcoded.
ruleset_id() {
  local r; r="$(cf GET "/zones/$CF_ZONE_ID/rulesets")"
  check "$r" "list rulesets"
  local id
  id="$(echo "$r" | jq -r '
    .result[] | select(.phase == "http_request_firewall_custom" and .kind == "zone") | .id' | head -1)"
  [ -n "$id" ] && [ "$id" != "null" ] || die "no http_request_firewall_custom ruleset on this zone"
  printf '%s' "$id"
}

fetch_ruleset() { cf GET "/zones/$CF_ZONE_ID/rulesets/$(ruleset_id)"; }

case "$CMD" in
  show)
    verify
    r="$(fetch_ruleset)"; check "$r" "get ruleset"
    echo "$r" | jq -r '
      .result.rules // []
      | to_entries[]
      | "\(.key + 1). [\(if .value.enabled then "on " else "OFF" end)] \(.value.action | ascii_upcase)  \(.value.description // "(no description)")"
        + "\n     expr:   \(.value.expression)"
        + (if (.value.action_parameters.phases // empty) then "\n     skips:  \((.value.action_parameters.phases) | join(", "))" else "" end)
        + (if (.value.action_parameters.ruleset // empty) then "\n     ALSO SKIPS: ruleset=\(.value.action_parameters.ruleset)" else "" end)
        + (if (.value.logging.enabled // true) then "" else "\n     logging: OFF" end)
        + "\n     id:     \(.value.id)\n"'
    ;;

  pull)
    verify
    rid="$(ruleset_id)"
    cf GET "/zones/$CF_ZONE_ID/rulesets"          > "$OUT/rulesets.json"
    cf GET "/zones/$CF_ZONE_ID/rulesets/$rid"     > "$OUT/custom-rules.json"
    jq '.result.rules' "$OUT/custom-rules.json"   > "$OUT/rules.json"
    printf 'wrote %s/{rulesets,custom-rules,rules}.json  (ruleset %s)\n' "$OUT" "$rid"
    printf 'edit rules.json, then: bash cf-rules.sh %s apply %s/rules.json\n' "$SITE_DIR" "$OUT"
    ;;

  lists)
    verify
    [ -n "${CF_ACCOUNT_ID:-}" ] || die "CF_ACCOUNT_ID needed for lists (needs Account Rule Lists permission)"
    r="$(cf GET "/accounts/$CF_ACCOUNT_ID/rules/lists")"; check "$r" "get lists"
    echo "$r" | jq -r '.result[] | "\(.name)  (\(.kind), \(.num_items) items)  id=\(.id)"'
    echo "$r" | jq -r '.result[].id' | while read -r lid; do
      name="$(echo "$r" | jq -r --arg i "$lid" '.result[] | select(.id==$i) | .name')"
      printf '\n--- $%s ---\n' "$name"
      cf GET "/accounts/$CF_ACCOUNT_ID/rules/lists/$lid/items" \
        | jq -r '.result[]? | "  \(.ip // .redirect.source_url // .hostname // .asn)\(if .comment then "   # " + .comment else "" end)"'
    done
    ;;

  audit)
    verify
    [ -n "${CF_ACCOUNT_ID:-}" ] || die "CF_ACCOUNT_ID needed for audit (token also needs Account > Audit Logs > Read)"
    # Default window: the last 7 days. Both bounds accept anything Cloudflare parses as
    # RFC3339 — a bare date (2026-08-04) is treated as midnight UTC.
    SINCE="${3:-$(date -u -v-7d +%Y-%m-%dT%H:%M:%SZ 2>/dev/null || date -u -d '7 days ago' +%Y-%m-%dT%H:%M:%SZ)}"
    BEFORE="${4:-$(date -u +%Y-%m-%dT%H:%M:%SZ)}"
    r="$(cf GET "/accounts/$CF_ACCOUNT_ID/audit_logs?since=$SINCE&before=$BEFORE&per_page=1000&direction=desc")"
    check "$r" "get audit logs"
    n="$(echo "$r" | jq '.result | length')"
    printf 'audit log  %s .. %s   (%s entries)\n\n' "$SINCE" "$BEFORE" "$n"
    if [ "$n" = "0" ]; then
      printf 'No configuration changes recorded in this window.\n'
      printf 'That rules out a change made from your account — NOT a change Cloudflare\n'
      printf 'rolled out themselves (managed rulesets, bot scoring). Check Security Events\n'
      printf 'for what is actually being actioned before concluding nothing changed.\n'
      exit 0
    fi
    echo "$r" | jq -r '
      .result[]
      | "\(.when)  \(.actor.email // .actor.type // "?")"
        + "\n     action:   \(.action.type // "?")\(if .action.result == false then "  (FAILED)" else "" end)"
        + "\n     resource: \(.resource.type // "?")\(if .resource.id then " " + .resource.id else "" end)"
        + (if (.metadata // {}) != {} then "\n     meta:     \(.metadata | tojson)" else "" end)
        + (if .oldValue and .oldValue != "" and .oldValue != null then "\n     from:     \(.oldValue | tostring | .[0:300])" else "" end)
        + (if .newValue and .newValue != "" and .newValue != null then "\n     to:       \(.newValue | tostring | .[0:300])" else "" end)
        + "\n"'
    ;;

  backup)
    verify
    ts="$(date -u +%Y%m%dT%H%M%SZ)"
    fetch_ruleset > "$OUT/ruleset-$ts.json"
    printf 'backed up to %s/ruleset-%s.json\n' "$OUT" "$ts"
    ;;

  apply)
    FILE="${3:-}"
    [ -n "$FILE" ] && [ -f "$FILE" ] || die "usage: bash cf-rules.sh <site-dir> apply <rules.json>"
    jq -e 'type == "array"' "$FILE" >/dev/null 2>&1 \
      || die "$FILE must be a JSON array of rule objects (the .result.rules array)"
    verify
    rid="$(ruleset_id)"

    # Always snapshot before a write — this is the rollback.
    ts="$(date -u +%Y%m%dT%H%M%SZ)"
    fetch_ruleset > "$OUT/ruleset-before-$ts.json"

    printf '\nAbout to REPLACE all custom rules on zone %s.\n' "$CF_ZONE_ID"
    printf 'Rollback snapshot: %s/ruleset-before-%s.json\n\n' "$OUT" "$ts"
    printf 'Current order:\n'
    jq -r '.result.rules[]? | "  \(.action | ascii_upcase)  \(.description // "(none)")"' \
      "$OUT/ruleset-before-$ts.json"
    printf '\nNew order:\n'
    jq -r '.[] | "  \(.action | ascii_upcase)  \(.description // "(none)")"' "$FILE"
    printf '\nType APPLY to continue: '
    read -r confirm
    [ "$confirm" = "APPLY" ] || die "aborted"

    # PUT the whole array: atomic, and array order IS rule order. Safer than
    # per-rule position PATCHes, which can transiently leave a bad ordering live.
    body="$(jq -c '{rules: .}' "$FILE")"
    r="$(cf PUT "/zones/$CF_ZONE_ID/rulesets/$rid" "$body")"
    check "$r" "put ruleset"
    printf 'applied. new order:\n'
    echo "$r" | jq -r '.result.rules[]? | "  \(.action | ascii_upcase)  \(.description // "(none)")"'
    ;;

  *) die "unknown command: $CMD" ;;
esac
