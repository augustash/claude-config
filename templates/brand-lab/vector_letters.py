"""Wordmark letters as vector, for a brand lab (skills/brand-lab): ASHEN, RAYNE and AR drawn from installed fonts,
each letter optionally trimmed to the band between baseline and cap height (for faces that throw strokes past them),
with letters redrawn or added to where the owner corrects them (EDITS). Writes a JS file the lab page loads, so the
wordmark renders the same anywhere, font installed or not.

This copy is the Ashen Rayne one (November 2026), kept as a worked example: change FONTS (name, file, trim), the
words in word() calls, EDITS and the output path for a new brand. Needs fontTools and skia-pathops."""
import json, os
import pathops
from fontTools.ttLib import TTFont

FONTS = [   # the wordmark is Michroma (his pick, 2026-11-14); the other candidates are in git-less history only
    ('Michroma', '~/Projects/ar-logo/fonts/Michroma-Regular.ttf', False),
]
TRACK = 0.06   # letter spacing, in ems

# letters redrawn (font units, y up), his corrections:
EDITS = {'Michroma': {
    # E: the top arm ran to 1700, short of the bottom arm's 1728; now both reach 1728 (the middle arm stays shorter)
    'E': [[(192, 0), (192, 1536), (1728, 1536), (1728, 1376), (384, 1376), (384, 864), (1645, 864), (1645, 704), (384, 704),
           (384, 160), (1728, 160), (1728, 0)]],
    # A: the crossbar raised from 352-512 to 704-864, level with the middle bars of the H and E; the legs' inner edges
    # kept on their straight lines (through the feet and the counter's apex)
    'A': [[(64, 0), (960, 1536), (1216, 1536), (2112, 0), (1888, 0), (1888 - 704 * 800 / 1408, 704), (288 + 704 * 800 / 1408, 704), (288, 0)],
          [(288 + 864 * 800 / 1408, 864), (1888 - 864 * 800 / 1408, 864), (1088, 1408)]],
    # A beside R (the monogram): the crossbar at 621-787, level with the R's own middle bar
    'A@R': [[(64, 0), (960, 1536), (1216, 1536), (2112, 0), (1888, 0), (1888 - 621 * 800 / 1408, 621), (288 + 621 * 800 / 1408, 621), (288, 0)],
            [(288 + 787 * 800 / 1408, 787), (1888 - 787 * 800 / 1408, 787), (1088, 1408)]],
}, 'Pirulen': {
    # A: a crossbar added (it had none), at 320-424 like the middle bars of the H and E, between the legs' inner
    # edges (run a little into each leg so it joins them as one shape)
    'A': {'add': [[(148 + 0.6508 * 320 - 8, 320), (880 - 0.6402 * 320 + 8, 320), (880 - 0.6402 * 424 + 8, 424), (148 + 0.6508 * 424 - 8, 424)]]},
    # A beside R (the monogram): the crossbar at 314-418, level with the R's own middle bar
    'A@R': {'add': [[(148 + 0.6508 * 314 - 8, 314), (880 - 0.6402 * 314 + 8, 314), (880 - 0.6402 * 418 + 8, 418), (148 + 0.6508 * 418 - 8, 418)]]},
}}

def drawn(p, contours):
    for c in contours:
        p.moveTo(*c[0])
        for q in c[1:]: p.lineTo(*q)
        p.close()

def emit(p):
    out = []
    for verb, pts in p.segments:
        if verb == 'moveTo': out.append('M%.1f %.1f' % (pts[0][0], -pts[0][1]))
        elif verb == 'lineTo': out.append('L%.1f %.1f' % (pts[0][0], -pts[0][1]))
        elif verb == 'curveTo': out.append('C' + ' '.join('%.1f %.1f' % (x, -y) for x, y in pts))
        elif verb == 'qCurveTo':   # TrueType: a run of handles, with implied points halfway between neighbours
            off, end = pts[:-1], pts[-1]
            for i, c in enumerate(off):
                to = end if i == len(off) - 1 else ((c[0] + off[i + 1][0]) / 2, (c[1] + off[i + 1][1]) / 2)
                out.append('Q%.1f %.1f %.1f %.1f' % (c[0], -c[1], to[0], -to[1]))
        elif verb in ('closePath', 'endPath'): out.append('Z')
    return ''.join(out)

data = {}
for name, path, trim in FONTS:
    f = TTFont(os.path.expanduser(path)); gs = f.getGlyphSet(); cmap = f.getBestCmap(); upm = f['head'].unitsPerEm
    cap = getattr(f['OS/2'], 'sCapHeight', 0) or 700
    band = pathops.Path(); band.moveTo(-100, 0); band.lineTo(3000, 0); band.lineTo(3000, cap); band.lineTo(-100, cap); band.close()
    def glyph(ch):
        g = gs[cmap[ord(ch[0])]]; p = pathops.Path()   # 'A@R' is a variant of A
        ed = EDITS.get(name, {}).get(ch)
        if isinstance(ed, list): drawn(p, ed)
        else: g.draw(p.getPen())
        p = pathops.simplify(p)
        if isinstance(ed, dict) and 'add' in ed:   # parts added to the drawn letter, joined into it
            q = pathops.Path(); drawn(q, ed['add']); p = pathops.op(p, pathops.simplify(q), pathops.PathOp.UNION)
        if trim: p = pathops.op(p, band, pathops.PathOp.INTERSECTION)
        return p, g.width
    def word(w):
        x = 0; d = ''
        for i, ch in enumerate(w):
            p, adv = glyph(ch); d += emit(p.transform(1, 0, 0, 1, x, 0)) if hasattr(p, 'transform') else ''
            x += adv + (TRACK * upm if i < len(w) - 1 else 0)
        return d, x
    A, aw = glyph('A@R' if 'A@R' in EDITS.get(name, {}) else 'A'); R, rw = glyph('R')   # the monogram's A matches its R
    # the ink's left and right edges too, so A and R can be set to touch the monogram's centre line exactly
    # each letter on its own (path, advance, ink left, ink right), so the page can lay words out and measure gaps
    G = {}
    for ch in 'ASHENRY':
        p, adv = glyph(ch); bx = p.bounds
        G[ch] = [emit(p), adv, bx[0], bx[2]]
    data[name] = {'G': G, 'track': TRACK * upm, 'cap': cap, 'upm': upm, 'ASHEN': word('ASHEN'), 'RAYNE': word('RAYNE'), 'SPACE': gs[cmap[32]].width if 32 in cmap else upm * .3,
                  'A': [emit(A), aw, A.bounds[0], A.bounds[2]], 'R': [emit(R), rw, R.bounds[0], R.bounds[2]]}
    print(name, 'cap', cap, 'ASHEN', round(data[name]['ASHEN'][1]), 'RAYNE', round(data[name]['RAYNE'][1]))
open('eagle/wordmarks.js', 'w').write('// wordmark letters as vector, trimmed to cap height and baseline. Built by wordmarks.py\nwindow.WORDMARKS=%s;\n' % json.dumps(data))
