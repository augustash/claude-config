"""Isolate a mark (a numeral, a monogram) from a client's logo raster, for potrace.

Usage: python trace-logo-mark.py logo.png out x0,y0,x1,y1 inks [kernel] [keep]
  box     the crop around the mark, in source pixels; end it at the mark, since anything
          in the same inks that touches the mark inside the box joins it
  inks    the mark's colours, comma-separated hex ("ed174b,231f20" for a red numeral with a
          black outline); pixels near any of them count as the mark, everything else doesn't
  kernel  opening size at 8x (default 61): drops thin strokes (ticks, needles, text)
          and keeps heavy shapes; lower it if the mark itself starts to erode
  keep    how many of the largest shapes to keep (default 2, e.g. a "4" and a "9")
Writes out.png (preview) and out.pbm, then:
  potrace -s --flat --tight -t 60 -a 1.0 -O 0.6 -o out.svg out.pbm
Needs Pillow; run it from a scratch venv.
"""
import sys
from PIL import Image, ImageFilter

src, out, box = sys.argv[1], sys.argv[2], tuple(int(v) for v in sys.argv[3].split(','))
inks = [tuple(int(c[i:i + 2], 16) for i in (0, 2, 4)) for c in sys.argv[4].lstrip('#').split(',')]
k = int(sys.argv[5]) if len(sys.argv) > 5 else 61
keep = int(sys.argv[6]) if len(sys.argv) > 6 else 2
S = 8
im = Image.open(src).convert('RGB').crop(box)
im = im.resize((im.width * S, im.height * S), Image.LANCZOS)
px = im.load()
m = Image.new('L', im.size, 0)
mp = m.load()
for y in range(im.height):
    for x in range(im.width):
        r, g, b = px[x, y]
        if any((r - ir) ** 2 + (g - ig) ** 2 + (b - ib) ** 2 < 95 ** 2 for ir, ig, ib in inks):
            mp[x, y] = 255
m = m.filter(ImageFilter.MinFilter(k)).filter(ImageFilter.MaxFilter(k))


def components(img):
    w, h = img.size
    p = img.load()
    seen = bytearray(w * h)
    found = []
    for y0 in range(h):
        for x0 in range(w):
            if p[x0, y0] > 127 and not seen[y0 * w + x0]:
                stack, pts = [(x0, y0)], []
                seen[y0 * w + x0] = 1
                while stack:
                    x, y = stack.pop()
                    pts.append((x, y))
                    for nx, ny in ((x + 1, y), (x - 1, y), (x, y + 1), (x, y - 1)):
                        if 0 <= nx < w and 0 <= ny < h and not seen[ny * w + nx] and p[nx, ny] > 127:
                            seen[ny * w + nx] = 1
                            stack.append((nx, ny))
                found.append(pts)
    return found


clean = Image.new('L', m.size, 0)
cp = clean.load()
for c in sorted(components(m), key=len, reverse=True)[:keep]:
    for x, y in c:
        cp[x, y] = 255
clean.save(out + '.png')
Image.eval(clean, lambda v: 0 if v > 127 else 255).convert('1').save(out + '.pbm')
