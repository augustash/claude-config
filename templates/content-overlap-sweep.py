#!/usr/bin/env python3
"""Find legacy nodes carrying the same information in different clothes.

Template — copy into a project as `scripts/content-overlap-sweep.py` and fill in
the CONFIG block below (source DB, body fields, node clusters). Companion to the
`content-audit` skill, which explains how to read what this prints.

The content audit decides a disposition per node, which structurally cannot see
the failure mode that costs the most: two nodes saying the same thing. Migrating
those separately replicates the legacy site's disorder forward, splits SEO
authority between competing near-duplicates, and leaves each page implying the
other case doesn't apply.

Verbatim sentence reuse is the tell — a writer who copies three sentences between
two pages was usually writing one page twice. Usually, not always: a sentence
carried by three or more pages is house boilerplate ("refer to your owner's
manual"), so it is discounted from the scores and reported on its own. That list
is the section-level note to write once. `--boilerplate N` tunes the threshold;
on a set that is genuinely one topic in many variants, raise it, since there a
sentence on three pages IS the duplication.

    python3 scripts/content-overlap-sweep.py 1372 1375 1376 139
    python3 scripts/content-overlap-sweep.py --preset troubleshooting
    python3 scripts/content-overlap-sweep.py --preset howto --boilerplate 99

Reads the legacy database directly, trying each configured body field in turn —
a CMS rarely keeps all its prose in one field (D7's `education_article` used
`field_ea_description`, not `body`, which read as "these nodes are empty").

Run this BEFORE building a section, not after. On the reference project the
75% fault-code overlap was caught only because those two tables happened to be
built side by side; one node at a time, it would have shipped as two pages.

Two things it cannot do, both of which cost a wrong call once already:

- **It scores, it does not read.** A high score is a candidate, not a verdict.
  Two pages scored 44% on four boilerplate sentences while the procedures beneath
  them shared nothing; merging on the score would have produced instructions
  matching neither device. The boilerplate discount kills that specific case,
  not the general one.
- **It only sees the legacy CMS.** A node duplicating content that already
  migrated into the new site is invisible here — one scored a clean 20% and
  turned out to be a product overview owned by two live commerce products. Check
  each section's nodes against migrated content by hand.
"""

import argparse
import collections
import html
import itertools
import re
import subprocess
import sys

# --- CONFIG — set these per project ---------------------------------------

# The legacy database, as reachable from wherever this runs.
SOURCE_DB = 'migrate'

# Every table/column that might hold a node's prose, tried in order. Add one per
# body-ish field the legacy site used, or nodes silently read as empty.
# The D7 shape is shown; adjust for D6/D8+/WordPress.
FIELDS = (
    ('body_value', 'field_data_body'),
    # ('field_ea_description_value', 'field_data_field_ea_description'),
)

# Node clusters from the audit doc, so a sweep is one flag. Name them after the
# destination sections you are considering — the point is to test whether a
# proposed section is really one topic.
PRESETS = {
    # 'troubleshooting': [1372, 1375, 1376],
}

# Sentences shorter than this are fragments and list items, not prose worth
# comparing. 45 was tuned on a known-good duplicate pair; lower it if a legacy
# site writes in very short sentences.
MIN_SENTENCE = 45

# --- end CONFIG -------------------------------------------------------------


def fetch(nid: int) -> str:
    """Return a node's raw body, whichever field holds it."""
    for column, table in FIELDS:
        query = (f'SELECT {column} FROM {SOURCE_DB}.{table} '
                 f"WHERE entity_id={nid} AND entity_type='node'")
        try:
            out = subprocess.run(['ddev', 'mysql', '-N', '-e', query],
                                 capture_output=True, text=True, timeout=60)
        except (OSError, subprocess.SubprocessError) as err:
            print(f'  ! nid {nid}: {err}', file=sys.stderr)
            return ''
        if out.stdout.strip():
            return out.stdout
    return ''


