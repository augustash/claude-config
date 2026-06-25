#!/usr/bin/env python3
"""Build a self-contained HTML report (inline SVG charts) + CSVs from the
JSON that nr-pull.sh writes. Pure stdlib — no matplotlib/pandas/network.

Usage:   python3 nr-report.py <site-dir>
Reads:   <site-dir>/out/nr-hist-response-time.json | nr-hist-errors.json | nr-hist-cron.json
         <site-dir>/breakpoints.csv   (optional)  -> "date,label" deploy markers + period bounds
         <site-dir>/intro.html        (optional)  -> your narrative, injected above the charts
Writes:  <site-dir>/out/report.html, <site-dir>/out/data-*.csv

The tool handles the mechanical parts (charts, CSVs, per-period median/worst-day
stats). Write the site-specific narrative/analysis yourself in intro.html — that's
not something to auto-generate.
"""
import json, math, sys, datetime, html, csv, statistics
from pathlib import Path

SITE = Path(sys.argv[1] if len(sys.argv) > 1 else ".")
OUT = SITE / "out"
if not OUT.is_dir():
    sys.exit(f"no out/ dir under {SITE} — run nr-pull.sh first")

def load(name):
    f = OUT / name
    if not f.is_file():
        return None
    return json.loads(f.read_text())["data"]["actor"]["account"]["nrql"]["results"]

def series(rows, key):
    if rows is None:
        return None
    out = []
    for r in rows:
        t = r.get("beginTimeSeconds")
        if t is None:
            continue
        out.append((datetime.datetime.fromtimestamp(t, datetime.UTC).date(), (r.get(key) or 0)))
    return out

rt   = load("nr-hist-response-time.json")
errs = load("nr-hist-errors.json")
cron = load("nr-hist-cron.json")
avg_ms  = series(rt, "avg_ms")
max_ms  = series(rt, "max_ms")
err_day = series(errs, "errors")
cron_ms = series(cron, "avg_ms")
if not max_ms and not err_day:
    sys.exit("no hist-response-time or hist-errors data found in out/")

# ---- breakpoints (optional): date,label ----
BREAKS = []
bp = SITE / "breakpoints.csv"
if bp.is_file():
    for row in csv.DictReader(bp.open()):
        try:
            BREAKS.append((datetime.date.fromisoformat(row["date"].strip()), row["label"].strip()))
        except Exception:
            pass
BREAKS.sort()

# ---- CSVs ----
def write_csv(name, header, *cols):
    dates = [d for d, _ in cols[0]]
    lines = [",".join(header)]
    for i, d in enumerate(dates):
        lines.append(",".join([d.isoformat()] + [f"{cols[j][i][1]:.1f}" for j in range(len(cols))]))
    (OUT / name).write_text("\n".join(lines) + "\n")

if max_ms:  write_csv("data-response-time.csv", ["date", "avg_ms", "peak_ms"], avg_ms, max_ms)
if err_day: write_csv("data-errors.csv", ["date", "errors"], err_day)
if cron_ms: write_csv("data-cron.csv", ["date", "avg_ms"], cron_ms)

# ---- per-period stats from breakpoints ----
def periods():
    """Yield (label, lo_date, hi_date_exclusive) spans split by BREAKS."""
    dmin = min(d for d, _ in (max_ms or err_day))
    dmax = max(d for d, _ in (max_ms or err_day))
    bounds = [dmin] + [b[0] for b in BREAKS] + [dmax + datetime.timedelta(days=1)]
    for i in range(len(bounds) - 1):
        lbl = f"before {BREAKS[0][1]}" if i == 0 else f"after {BREAKS[i-1][1]}"
        if not BREAKS:
            lbl = "full range"
        yield lbl, bounds[i], bounds[i + 1]

def win(s, lo, hi):
    return [v for d, v in s if lo <= d < hi]

def fmt_s(ms):
    return f"{ms/1000:.1f} s" if ms is not None else "—"

