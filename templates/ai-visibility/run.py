#!/usr/bin/env python3
"""AI answer-engine visibility tracker. Stdlib only.

Asks a fixed query set of the answer engines, scores every answer the same way, and
reports per-segment rates against the previous round. See skills/ai-visibility/SKILL.md.

  run.py run    --dir docs/seo/ai-visibility [--engines openai,gemini] [--runs 3] [--limit N]
  run.py ingest --dir ... --engine copilot --query-id t01 --run 1 --text-file answer.txt [--url U ...]
  run.py report --dir ... [--file results/2026-10-28.jsonl] [--against results/2026-10-21.jsonl]

Keys come from $AI_VISIBILITY_KEYS, else ~/.config/ai-visibility/<site>.env (site = "site" in
queries.json), else ~/.config/ai-visibility/keys.env. KEY=value lines. One key per client per
provider, so each client's spend shows separately for billing. Keys live on the developer's
machine, never in a repo, and are never printed.
"""
import argparse
import concurrent.futures as cf
import datetime as dt
import json
import math
import os
import re
import sys
import time
import urllib.error
import urllib.request
from collections import Counter, defaultdict
from pathlib import Path
from urllib.parse import urlparse

KEYS_DIR = Path("~/.config/ai-visibility").expanduser()


def keys_file(site):
    if os.environ.get("AI_VISIBILITY_KEYS"):
        return Path(os.environ["AI_VISIBILITY_KEYS"]).expanduser()
    per_site = KEYS_DIR / f"{site}.env"
    return per_site if site and per_site.exists() else KEYS_DIR / "keys.env"


def load_keys(site):
    keys = {}
    f = keys_file(site)
    if f.exists():
        for line in f.read_text().splitlines():
            line = line.strip()
            if line and not line.startswith("#") and "=" in line:
                k, v = line.split("=", 1)
                keys[k.strip()] = v.strip().strip("'\"")
    # The environment wins, so CI or a one-off run can override the file.
    for k in ("OPENAI_API_KEY", "GEMINI_API_KEY", "PERPLEXITY_API_KEY"):
        if os.environ.get(k):
            keys[k] = os.environ[k]
    return keys


def post(url, body, headers, timeout=300, attempts=4):
    req = urllib.request.Request(url, data=json.dumps(body).encode(), method="POST",
                                 headers={"Content-Type": "application/json", **headers})
    for i in range(attempts):
        try:
            with urllib.request.urlopen(req, timeout=timeout) as r:
                return json.load(r)
        except urllib.error.HTTPError as e:
            try:
                msg = json.load(e).get("error", {})
                msg = msg.get("message", str(msg)) if isinstance(msg, dict) else str(msg)
            except Exception:
                msg = e.reason
            # 503 "high demand" and rate limits are transient; a quota 429 is not, but
            # retrying it costs nothing and the final error still says which it was.
            if e.code in (429, 500, 502, 503) and i < attempts - 1:
                time.sleep(5 * 2 ** i)
                continue
            raise RuntimeError(f"HTTP {e.code}: {str(msg)[:200]}") from None
        except (urllib.error.URLError, TimeoutError) as e:
            if i < attempts - 1:
                time.sleep(5 * 2 ** i)
                continue
            raise RuntimeError(f"network: {e}") from None


# --- Engines. Each returns {text, urls, searches, model, tokens}. ---

def ask_openai(cfg, keys, q):
    # Responses API with the hosted web_search tool: the same retrieval ChatGPT search uses.
    body = {"model": cfg["model"], "input": q,
            "tools": [{"type": "web_search", "user_location": {"type": "approximate", "country": cfg.get("country", "US")}}]}
    d = post("https://api.openai.com/v1/responses", body, {"Authorization": f"Bearer {keys['OPENAI_API_KEY']}"})
    text, urls, searches = "", [], []
    for o in d.get("output", []):
        if o.get("type") == "web_search_call":
            s = (o.get("action") or {}).get("query")
            if s:
                searches.append(s)
        elif o.get("type") == "message":
            for c in o.get("content", []):
                text += c.get("text", "")
                urls += [a["url"] for a in c.get("annotations", []) if a.get("type") == "url_citation"]
    return {"text": text, "urls": urls, "searches": searches, "model": d.get("model"),
            "tokens": (d.get("usage") or {}).get("total_tokens")}


