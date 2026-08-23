/**
 * Real screen-reader capture — VoiceOver on macOS, NVDA on Windows.
 *
 * Drives the ACTUAL assistive technology via Guidepup and records what it
 * spoke, so a report can say "tested with VoiceOver" and show the transcript
 * rather than describing the accessibility tree and hoping that stands in.
 *
 *   node screenreader.mjs flows.json
 *
 * flows.json:
 *   { "base": "https://example.com",
 *     "out": "./results",
 *     "flows": [
 *       { "id": "pdp-size", "url": "/product-x",
 *         "note": "the fields the complaint names",
 *         "steps": 40,
 *         "stopAt": "Add to Cart" }
 *     ] }
 *
 * PREREQUISITES — a human must do these once; they are system security
 * settings and are not ours to change silently:
 *   1. npx @guidepup/setup
 *   2. Approve Accessibility permission for the terminal in
 *      System Settings -> Privacy & Security -> Accessibility
 *
 * The screen reader TAKES OVER the machine while this runs: it speaks aloud
 * and captures the keyboard. Do not type during a run. If VoiceOver wedges,
 * Cmd+F5 twice usually clears it.
 */
import { voiceOver, nvda } from '@guidepup/guidepup';
import fs from 'node:fs';
import path from 'node:path';

const cfg = JSON.parse(fs.readFileSync(process.argv[2] || 'flows.json', 'utf8'));
const OUT = cfg.out || './results';
fs.mkdirSync(OUT, { recursive: true });

const isMac = process.platform === 'darwin';
const sr = isMac ? voiceOver : nvda;
const srName = isMac ? 'VoiceOver (macOS)' : 'NVDA (Windows)';

if (!isMac && process.platform !== 'win32') {
  console.error('Real screen-reader capture needs macOS (VoiceOver) or Windows (NVDA).');
  process.exit(1);
}

const runs = [];

try {
  await sr.start();
  console.log(`${srName} started.\n`);

  for (const flow of cfg.flows) {
    const url = cfg.base + flow.url;
    console.log(`--- ${flow.id}: ${url}`);
    const rec = { id: flow.id, url, note: flow.note || null, screenReader: srName, spoken: [] };

    try {
      // Drive the browser through the screen reader's own host app so what we
      // capture is genuinely what a user would hear, not a synthetic read.
      await sr.navigateToWebContent?.().catch(() => {});
      await openUrl(url);
      await sleep(6000); // let the page and the SR's virtual buffer settle

      const steps = flow.steps || 40;
      for (let i = 0; i < steps; i++) {
        await sr.next();
        const phrase = await sr.lastSpokenPhrase();
        const clean = (phrase || '').replace(/\s+/g, ' ').trim();
        if (clean) rec.spoken.push({ step: i + 1, said: clean });
        if (flow.stopAt && clean.toLowerCase().includes(String(flow.stopAt).toLowerCase())) {
          rec.stoppedAt = clean;
          break;
        }
      }

      // The itemText/log gives the full session in one go where supported.
      try { rec.fullLog = (await sr.spokenPhraseLog()).slice(-200); } catch (e) { /* optional */ }
    } catch (e) {
      rec.error = String(e).slice(0, 300);
    }

    runs.push(rec);
    console.log(`    captured ${rec.spoken.length} phrases${rec.error ? ' (with error)' : ''}`);
  }
} finally {
  try { await sr.stop(); } catch (e) { /* ignore */ }
}

const out = {
  generatedAt: new Date().toISOString(),
  screenReader: srName,
  platform: process.platform,
  base: cfg.base,
  runs,
};
const file = path.join(OUT, 'screenreader.json');
fs.writeFileSync(file, JSON.stringify(out, null, 2));

// A plain-text transcript is what actually goes in front of a reader.
const txt = runs.map((r) =>
  `=== ${r.id} — ${r.url}\n` +
  `Screen reader: ${r.screenReader}\n` +
  (r.note ? `Focus: ${r.note}\n` : '') +
  (r.error ? `ERROR: ${r.error}\n` : '') +
  r.spoken.map((s) => `  ${String(s.step).padStart(3)}. ${s.said}`).join('\n')
).join('\n\n');
fs.writeFileSync(path.join(OUT, 'screenreader-transcript.txt'), txt);

console.log(`\nWrote ${file} and screenreader-transcript.txt`);
console.log('Read the transcript before quoting it — a screen reader says things a tree dump does not.');

/* ---------- helpers ---------- */
function sleep(ms) { return new Promise((r) => setTimeout(r, ms)); }

async function openUrl(url) {
  const { execSync } = await import('node:child_process');
  if (isMac) {
    // Safari is the browser VoiceOver is best behaved with.
    execSync(`open -a Safari ${JSON.stringify(url)}`);
  } else {
    execSync(`start "" ${JSON.stringify(url)}`, { shell: 'cmd.exe' });
  }
}