stats_rows = []
for lbl, lo, hi in periods():
    pk = win(max_ms, lo, hi) if max_ms else []
    av = win(avg_ms, lo, hi) if avg_ms else []
    er = win(err_day, lo, hi) if err_day else []
    stats_rows.append((
        lbl,
        fmt_s(statistics.median(pk)) if pk else "—",
        fmt_s(max(pk)) if pk else "—",
        f"{max(er):,.0f}" if er else "—",
        f"{statistics.median(er):,.0f}" if er else "—",
        f"{statistics.median(av):,.0f} ms" if av else "—",
    ))

# ---- SVG line chart (log y) ----
W, H = 920, 340
ML, MR, MT, MB = 70, 28, 24, 46
PW, PH = W - ML - MR, H - MT - MB
PALETTE = ["#1f6feb", "#d1242f", "#8250df"]

def chart(title, unit, named_series, ymin_floor=1.0):
    named_series = [(n, s) for n, s in named_series if s]
    if not named_series:
        return ""
    d0 = min(d for _, s in named_series for d, _ in s)
    d1 = max(d for _, s in named_series for d, _ in s)
    span = max((d1 - d0).days, 1)
    allv = [v for _, s in named_series for _, v in s if v > 0] or [1]
    lo = math.floor(math.log10(max(min(allv), ymin_floor)))
    hi = math.ceil(math.log10(max(allv)))
    hi = max(hi, lo + 1)
    def x(d): return ML + (d - d0).days / span * PW
    def y(v): return MT + PH - (math.log10(max(v, 10 ** lo)) - lo) / (hi - lo) * PH
    p = [f'<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 {W} {H}" font-family="-apple-system,Segoe UI,Roboto,sans-serif">']
    p.append(f'<text x="{ML}" y="16" font-size="14" font-weight="600">{html.escape(title)}</text>')
    for e in range(lo, hi + 1):
        yy = y(10 ** e); val = 10 ** e
        lbl = f"{val:,.0f}" if val >= 1 else f"{val:g}"
        p.append(f'<line x1="{ML}" y1="{yy:.1f}" x2="{ML+PW}" y2="{yy:.1f}" stroke="#e6e6e6"/>')
        p.append(f'<text x="{ML-8:.0f}" y="{yy+4:.1f}" font-size="11" fill="#666" text-anchor="end">{lbl}</text>')
    p.append(f'<text x="16" y="{MT+PH/2:.0f}" font-size="11" fill="#666" transform="rotate(-90 16 {MT+PH/2:.0f})" text-anchor="middle">{html.escape(unit)} (log)</text>')
    yr, mo = d0.year, d0.month
    while datetime.date(yr, mo, 1) <= d1:
        md = datetime.date(yr, mo, 1)
        if md >= d0:
            xx = x(md)
            p.append(f'<line x1="{xx:.1f}" y1="{MT}" x2="{xx:.1f}" y2="{MT+PH}" stroke="#f1f1f1"/>')
            p.append(f'<text x="{xx:.1f}" y="{MT+PH+16:.0f}" font-size="11" fill="#666" text-anchor="middle">{md.strftime("%b")}</text>')
        mo = mo % 12 + 1
        if mo == 1: yr += 1
    for slot, (bd, blbl) in enumerate(BREAKS):
        if d0 <= bd <= d1:
            xx = x(bd); ly = MT + 12 + slot * 15
            p.append(f'<line x1="{xx:.1f}" y1="{MT}" x2="{xx:.1f}" y2="{MT+PH}" stroke="#2da44e" stroke-width="1.4" stroke-dasharray="4 3"/>')
            p.append(f'<text x="{xx-4:.1f}" y="{ly:.0f}" font-size="10" fill="#1a7f37" text-anchor="end">{html.escape(blbl)} &#8594;</text>')
    for i, (nm, s) in enumerate(named_series):
        col = PALETTE[i % len(PALETTE)]
        pts = " ".join(f"{x(d):.1f},{y(v):.1f}" for d, v in s if v > 0)
        p.append(f'<polyline points="{pts}" fill="none" stroke="{col}" stroke-width="1.6" opacity="0.9"/>')
    for i, (nm, _) in enumerate(named_series):
        col = PALETTE[i % len(PALETTE)]
        lx = ML + 6 + i * 130; ly = MT + 14
        p.append(f'<line x1="{lx}" y1="{ly}" x2="{lx+16}" y2="{ly}" stroke="{col}" stroke-width="2.5"/>')
        p.append(f'<text x="{lx+20}" y="{ly+4}" font-size="11" fill="#333">{html.escape(nm)}</text>')
    p.append("</svg>")
    return "\n".join(p)