def ask_gemini(cfg, keys, q):
    body = {"contents": [{"parts": [{"text": q}]}]}
    if cfg.get("grounded"):
        # Google Search grounding: needs billing on the key; a free key gets a 429.
        body["tools"] = [{"google_search": {}}]
    d = post(f"https://generativelanguage.googleapis.com/v1beta/models/{cfg['model']}:generateContent",
             body, {"x-goog-api-key": keys["GEMINI_API_KEY"]})
    c = (d.get("candidates") or [{}])[0]
    text = "".join(p.get("text", "") for p in (c.get("content") or {}).get("parts", []) if not p.get("thought"))
    g = c.get("groundingMetadata") or {}
    # Grounding URLs are vertexaisearch redirects; the chunk title carries the real domain.
    urls = [ch["web"].get("title", "") for ch in g.get("groundingChunks", []) if ch.get("web")]
    return {"text": text, "urls": urls, "searches": g.get("webSearchQueries", []),
            "model": d.get("modelVersion"), "tokens": (d.get("usageMetadata") or {}).get("totalTokenCount")}


def ask_perplexity(cfg, keys, q):
    d = post("https://api.perplexity.ai/chat/completions",
             {"model": cfg["model"], "messages": [{"role": "user", "content": q}]},
             {"Authorization": f"Bearer {keys['PERPLEXITY_API_KEY']}"})
    text = d["choices"][0]["message"]["content"]
    urls = d.get("citations") or [r.get("url") for r in d.get("search_results", [])]
    return {"text": text, "urls": [u for u in urls if u], "searches": [], "model": d.get("model"),
            "tokens": (d.get("usage") or {}).get("total_tokens")}


ENGINES = {"openai": (ask_openai, "OPENAI_API_KEY"),
           "gemini": (ask_gemini, "GEMINI_API_KEY"),
           "perplexity": (ask_perplexity, "PERPLEXITY_API_KEY")}


# --- Scoring: one function for API and browser answers alike, so rounds compare. ---

def domain(u):
    u = u.strip()
    host = urlparse(u if "://" in u else "https://" + u).netloc.lower()
    return host[4:] if host.startswith("www.") else host


def first_hit(patterns, text):
    hits = [m.start() for p in patterns for m in [re.search(p, text, re.I)] if m]
    return min(hits) if hits else None


def score(cfg, query, ans):
    text = ans.get("text") or ""
    brand = cfg["brand"]
    order = []  # brands by first appearance; position = how early DMX is recommended
    for name, pats in [(brand["name"], brand["patterns"])] + [(c["name"], c["patterns"]) for c in cfg["competitors"]]:
        at = first_hit(pats, text)
        if at is not None:
            order.append((at, name))
    order = [n for _, n in sorted(order)]
    domains = sorted({domain(u) for u in ans.get("urls", []) if u})
    row = {"brand_mentioned": brand["name"] in order,
           "brand_rank": order.index(brand["name"]) + 1 if brand["name"] in order else None,
           "brands": order,
           "cited_domains": domains,
           "site_cited": any(d == s or d.endswith("." + s) for d in domains for s in brand["domains"])}
    if query.get("expect") or query.get("reject"):
        exp = query.get("expect", [])
        row["accuracy"] = {"expect_hit": [p for p in exp if re.search(p, text, re.I)],
                           "expect_miss": [p for p in exp if not re.search(p, text, re.I)],
                           "reject_hit": [p for p in query.get("reject", []) if re.search(p, text, re.I)]}
        row["accurate"] = not row["accuracy"]["expect_miss"] and not row["accuracy"]["reject_hit"]
    return row


def load_cfg(d):
    cfg = json.loads((d / "queries.json").read_text())
    queries = []
    for seg, items in cfg["segments"].items():
        for q in items:
            queries.append({**q, "segment": seg})
    return cfg, queries


