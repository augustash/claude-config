#!/usr/bin/env python3
"""Read a page the way a retrieval engine does: as sections cut at headings.

Companion to the `content-seo-review` skill, which says how to read what this prints.

    review.py extract URL [URL ...]              # outline, metadata, mechanical flags
    review.py blind URL --ai-dir docs/seo/ai-visibility
                                                 # + what each section answers, heading hidden
    review.py extract URL --json > page.json     # machine-readable, for diffing before/after

`extract` is stdlib and free. `blind` sends each section's body (never its heading) to the
OpenAI model pinned in ai-visibility's queries.json, using that skill's per-client key file,
and asks what question the passage answers and what it would title it. Disagreement with the
real heading is the finding. Keys and the HTTP helper are imported from ai-visibility/run.py
so the two skills share one secrets path and one retry policy.

Content is scoped to <main> when the page has one; nav, header, footer, aside, script,
style, form and template are skipped everywhere.
"""
import argparse
import html
import json
import re
import ssl
import sys
import urllib.request
from html.parser import HTMLParser
from pathlib import Path

SKIP = {"nav", "header", "footer", "aside", "script", "style", "noscript", "form", "template", "svg"}
VOID = {"area", "base", "br", "col", "embed", "hr", "img", "input", "link", "meta", "source", "track", "wbr"}
HEADINGS = {f"h{i}" for i in range(1, 7)}
BLOCK = {"p", "li", "td", "th", "dd", "dt", "div", "section", "article", "br", "tr", "figcaption", "blockquote"}

# Headings that name a slot in a template rather than what the section says.
GENERIC = re.compile(r"^((key|main|our|product) )?(overview|introduction|features?|benefits|details|more( info(rmation)?)?|"
                     r"learn more|resources|downloads?|specifications?|specs|about|related|"
                     r"why choose us|our story|welcome|get started|faq|questions)$", re.I)
# A passage that leans on the one before it can't be quoted alone.
BACKREF = re.compile(r"^(this|these|those|that|it|they|its|their|such|as (mentioned|noted|shown|described)|"
                     r"the above|see above|as well|also|additionally|furthermore|however)\b", re.I)
STOP = set("a an and are as at be by for from has have how i in is it its of on or our that the "
           "their this to was we what when where which who why will with you your can do does".split())


class Outline(HTMLParser):
    def __init__(self):
        super().__init__(convert_charrefs=True)
        self.stack, self.skip_depth = [], 0
        self.in_main, self.saw_main = 0, False
        self.meta, self.jsonld, self.title = {}, [], ""
        self.all_sections, self.main_sections = [], []
        self._heading, self._jsonld, self._title = None, None, False
        self._cur = {"all": None, "main": None}
        self.alts = []

    def _open(self, bucket, level, text):
        sec = {"level": level, "heading": text, "text": ""}
        (self.main_sections if bucket == "main" else self.all_sections).append(sec)
        self._cur[bucket] = sec

    def _add(self, s):
        for b in ("all", "main"):
            if b == "main" and not self.in_main:
                continue
            if self._cur[b] is None:
                self._open(b, 0, "")
            self._cur[b]["text"] += s

    def handle_starttag(self, tag, attrs):
        a = dict(attrs)
        if tag == "meta":
            k = (a.get("name") or a.get("property") or "").lower()
            if k:
                self.meta[k] = a.get("content", "")
        elif tag == "link" and "canonical" in (a.get("rel") or ""):
            self.meta["canonical"] = a.get("href", "")
        elif tag == "title":
            self._title = True
        elif tag == "script" and a.get("type") == "application/ld+json":
            self._jsonld = ""
        if tag in VOID:
            if tag == "img" and not self.skip_depth and self.in_main:
                self.alts.append(a.get("alt"))
            if tag == "br":
                self._add("\n")
            return
        # header/footer inside <main> are the page's own (the H1 often lives there), not chrome.
        skipped = tag in SKIP and not (tag in ("header", "footer") and self.in_main)
        self.stack.append((tag, skipped))
        if skipped:
            self.skip_depth += 1
        if tag == "main" or a.get("role") == "main":
            self.in_main += 1
            self.saw_main = True
        if tag in HEADINGS and not self.skip_depth:
            self._heading = (int(tag[1]), "")
        elif tag in BLOCK:
            self._add("\n")

    def handle_endtag(self, tag):
        if tag == "title":
            self._title = False
        if tag == "script" and self._jsonld is not None:
            self.jsonld.append(self._jsonld)
            self._jsonld = None
        if tag not in (t for t, _ in self.stack):
            return
        while self.stack:
            t, skipped = self.stack.pop()
            if skipped:
                self.skip_depth -= 1
            if t == "main":
                self.in_main -= 1
            if t in HEADINGS and self._heading:
                lvl, txt = self._heading
                txt = re.sub(r"\s+", " ", txt).strip()
                self._open("all", lvl, txt)
                if self.in_main:
                    self._open("main", lvl, txt)
                self._heading = None
            if t == tag:
                break
        if tag in BLOCK:
            self._add("\n")

    def handle_data(self, d):
        if self._title:
            self.title += d
        if self._jsonld is not None:
            self._jsonld += d
            return
        if self.skip_depth:
            return
        if self._heading:
            self._heading = (self._heading[0], self._heading[1] + d)
        else:
            self._add(d)