figs = []
c = chart("Daily web response time", "ms", [("Peak (max)", max_ms or []), ("Average", avg_ms or [])])
if c: figs.append((c, "Daily <b>peak</b> vs <b>average</b> response time (log). Worker saturation shows in the peak/tail, not the average."))
c = chart("Application errors per day", "errors/day", [("Errors", err_day or [])])
if c: figs.append((c, "Application errors per day (log). Watch for catastrophic spike-days collapsing after a fix."))
c = chart("Background / cron transaction time (daily avg)", "ms", [("Cron avg", cron_ms or [])])
if c: figs.append((c, "Background/cron transaction time. Rising cron can be intentional load shifted off the request path — confirm before reading it as a regression."))

intro_html = ""
intro = SITE / "intro.html"
if intro.is_file():
    intro_html = intro.read_text()

figs_html = "\n".join(
    f'<div class="fig">{svg}<div class="cap">{cap}</div></div>' for svg, cap in figs
)
stats_html = "".join(
    f"<tr><td>{html.escape(r[0])}</td>" + "".join(f'<td class="n">{c}</td>' for c in r[1:]) + "</tr>"
    for r in stats_rows
)

PAGE = f"""<!doctype html><html lang="en"><head><meta charset="utf-8">
<meta name="viewport" content="width=device-width,initial-scale=1">
<title>New Relic report</title>
<style>
 body{{font:15px/1.55 -apple-system,Segoe UI,Roboto,sans-serif;color:#1c2128;max-width:1000px;margin:2rem auto;padding:0 1.2rem}}
 h1{{font-size:1.5rem}} h2{{font-size:1.15rem;margin:1.8rem 0 .6rem;border-bottom:1px solid #eaecef;padding-bottom:.3rem}}
 table{{border-collapse:collapse;width:100%;margin:.6rem 0;font-size:14px}}
 th,td{{border:1px solid #d0d7de;padding:.4rem .6rem;text-align:left}} th{{background:#f6f8fa}}
 td.n,th.n{{text-align:right;font-variant-numeric:tabular-nums}}
 .fig{{margin:1rem 0;padding:.5rem;border:1px solid #eaecef;border-radius:6px;background:#fff}}
 .cap{{color:#57606a;font-size:13px;margin:.2rem}} code{{background:#eff1f3;padding:.1rem .3rem;border-radius:4px}}
 footer{{color:#57606a;font-size:13px;margin-top:2rem;border-top:1px solid #eaecef;padding-top:.8rem}}
</style></head><body>
{intro_html}
<h2>Charts</h2>
{figs_html}
<h2>Per-period summary</h2>
<table>
<tr><th>Period</th><th class="n">Median daily-peak RT</th><th class="n">Worst-day peak RT</th><th class="n">Worst-day errors</th><th class="n">Median errors/day</th><th class="n">Median avg RT</th></tr>
{stats_html}
</table>
<p class="cap">Periods split at the dates in <code>breakpoints.csv</code>. Median (not mean) is used because
saturation metrics are spike-driven — a mean is dragged up by a few spike-days and overstates the typical rate.
Source: New Relic <code>FROM Metric</code> timeslice data (avg/max/count; no percentiles). Raw JSON in <code>out/</code>.</p>
<footer>Generated by templates/newrelic/nr-report.py — charts are inline SVG, no internet required.</footer>
</body></html>"""

(OUT / "report.html").write_text(PAGE)
print(f"wrote {OUT/'report.html'}")
for n in ("data-response-time.csv", "data-errors.csv", "data-cron.csv"):
    if (OUT / n).is_file():
        print(f"wrote {OUT/n}")
