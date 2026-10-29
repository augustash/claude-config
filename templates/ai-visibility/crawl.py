#!/usr/bin/env python3
"""Has each crawler fetched a changed page since we changed it?

An AI answer can only move once the engine has re-read the page, and that takes days
to weeks. This reads Cloudflare's request analytics for the pages in a watch list and
reports, per page, which answer-engine crawlers fetched it after its change date,
when they last did, and with what status. A weekly report that shows no movement
means "crawled, not chosen" if the crawlers came, and "not seen yet" if they didn't.

    crawl.py --cf .cloudflare --watch docs/seo/ai-visibility/watch.json [--out FILE]

watch.json is a list of {"path": "/as/requested", "since": "YYYY-MM-DD", "note": "..."};
add a row whenever a changelog.md entry touches a page. Paths match exactly, as
requested (percent-encoded the way the crawler sends them).

<cf-dir>/cf.env supplies CF_API_TOKEN and CF_ZONE_ID (templates/cloudflare/cf.env.example);
the token needs Zone > Analytics > Read. Cloudflare keeps ~8 days and serves one day per
query on non-Enterprise plans, so a change older than that shows only recent fetches.
Crawlers are matched by user agent: on non-Enterprise zones Cloudflare does not expose
verified-bot identity, so a scanner using a crawler's name counts too. A 200 on the exact
page is rarely spoofed; treat odd statuses (403 on a normal page) as a probe, not the bot.
"""
import argparse, collections, datetime as dt, json, os, sys, urllib.request
from pathlib import Path

# The crawlers that feed answers, by vendor. Training-only crawlers (GPTBot, CCBot) are
# listed last: they say nothing about live retrieval.
BOTS = [
    ("OpenAI", "OAI-SearchBot", "oai-searchbot"),
    ("OpenAI", "ChatGPT-User", "chatgpt-user"),
    ("Perplexity", "PerplexityBot", "perplexitybot"),
    ("Perplexity", "Perplexity-User", "perplexity-user"),
    ("Anthropic", "Claude-SearchBot", "claude-searchbot"),
    ("Anthropic", "Claude-User", "claude-user"),
    ("Anthropic", "ClaudeBot", "claudebot"),
    ("Google", "Googlebot", "googlebot"),
    ("Microsoft", "Bingbot", "bingbot"),
    ("Apple", "Applebot", "applebot"),
    ("DuckDuckGo", "DuckAssistBot", "duckassistbot"),
    ("Meta", "Meta-ExternalAgent", "meta-externalagent"),
    ("OpenAI", "GPTBot", "gptbot"),
]
# One per engine is enough to say "this engine has seen it".
KEY = {"OpenAI": ("OAI-SearchBot", "ChatGPT-User"), "Perplexity": ("PerplexityBot", "Perplexity-User"),
       "Anthropic": ("Claude-SearchBot", "Claude-User", "ClaudeBot"), "Google": ("Googlebot",),
       "Microsoft": ("Bingbot",)}


def env(cf_dir):
    out = {}
    for line in Path(cf_dir, "cf.env").read_text().splitlines():
        line = line.strip()
        if line and not line.startswith("#") and "=" in line:
            k, v = line.split("=", 1)
            out[k.strip().removeprefix("export ").strip()] = v.strip().strip("'\"")
    for k in ("CF_API_TOKEN", "CF_ZONE_ID"):
        if not out.get(k):
            sys.exit(f"{k} missing from {cf_dir}/cf.env")
    return out


def gql(token, query):
    req = urllib.request.Request("https://api.cloudflare.com/client/v4/graphql",
                                 data=json.dumps({"query": query}).encode(),
                                 headers={"Authorization": "Bearer " + token, "Content-Type": "application/json"})
    res = json.load(urllib.request.urlopen(req, timeout=60))
    if res.get("errors"):
        sys.exit("Cloudflare: " + res["errors"][0]["message"])
    return res["data"]["viewer"]["zones"][0]["httpRequestsAdaptiveGroups"]


