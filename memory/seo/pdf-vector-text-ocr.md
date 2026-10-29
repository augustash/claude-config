---
name: pdf-vector-text-ocr
description: A PDF that looks fully readable but extracts only headings; ocrmypdf --skip-text reports success and adds nothing. Use --redo-ocr.
metadata:
  type: reference
---

# A readable PDF that search engines can't read

Vendor manuals (seen on Sensata/Magnum inverter manuals, DMX 2026-10) often have the headings
as real text and the body text **converted to vector outlines**. On screen the page is fully
readable; `pdftotext` returns only the headings. Search engines and AI answer engines read
what `pdftotext` reads, so the specs in the body are invisible to them.

Telling the cases apart:

- `pdftotext -f N -l N file.pdf -` returns a handful of headings on a page dense with text.
- `pdfimages -list` shows no page-sized image, so it isn't a scan. The text is vector paths.
- A low characters-per-page average for the whole file hides this: a 62-page manual averaged
  227 chars/page, and only 12 pages fell under 100. Check a body page, not the average.

The trap: `ocrmypdf --skip-text` skips **any page that already has some text**, so on these
files it exits clean and changes nothing. That reads as "already searchable."

Use `ocrmypdf --redo-ocr --output-type pdf --optimize 1 in.pdf out.pdf`. It keeps the original
page content (vectors and diagrams untouched, no rasterizing) and adds an invisible text layer
only where no text exists. On the DMX set it took manuals from ~14k to ~138k extractable
characters, and files came out smaller. `--force-ocr` also works but rasterizes every page,
degrading diagrams and bloating the file. Use it only for a pure scan.

Expect small gaps where a line is part real text, part outlines: OCR skips regions that
overlap existing text. Spot-check one body page against a render (`pdftoppm -r 60 -png`).

Charts and schematics with only labels legitimately extract little. Leave those alone.