def fetch(url):
    ctx = ssl.create_default_context()
    if ".ddev.site" in url or "localhost" in url:
        ctx.check_hostname, ctx.verify_mode = False, ssl.CERT_NONE
    req = urllib.request.Request(url, headers={"User-Agent": "content-seo-review/1.0"})
    with urllib.request.urlopen(req, timeout=60, context=ctx) as r:
        return r.read().decode("utf-8", "replace")


def words(s):
    return re.findall(r"[a-z0-9][a-z0-9'\-]*", s.lower())


def content_words(s):
    return {w for w in words(s) if w not in STOP and len(w) > 2}


def ld_types(blobs):
    out = []

    def walk(o):
        if isinstance(o, dict):
            t = o.get("@type")
            if t:
                out.extend(t if isinstance(t, list) else [t])
            for v in o.values():
                walk(v)
        elif isinstance(o, list):
            for v in o:
                walk(v)
    for b in blobs:
        try:
            walk(json.loads(b))
        except ValueError:
            out.append("(invalid JSON-LD)")
    return sorted(set(out))


def analyse(url):
    p = Outline()
    p.feed(fetch(url))
    secs = p.main_sections if p.saw_main else p.all_sections
    for s in secs:
        s["text"] = re.sub(r"[ \t]+", " ", re.sub(r"\n\s*\n+", "\n", html.unescape(s["text"]))).strip()
        s["words"] = len(words(s["text"]))
        flags = []
        hw = content_words(s["heading"])
        if s["heading"]:
            if GENERIC.match(s["heading"].strip(" :?")):
                flags.append("generic heading")
            if hw:
                hit = len(hw & content_words(s["text"])) / len(hw)
                s["heading_overlap"] = round(hit, 2)
                if hit == 0 and s["words"] >= 25:
                    flags.append("heading words absent from body")
        if s["words"] < 25 and s["level"]:
            flags.append("thin")
        first = s["text"].split("\n")[0] if s["text"] else ""
        if BACKREF.match(first):
            flags.append(f"opens on a back-reference: \"{first[:60]}\"")
        s["flags"] = flags

    h1 = [s["heading"] for s in secs if s["level"] == 1] or [s["heading"] for s in p.all_sections if s["level"] == 1]
    levels = [s["level"] for s in secs if s["level"]]
    page_flags = []
    if len(h1) != 1:
        page_flags.append(f"{len(h1)} H1s")
    skips = [f"h{a}→h{b}" for a, b in zip(levels, levels[1:]) if b > a + 1]
    if skips:
        page_flags.append("level skips " + ", ".join(sorted(set(skips))))
    title = re.sub(r"\s+", " ", p.title).strip()
    desc = p.meta.get("description", "")
    if not desc:
        page_flags.append("no meta description")
    elif not 70 <= len(desc) <= 170:
        page_flags.append(f"meta description {len(desc)} chars")
    if h1 and title and not (content_words(h1[0]) & content_words(title)):
        page_flags.append("title and H1 share no words")
    if "noindex" in p.meta.get("robots", "").lower():
        page_flags.append("noindex")
    dupes = {s["heading"] for s in secs if s["heading"] and [x["heading"] for x in secs].count(s["heading"]) > 1}
    if dupes:
        page_flags.append("repeated headings: " + "; ".join(sorted(dupes)))
    missing_alt = sum(1 for a in p.alts if a is None)
    if missing_alt:
        page_flags.append(f"{missing_alt} images without alt")
    return {"url": url, "title": title, "description": desc, "canonical": p.meta.get("canonical", ""),
            "og_title": p.meta.get("og:title", ""), "h1": h1, "jsonld_types": ld_types(p.jsonld),
            "scoped_to_main": p.saw_main, "words": sum(s["words"] for s in secs),
            "page_flags": page_flags, "sections": secs}