def bot_of(ua):
    ua = (ua or "").lower()
    for vendor, name, needle in BOTS:
        if needle in ua:
            return vendor, name
    return None


def main():
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--cf", required=True, help="directory holding cf.env")
    ap.add_argument("--watch", required=True, help="watch.json")
    ap.add_argument("--days", type=int, default=8)
    ap.add_argument("--out", help="also write the report here")
    a = ap.parse_args()
    e = env(a.cf)
    watch = json.load(open(a.watch))
    paths = sorted({w["path"] for w in watch})
    plist = ",".join(json.dumps(p) for p in paths)

    # (path, bot) -> {"last": datetime, "n": count since change, "status": Counter}
    seen = collections.defaultdict(lambda: {"last": None, "n": 0, "status": collections.Counter()})
    since = {w["path"]: dt.datetime.fromisoformat(w["since"]).replace(tzinfo=dt.timezone.utc) for w in watch}
    now = dt.datetime.now(dt.timezone.utc).replace(minute=0, second=0, microsecond=0)
    z = lambda t: t.isoformat().replace("+00:00", "Z")
    for d in range(a.days):
        end = now - dt.timedelta(days=d)
        start = end - dt.timedelta(days=1)
        rows = gql(e["CF_API_TOKEN"], '{viewer{zones(filter:{zoneTag:"%s"}){httpRequestsAdaptiveGroups('
                   'limit:10000,filter:{datetime_geq:"%s",datetime_lt:"%s",clientRequestPath_in:[%s]})'
                   '{count dimensions{clientRequestPath userAgent edgeResponseStatus datetimeHour}}}}}'
                   % (e["CF_ZONE_ID"], z(start), z(end), plist))
        for r in rows:
            dm = r["dimensions"]
            b = bot_of(dm["userAgent"])
            if not b:
                continue
            t = dt.datetime.fromisoformat(dm["datetimeHour"].replace("Z", "+00:00"))
            if t < since[dm["clientRequestPath"]]:
                continue
            s = seen[(dm["clientRequestPath"], b[1])]
            s["n"] += r["count"]
            s["status"][dm["edgeResponseStatus"]] += r["count"]
            s["last"] = max(s["last"] or t, t)

    lines = [f"# Crawl check — {now:%Y-%m-%d}", "",
             f"Fetches since each page's change date, last {a.days} days (Cloudflare analytics, matched by user agent).",
             "Engines: " + ", ".join(KEY) + " — ✓ means at least one of that engine's crawlers fetched it.", "",
             "| Page | Changed | " + " | ".join(KEY) + " | Crawlers (last fetch, status) |",
             "|---|---|" + "---|" * len(KEY) + "---|"]
    for w in watch:
        p = w["path"]
        hits = {name: seen[(p, name)] for _, name, _ in BOTS if (p, name) in seen}
        marks = ["✓" if any(n in hits for n in KEY[v]) else "—" for v in KEY]
        detail = "; ".join(f"{n} {h['last']:%m-%d} {'/'.join(str(s) for s in sorted(h['status']))} ×{h['n']}"
                           for n, h in sorted(hits.items(), key=lambda x: x[1]["last"], reverse=True))
        label = p if not w.get("note") else f"{p} ({w['note']})"
        lines.append(f"| {label} | {w['since']} | " + " | ".join(marks) + f" | {detail or 'none yet'} |")
    total = len(watch)
    lines += ["", "Seen by engine: " + ", ".join(
        f"{v} {sum(any((w['path'], n) in seen for n in KEY[v]) for w in watch)}/{total}" for v in KEY)]
    report = "\n".join(lines) + "\n"
    print(report)
    if a.out:
        Path(a.out).parent.mkdir(parents=True, exist_ok=True)
        Path(a.out).write_text(report)


if __name__ == "__main__":
    main()