def cmd_run(a):
    d = Path(a.dir)
    cfg, queries = load_cfg(d)
    keys = load_keys(cfg.get("site"))
    engines = a.engines.split(",") if a.engines else [e for e, c in cfg["engines"].items() if c.get("api")]
    usable = []
    for e in engines:
        fn, k = ENGINES.get(e, (None, None))
        if not fn:
            print(f"skip {e}: browser-only engine, record it with `ingest`", file=sys.stderr)
        elif not keys.get(k):
            print(f"skip {e}: no {k} in {keys_file(cfg.get('site'))}", file=sys.stderr)
        else:
            usable.append(e)
    if a.limit:
        queries = queries[:a.limit]
    runs = a.runs or cfg.get("runs", 3)
    jobs = [(e, q, r) for e in usable for q in queries for r in range(1, runs + 1)]
    out = d / "results" / f"{dt.date.today().isoformat()}.jsonl"
    out.parent.mkdir(parents=True, exist_ok=True)
    print(f"{len(jobs)} answers: {len(queries)} queries x {runs} runs x {usable} -> {out}", file=sys.stderr)

    def work(job):
        e, q, r = job
        base = {"date": dt.date.today().isoformat(), "engine": e, "segment": q["segment"],
                "query_id": q["id"], "query": q["q"], "run": r, "source": "api"}
        try:
            ans = ENGINES[e][0](cfg["engines"][e], keys, q["q"])
            return {**base, **ans, **score(cfg, q, ans)}
        except Exception as ex:
            return {**base, "error": str(ex)}

    n_err = 0
    with cf.ThreadPoolExecutor(max_workers=a.workers) as pool, out.open("a") as f:
        for i, row in enumerate(pool.map(work, jobs), 1):
            f.write(json.dumps(row) + "\n")
            f.flush()
            n_err += "error" in row
            mark = "ERR " + row["error"][:60] if "error" in row else ("DMX" if row["brand_mentioned"] else "-")
            print(f"[{i}/{len(jobs)}] {row['engine']:<10} {row['query_id']:<5} r{row['run']} {mark}", file=sys.stderr)
    print(f"done, {n_err} errors", file=sys.stderr)


def cmd_ingest(a):
    """Score an answer read off a browser engine (Copilot, ChatGPT UI) into today's file."""
    d = Path(a.dir)
    cfg, queries = load_cfg(d)
    q = next(q for q in queries if q["id"] == a.query_id)
    ans = {"text": Path(a.text_file).read_text(), "urls": a.url or [], "searches": [], "model": a.model, "tokens": None}
    row = {"date": dt.date.today().isoformat(), "engine": a.engine, "segment": q["segment"], "query_id": q["id"],
           "query": q["q"], "run": a.run, "source": "browser", **ans, **score(cfg, q, ans)}
    out = d / "results" / f"{dt.date.today().isoformat()}.jsonl"
    out.parent.mkdir(parents=True, exist_ok=True)
    with out.open("a") as f:
        f.write(json.dumps(row) + "\n")
    print(f"{a.engine} {q['id']} r{a.run}: {'DMX' if row['brand_mentioned'] else '-'} rank={row['brand_rank']} site_cited={row['site_cited']}")


def rows_of(path):
    return [json.loads(l) for l in Path(path).read_text().splitlines() if l.strip()]


def summarize(rows, brand):
    s = defaultdict(lambda: {"n": 0, "mention": 0, "cited": 0, "brand_m": 0, "all_m": 0, "acc_n": 0, "acc": 0,
                             "domains": Counter(), "competitors": Counter()})
    for r in rows:
        if "error" in r:
            continue
        for key in ((r["segment"], r["engine"]), (r["segment"], "ALL")):
            x = s[key]
            x["n"] += 1
            x["mention"] += r["brand_mentioned"]
            x["cited"] += r["site_cited"]
            x["all_m"] += len(r["brands"])
            x["brand_m"] += r["brand_mentioned"]
            x["domains"].update(r["cited_domains"])
            x["competitors"].update(b for b in r["brands"] if b != brand)
            if "accurate" in r:
                x["acc_n"] += 1
                x["acc"] += r["accurate"]
    return s


def pct(k, n):
    return k / n if n else 0.0