def title(nid: int) -> str:
    out = subprocess.run(
        ['ddev', 'mysql', '-N', '-e',
         f'SELECT title FROM {SOURCE_DB}.node WHERE nid={nid}'],
        capture_output=True, text=True, timeout=60)
    return out.stdout.strip() or f'nid {nid}'


def sentences(raw: str) -> set:
    """Tag-stripped, normalised sentences long enough to carry meaning."""
    text = html.unescape(re.sub(r'<[^>]+>', ' ', raw.replace('\\n', ' ').replace('\\t', ' ')))
    text = re.sub(r'\s+', ' ', text)
    return {
        s.strip().lower()
        for s in re.split(r'(?<=[.!?])\s+', text)
        if len(s.strip()) > MIN_SENTENCE
    }


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__,
                                 formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument('nids', nargs='*', type=int)
    ap.add_argument('--preset', choices=sorted(PRESETS))
    ap.add_argument('--examples', type=int, default=3,
                    help='shared sentences to quote per pair (default 3)')
    ap.add_argument('--boilerplate', type=int, default=3, metavar='N',
                    help='a sentence on N+ nodes is boilerplate, not overlap '
                         '(default 3; raise it on a set that is genuinely one '
                         'topic in many variants)')
    args = ap.parse_args()

    nids = args.nids or PRESETS.get(args.preset, [])
    if not nids:
        ap.error('give some nids, or --preset ' + '/'.join(sorted(PRESETS)))

    corpus, labels = {}, {}
    for nid in nids:
        labels[nid] = title(nid)
        corpus[nid] = sentences(fetch(nid))
        print(f'{nid:>5}  {labels[nid][:44]:<46} {len(corpus[nid]):>3} sentences')

    # A sentence on three or more pages is house boilerplate ("refer to your
    # owner's manual"), not evidence that two of them are the same page. Scoring
    # it as overlap is how 1182/1183 read as 44% CONSOLIDATE when the four
    # sentences behind that score were all boilerplate and the two menu paths
    # underneath shared nothing — merging them would have produced instructions
    # matching neither remote. Discount them, and report them separately: the
    # list is itself the section-level note to write once.
    tally = collections.Counter(s for body in corpus.values() for s in body)
    boiler = {s for s, n in tally.items() if n >= args.boilerplate}

    pairs = []
    for a, b in itertools.combinations(nids, 2):
        shared = (corpus[a] & corpus[b]) - boiler
        if shared:
            # Against the SMALLER node: a short page wholly absorbed by a long
            # one is the strongest signal, and dividing by the union would bury
            # it. Boilerplate leaves the denominator too — a page that is mostly
            # house furniture shouldn't get a small denominator as a reward.
            smaller = min(len(corpus[a] - boiler), len(corpus[b] - boiler))
            pct = len(shared) / (smaller or 1)
            pairs.append((pct, len(shared), a, b, shared))
    pairs.sort(reverse=True)

    if boiler:
        print(f'\n--- shared by {args.boilerplate}+ nodes: boilerplate, discounted from the scores below ---')
        print('    Say these once at section level instead of on every page.')
        for s in sorted(boiler, key=lambda s: (-tally[s], s)):
            print(f'  {tally[s]}x · {s[:104]}')

    print('\n--- pairs sharing verbatim SUBSTANCE, most overlapping first ---')
    if not pairs:
        print('none — no two of these say the same thing twice')
        print('(any overlap above was boilerplate; these pages are genuinely separate)')
        return 0
    for pct, count, a, b, shared in pairs:
        flag = '  <-- CONSOLIDATE' if pct >= 0.40 else ''
        print(f'\n{pct:>4.0%}  {count:>2} shared   {a} {labels[a][:28]} <-> {b} {labels[b][:28]}{flag}')
        for s in sorted(shared, key=len, reverse=True)[:args.examples]:
            print(f'        · {s[:110]}')
    print('\n40%+ is usually one topic split by variant (display, remote, model).'
          '\nStill a candidate detector, not a verdict — read the node before acting.')
    return 0


if __name__ == '__main__':
    sys.exit(main())
