/**
 * Virtual screen-reader capture — headless, no OS permissions, no AT install.
 *
 * Drives @guidepup/virtual-screen-reader over the live rendered page and records
 * the announcement sequence. This is the layer that catches what a rule engine
 * structurally cannot: alt text that exists but says nothing, a control whose
 * name is its value, a group whose legend never reaches the field.
 *
 *   node virtual-screenreader.mjs '<url>' [selector] [steps]
 *   node virtual-screenreader.mjs '<urlA>' '<urlB>' --compare [selector]
 *
 * `selector` scopes the reader to one component (pass the CSS selector of an
 * element inside it — the script walks up to its enclosing fieldset/section).
 * Scoping is what makes a before/after comparison readable; a whole-page read
 * is hundreds of lines and diffs badly.
 *
 * --compare reads two URLs with identical settings and prints them side by side,
 * which is how you evidence "this is what changed" rather than asserting it.
 */
import { chromium } from 'playwright';
import fs from 'node:fs';

// The bundle exports a RENAMED local (`export{X$ as virtual}`). Bind the local
// identifier — `virtual` is not in scope, and a greedy \S+ here will swallow the
// preceding comma and capture the wrong name.
const BUNDLE = 'node_modules/@guidepup/virtual-screen-reader/lib/esm/index.browser.js';
const RAW = fs.readFileSync(BUNDLE, 'utf8');
const localName = (RAW.match(/export\s*\{[^}]*?([A-Za-z_$][\w$]*)\s+as\s+virtual\s*[,}]/) || [])[1];
if (!localName) throw new Error('could not locate the virtual export binding in ' + BUNDLE);
const SRC = RAW + `\nwindow.__virtual = ${localName};`;

const argv = process.argv.slice(2);
const compare = argv.includes('--compare');
const positional = argv.filter((a) => a !== '--compare');
const urls = compare ? positional.slice(0, 2) : [positional[0]];
const selector = positional[compare ? 2 : 1] || null;
const steps = parseInt(positional[compare ? 3 : 2] || '60', 10);
if (!urls[0]) {
  console.error('usage: node virtual-screenreader.mjs <url> [selector] [steps]');
  process.exit(1);
}

const browser = await chromium.launch({ ignoreHTTPSErrors: true });
const ctx = await browser.newContext({
  viewport: { width: 1440, height: 900 },
  ignoreHTTPSErrors: true,
  bypassCSP: true,
});

const runs = [];
for (const url of urls) {
  const page = await ctx.newPage();
  await page.goto(url, { waitUntil: 'domcontentloaded', timeout: 60000 });

  // two slow passes: lazily-built regions do not exist after one fast scroll
  for (let i = 0; i < 2; i++) {
    await page.evaluate(async () => {
      const h = document.body.scrollHeight;
      for (let y = 0; y < h; y += 400) {
        window.scrollTo(0, y);
        await new Promise((r) => setTimeout(r, 100));
      }
    });
    await page.waitForTimeout(3000);
  }
  await page.evaluate(() => window.scrollTo(0, 0));

  await page.addScriptTag({ content: SRC, type: 'module' });
  await page.waitForFunction(() => !!window.__virtual, null, { timeout: 15000 });

  const spoken = await page.evaluate(
    async ({ selector, steps }) => {
      const v = window.__virtual;
      let container = document.body;
      if (selector) {
        const el = document.querySelector(selector);
        if (!el) return ['(selector matched nothing: ' + selector + ')'];
        container =
          el.closest('fieldset')?.parentElement?.closest('fieldset') ||
          el.closest('fieldset') || el.closest('section, form') || el;
      }
      await v.start({ container });
      const phrases = [];
      for (let i = 0; i < steps; i++) {
        await v.next();
        const s = (await v.lastSpokenPhrase()) || '';
        const t = s.replace(/\s+/g, ' ').trim();
        if (t) phrases.push(t);
      }
      await v.stop();
      return phrases;
    },
    { selector, steps }
  );

  runs.push({ url, spoken });
  await page.close();
}
await browser.close();

if (compare && runs.length === 2) {
  const [a, b] = runs;
  const n = Math.max(a.spoken.length, b.spoken.length);
  const w = 62;
  console.log('\n' + pad('A: ' + a.url, w) + '  |  B: ' + b.url + '\n' + '-'.repeat(w * 2));
  for (let i = 0; i < n; i++) {
    const l = a.spoken[i] || '', r = b.spoken[i] || '';
    const mark = l === r ? ' ' : '*';   // * marks a line that differs
    console.log(mark + ' ' + pad(l.slice(0, w - 2), w) + '  |  ' + r.slice(0, w));
  }
  console.log('\n* = differs between the two runs');
} else {
  for (const r of runs) {
    console.log('\n===== ' + r.url);
    r.spoken.forEach((s, i) => console.log('  ' + String(i + 1).padStart(3) + '. ' + s));
  }
}

fs.mkdirSync('./results', { recursive: true });
fs.writeFileSync(
  './results/virtual-screenreader.json',
  JSON.stringify({ generatedAt: new Date().toISOString(), selector, runs }, null, 2)
);
console.log('\nWrote ./results/virtual-screenreader.json');

function pad(s, n) { return (s + ' '.repeat(n)).slice(0, n); }