def noise(p1, n1, p2, n2):
    # Two standard errors of the difference: a move smaller than this is run-to-run noise.
    return 2 * math.sqrt(max(p1 * (1 - p1), 0.01) / max(n1, 1) + max(p2 * (1 - p2), 0.01) / max(n2, 1))


def cmd_report(a):
    d = Path(a.dir)
    cfg, _ = load_cfg(d)
    files = sorted((d / "results").glob("*.jsonl"))
    cur = Path(a.file) if a.file else files[-1]
    prev = Path(a.against) if a.against else next((f for f in reversed(files) if f.name < cur.name), None)
    s = summarize(rows_of(cur), cfg["brand"]["name"])
    p = summarize(rows_of(prev), cfg["brand"]["name"]) if prev else {}
    errs = sum("error" in r for r in rows_of(cur))
    tok = Counter()
    for r in rows_of(cur):
        if r.get("tokens"):
            tok[r["engine"]] += r["tokens"]
    lines = [f"# AI visibility — {cur.stem}", "",
             f"Compared against: {prev.stem if prev else 'nothing (baseline)'}. Errors this round: {errs}.", "",
             "Δ is marked **↑/↓** only when it beats two standard errors; anything smaller is run-to-run noise.", ""]
    for seg in cfg["segments"]:
        keys = sorted([k for k in s if k[0] == seg], key=lambda k: (k[1] != "ALL", k[1]))
        if not keys:
            continue
        lines += [f"## {seg}", "", "| Engine | Answers | Mention rate | Δ | Site cited | Share of voice | Accurate |",
                  "|---|---|---|---|---|---|---|"]
        for k in keys:
            x = s[k]
            m = pct(x["mention"], x["n"])
            delta = ""
            if k in p and p[k]["n"]:
                pm = pct(p[k]["mention"], p[k]["n"])
                dlt = m - pm
                sig = abs(dlt) > noise(m, x["n"], pm, p[k]["n"])
                delta = f"{dlt:+.0%}" + (" **↑**" if sig and dlt > 0 else " **↓**" if sig else "")
            acc = f"{pct(x['acc'], x['acc_n']):.0%}" if x["acc_n"] else "—"
            lines.append(f"| {k[1]} | {x['n']} | {m:.0%} | {delta} | {pct(x['cited'], x['n']):.0%} | "
                         f"{pct(x['brand_m'], x['all_m']):.0%} | {acc} |")
        allx = s[(seg, "ALL")]
        lines += ["", "Competitors named: " + ", ".join(f"{b} {c}" for b, c in allx["competitors"].most_common(8)),
                  "", "Top cited domains: " + ", ".join(f"{dm} {c}" for dm, c in allx["domains"].most_common(12)), ""]
    lines += ["## Usage", "", "Tokens by engine (bill from these at each provider's current rate; "
              "OpenAI also charges per web search call): " + (", ".join(f"{e} {n:,}" for e, n in tok.items()) or "none"), ""]
    report = "\n".join(lines)
    (d / "reports").mkdir(exist_ok=True)
    (d / "reports" / f"{cur.stem}.md").write_text(report + "\n")
    print(report)


def main():
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    sub = ap.add_subparsers(dest="cmd", required=True)
    r = sub.add_parser("run")
    r.add_argument("--dir", required=True)
    r.add_argument("--engines")
    r.add_argument("--runs", type=int)
    r.add_argument("--limit", type=int, help="first N queries only, for a smoke test")
    r.add_argument("--workers", type=int, default=6)
    i = sub.add_parser("ingest")
    i.add_argument("--dir", required=True)
    i.add_argument("--engine", required=True)
    i.add_argument("--query-id", required=True)
    i.add_argument("--run", type=int, default=1)
    i.add_argument("--text-file", required=True)
    i.add_argument("--url", action="append")
    i.add_argument("--model")
    p = sub.add_parser("report")
    p.add_argument("--dir", required=True)
    p.add_argument("--file")
    p.add_argument("--against")
    a = ap.parse_args()
    {"run": cmd_run, "ingest": cmd_ingest, "report": cmd_report}[a.cmd](a)


if __name__ == "__main__":
    main()
