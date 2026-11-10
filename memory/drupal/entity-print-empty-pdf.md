---
name: entity-print-empty-pdf
description: entity_print's savePrintable() writes whatever the engine returns, so a failed render becomes a 0-byte PDF reported as success; and wkhtmltopdf fails this way when a platform upgrade breaks its binary.
metadata:
  type: reference
---

# entity_print saves a failed render as an empty PDF

**Symptom.** A generated PDF link opens blank, or the browser says it failed to load. The file
is on disk at 0 bytes (`curl -sI` shows `content-length: 0`), and the site logged it as created,
probably emailed it too. Nothing in watchdog. Usually it isn't one file: everything generated
in a window is empty.

**Mechanism.** `PrintBuilder::savePrintable()` passes `$engine->getBlob()` straight to
`fileSystem->saveData()` and returns the URI. It never checks what it got. An engine that throws
leaves no file, but one that *returns* a failure writes it: `PhpWkhtmlToPdf::getBlob()` returns
mikehaertl's `Pdf::toString()`, which is `FALSE` when the binary fails, and `FALSE` saves as an
empty file. Callers that test `if ($uri)` or `file_exists()` see success, and an "only generate
if missing" check never regenerates it.

**The wkhtmltopdf trap.** It shells out to an external binary, so a PHP bump, a D11 upgrade or
a platform image change can break it with no code change on our side. On mace (2026-04 to
2026-07) every PDF on live came out empty from the D11/PHP 8.3 deploy until the switch to dompdf
reached live: 20 tenant documents over three months, found when a client reported one link.
dompdf is pure PHP and has no binary to lose. Treat any site still on `pdf_engine: phpwkhtmltopdf`
as at risk on its next PHP or core upgrade, and generate a PDF as part of that upgrade's checks
(as of 2026-10, mhs, on PHP 8.1).

**Find them:** scan the files directory for `*.pdf` with size 0, then bucket by month against
the good ones. A clean switch from all-good to all-empty dates the deploy that broke it.

**Guard it in code:** after `savePrintable()`, treat a missing or empty file as a failure:
delete it, return no URI, log it. mace's `mace_core/src/PdfGeneratorTrait.php` does that, and
retries through a core queue item it writes *before* the attempt, so a fatal mid-render is
still retried. After three attempts it emails changes@augustash.com.

Regenerating a lost file re-renders it as of *now*: check the template for `time()` dates
(mace's letterhead had one) before regenerating historical documents.