def blind(page, ai_dir, model=None, limit=None):
    """Ask a model what each section answers without showing it the heading."""
    sys.path.insert(0, str(Path(__file__).resolve().parent.parent / "ai-visibility"))
    import run  # noqa: E402 — ai-visibility's key loader and retrying POST
    cfg = json.loads((Path(ai_dir) / "queries.json").read_text())
    keys = run.load_keys(cfg.get("site"))
    if "OPENAI_API_KEY" not in keys:
        sys.exit(f"No OPENAI_API_KEY in {run.keys_file(cfg.get('site'))}")
    model = model or cfg["engines"]["openai"]["model"]
    brand = cfg.get("brand", {}).get("name", "")
    todo = [s for s in page["sections"] if s["level"] and s["words"] >= 25][:limit]
    instr = ("You are a search engine's retrieval step. You see one passage cut from a web page, "
             "with no surrounding context. Reply with JSON only: {\"question\": the one question a "
             "searcher would ask that this passage answers best, \"heading\": a 3-8 word heading "
             "for it, \"standalone\": true if the passage makes sense quoted alone, else false, "
             "\"missing\": what a reader would need from elsewhere to use it, or \"\"}.")
    for s in todo:
        body = {"model": model, "instructions": instr,
                "input": f"Site: {brand}\nPage title: {page['title']}\n\nPassage:\n{s['text'][:6000]}"}
        d = run.post("https://api.openai.com/v1/responses", body,
                     {"Authorization": f"Bearer {keys['OPENAI_API_KEY']}"})
        text = "".join(c.get("text", "") for o in d.get("output", []) if o.get("type") == "message"
                       for c in o.get("content", []))
        try:
            s["blind"] = json.loads(re.search(r"\{.*\}", text, re.S).group(0))
        except (AttributeError, ValueError):
            s["blind"] = {"raw": text[:300]}
    page["blind_model"] = model
    return page


def report(page):
    out = [f"# {page['url']}", ""]
    out.append(f"- **title:** {page['title']}")
    out.append(f"- **H1:** {' | '.join(page['h1']) or '—'}")
    out.append(f"- **description:** {page['description'] or '—'}")
    out.append(f"- **canonical:** {page['canonical'] or '—'}")
    out.append(f"- **JSON-LD:** {', '.join(page['jsonld_types']) or '—'}")
    out.append(f"- **words:** {page['words']}{'' if page['scoped_to_main'] else ' (no <main>; whole body read)'}")
    if page["page_flags"]:
        out.append(f"- **page flags:** {'; '.join(page['page_flags'])}")
    out.append("")
    for s in page["sections"]:
        if not s["level"] and not s["text"]:
            continue
        ind = "  " * max(s["level"] - 1, 0)
        head = f"h{s['level']} {s['heading']}" if s["level"] else "(before first heading)"
        out.append(f"{ind}- **{head}** — {s['words']}w"
                   + (f", overlap {s['heading_overlap']}" if "heading_overlap" in s else "")
                   + (f" ⚑ {'; '.join(s['flags'])}" if s["flags"] else ""))
        b = s.get("blind")
        if b:
            if "raw" in b:
                out.append(f"{ind}  - blind: (unparsed) {b['raw']}")
            else:
                out.append(f"{ind}  - blind heading: *{b.get('heading', '')}*")
                out.append(f"{ind}  - answers: {b.get('question', '')}")
                if b.get("standalone") is False:
                    out.append(f"{ind}  - not standalone: {b.get('missing', '')}")
    return "\n".join(out)


def main():
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    sub = ap.add_subparsers(dest="cmd", required=True)
    for name in ("extract", "blind"):
        s = sub.add_parser(name)
        s.add_argument("urls", nargs="+")
        s.add_argument("--json", action="store_true")
        if name == "blind":
            s.add_argument("--ai-dir", default="docs/seo/ai-visibility")
            s.add_argument("--model")
            s.add_argument("--limit", type=int)
    a = ap.parse_args()
    pages = []
    for u in a.urls:
        pg = analyse(u)
        if a.cmd == "blind":
            pg = blind(pg, a.ai_dir, a.model, a.limit)
        pages.append(pg)
    if a.json:
        print(json.dumps(pages if len(pages) > 1 else pages[0], indent=2))
    else:
        print("\n\n".join(report(p) for p in pages))


if __name__ == "__main__":
    main()
