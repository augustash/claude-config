/**
 * Accessibility evidence sweep.
 *
 * Runs axe-core (WCAG 2.0/2.1 A + AA) plus the structural checks a rule engine
 * cannot make, across a page list at several viewports, and writes one JSON
 * record per run. See skills/accessibility-audit/SKILL.md for the method.
 *
 *   node audit.mjs config.json
 *
 * config.json:
 *   { "base": "https://example.com",
 *     "out": "./results",
 *     "pages": [ { "id": "home", "url": "/", "label": "Homepage" } ],
 *     "viewports": [ { "id": "desktop", "width": 1440, "height": 900 } ] }
 *
 * Every figure this prints is meant to be reproducible by re-running it. Do not
 * hand-edit the output.
 */
import { chromium } from 'playwright';
import fs from 'node:fs';
import path from 'node:path';
import { createRequire } from 'node:module';

const require = createRequire(import.meta.url);
const axeSource = fs.readFileSync(require.resolve('axe-core/axe.min.js'), 'utf8');
const axeVersion = require('axe-core/package.json').version;

const cfg = JSON.parse(fs.readFileSync(process.argv[2] || 'config.json', 'utf8'));
const BASE = cfg.base;
const OUT = cfg.out || './results';
const VIEWPORTS = cfg.viewports || [
  { id: 'desktop', width: 1440, height: 900 },
  { id: 'mobile', width: 390, height: 844 },
];

/* Let lazy regions render. A single fast scroll pass is NOT enough — it leaves
 * lazily-loaded blocks unbuilt and every count downstream comes out low. */
async function settle(page) {
  for (let pass = 0; pass < 2; pass++) {
    await page.evaluate(async () => {
      const h = document.body.scrollHeight;
      for (let y = 0; y < h; y += 400) {
        window.scrollTo(0, y);
        await new Promise((r) => setTimeout(r, 110));
      }
    });
    await page.waitForTimeout(3500);
  }
  await page.evaluate(() => window.scrollTo(0, 0));
  await page.waitForTimeout(1500);
}

/* ---------------- structural checks (run in page) ---------------- */
function structuralChecks() {
  const SEL =
    'a[href],button,input:not([type=hidden]),select,textarea,[tabindex],details>summary,iframe';

  // Is this removed from the accessibility tree by an ancestor?
  const atHidden = (el) => {
    let e = el;
    while (e && e !== document.documentElement) {
      const s = getComputedStyle(e);
      if (s.display === 'none' || s.visibility === 'hidden') return true;
      if (e.getAttribute && e.getAttribute('aria-hidden') === 'true') return true;
      e = e.parentElement;
    }
    return false;
  };
  const vis = (el) => {
    const s = getComputedStyle(el);
    if (s.display === 'none' || s.visibility === 'hidden') return false;
    if (parseFloat(s.opacity) === 0) return false;
    const r = el.getBoundingClientRect();
    return !(r.width === 0 && r.height === 0);
  };

  // Approximate accessible-name computation, and — crucially — WHERE the name
  // came from. "placeholder" is reported explicitly because it is not a label.
  const accName = (el) => {
    const t = el.tagName.toLowerCase();
    const al = el.getAttribute('aria-label');
    if (al && al.trim()) return { name: al.trim(), from: 'aria-label' };
    const lb = el.getAttribute('aria-labelledby');
    if (lb) {
      const s = lb
        .split(/\s+/)
        .map((id) => (document.getElementById(id) || {}).textContent || '')
        .map((x) => x.trim())
        .filter(Boolean)
        .join(' ');
      if (s) return { name: s, from: 'aria-labelledby' };
    }
    if (['input', 'select', 'textarea'].includes(t)) {
      if (el.id) {
        const l = document.querySelector(`label[for="${CSS.escape(el.id)}"]`);
        if (l && l.textContent.trim()) return { name: l.textContent.trim(), from: 'label[for]' };
      }
      const w = el.closest('label');
      if (w && w.textContent.trim()) return { name: w.textContent.trim(), from: 'wrapping label' };
      const ti = el.getAttribute('title');
      if (ti && ti.trim()) return { name: ti.trim(), from: 'title' };
      const ph = el.getAttribute('placeholder');
      if (ph && ph.trim()) return { name: ph.trim(), from: 'placeholder (NOT a label)' };
      return { name: '', from: 'NONE' };
    }
    if (t === 'img') {
      const a = el.getAttribute('alt');
      return { name: a === null ? '' : a, from: a === null ? 'NO alt attribute' : 'alt' };
    }
    const txt = (el.innerText || el.textContent || '').replace(/\s+/g, ' ').trim();
    if (txt) return { name: txt.slice(0, 80), from: 'text content' };
    const im = el.querySelector('img[alt]');
    if (im && im.getAttribute('alt').trim())
      return { name: im.getAttribute('alt').trim(), from: 'child img alt' };
    return { name: '', from: 'NONE' };
  };

  const tabbable = [...document.querySelectorAll(SEL)].filter((el) => {
    const ti = el.getAttribute('tabindex');
    if (ti !== null && parseInt(ti, 10) < 0) return false;
    if (el.disabled) return false;
    return vis(el);
  });

  /* Form controls with no programmatic label. */
  const unlabeled = [
    ...document.querySelectorAll(
      'input:not([type=hidden]):not([type=submit]):not([type=button]):not([type=image]),select,textarea'
    ),
  ]
    .filter(vis)
    .map((c) => {
      const n = accName(c);
      return {
        tag: c.tagName.toLowerCase(), type: c.type || null, id: c.id || null,
        fieldName: c.name || null, accessibleName: n.name, nameSource: n.from,
        required: !!c.required,
      };
    })
    .filter((r) => !r.accessibleName || r.nameSource.includes('NOT a label'));

  /* Adjacent tab stops going to the same destination. Compare origin+pathname:
   * exact-href misses links differing only by a query string, and pathname alone
   * makes every off-site share link to "/" look like a duplicate. */
  const dest = (a) => {
    try {
      const u = new URL(a.getAttribute('href'), location.href);
      return u.origin + u.pathname;
    } catch (e) {
      return null;
    }
  };
  const dupPairs = [];
  for (let i = 0; i < tabbable.length - 1; i++) {
    const a = tabbable[i], b = tabbable[i + 1];
    if (!a.getAttribute('href') || !b.getAttribute('href')) continue;
    const da = dest(a), db = dest(b);
    if (da && db && da === db) {
      dupPairs.push({
        position: i, destination: da,
        first: accName(a).name || '[image link]',
        second: accName(b).name || '[image link]',
      });
    }
  }

  /* Carousel slides scrolled out of view but still exposed to AT. Covers both
   * Swiper and slick; checks ancestor visibility first so a carousel inside a
   * display:none wrapper is not measured against a zero-width container. */
  const carousels = [];
  const scan = (containerSel, slideSel, lib) => {
    document.querySelectorAll(containerSel).forEach((c, i) => {
      if (atHidden(c)) {
        carousels.push({ lib, index: i, status: 'not in a11y tree (hidden ancestor)' });
        return;
      }
      const cr = c.getBoundingClientRect();
      if (cr.width === 0) {
        carousels.push({ lib, index: i, status: 'zero-width container — not measurable' });
        return;
      }
      const slides = [...c.querySelectorAll(slideSel)];
      let clipped = 0, chars = 0, focusables = 0;
      const samples = [];
      slides.forEach((s) => {
        const sr = s.getBoundingClientRect();
        const out = sr.right <= cr.left + 1 || sr.left >= cr.right - 1;
        if (out && !atHidden(s)) {
          clipped++;
          const t = (s.textContent || '').replace(/\s+/g, ' ').trim();
          chars += t.length;
          focusables += [...s.querySelectorAll(SEL)].filter(vis).length;
          if (samples.length < 3 && t) samples.push(t.slice(0, 90));
        }
      });
      carousels.push({
        lib, index: i, slides: slides.length,
        slidesClippedButExposed: clipped,
        anySlideAriaHidden: slides.some((s) => s.getAttribute('aria-hidden') === 'true'),
        anySlideInert: slides.some((s) => s.hasAttribute('inert')),
        hiddenTextCharsExposed: chars, focusableInClippedSlides: focusables,
        sampleHiddenText: samples,
      });
    });
  };
  scan('.swiper,.swiper-container', ':scope .swiper-slide', 'swiper');
  scan('.slick-slider', '.slick-slide', 'slick');

  /* Interactive elements with no accessible name at all. */
  const nameless = tabbable
    .map((el) => (accName(el).name ? null : {
      tag: el.tagName.toLowerCase(), role: el.getAttribute('role'),
      href: el.getAttribute('href') || null,
      cls: (el.className || '').toString().slice(0, 60),
    }))
    .filter(Boolean);

  const headings = [...document.querySelectorAll('h1,h2,h3,h4,h5,h6')].filter(vis)
    .map((h) => +h.tagName[1]);
  let skips = 0;
  for (let i = 1; i < headings.length; i++) if (headings[i] - headings[i - 1] > 1) skips++;

  return {
    tabbableCount: tabbable.length,
    unlabeledControls: unlabeled,
    duplicateAdjacentTabStops: dupPairs.length,
    duplicateSamples: dupPairs.slice(0, 8),
    carousels,
    namelessInteractiveCount: nameless.length,
    namelessInteractive: nameless.slice(0, 20),
    h1Count: headings.filter((l) => l === 1).length,
    headingSkips: skips,
  };
}

/* ---------------- keyboard walk ----------------
 * Tracks element IDENTITY, never a text signature. Two third-party widgets
 * sharing a class and label will otherwise read as a keyboard trap. */
async function keyboardWalk(page, maxSteps = 400) {
  await page.evaluate(() => {
    let n = 0;
    document.querySelectorAll('*').forEach((e) => e.setAttribute('data-a11y-uid', 'u' + n++));
    window.scrollTo(0, 0);
    document.body.focus();
  });

  const visits = [];
  const seen = new Set();
  let trap = null, noIndicator = [];

  for (let i = 0; i < maxSteps; i++) {
    await page.keyboard.press('Tab');
    const info = await page.evaluate(() => {
      const el = document.activeElement;
      if (!el || el === document.body) return null;
      const cs = getComputedStyle(el);
      // Compare against the element's own UNFOCUSED style — a control may
      // legitimately indicate focus by border or background, not just outline.
      const clone = el.cloneNode(false);
      clone.style.position = 'absolute';
      clone.style.left = '-9999px';
      document.body.appendChild(clone);
      const bs = getComputedStyle(clone);
      const hasOutline = cs.outlineStyle !== 'none' && parseFloat(cs.outlineWidth) > 0;
      const changed =
        hasOutline || cs.boxShadow !== bs.boxShadow ||
        cs.backgroundColor !== bs.backgroundColor ||
        cs.borderColor !== bs.borderColor || cs.borderWidth !== bs.borderWidth;
      clone.remove();
      return {
        uid: el.getAttribute('data-a11y-uid'),
        tag: el.tagName.toLowerCase(),
        cls: (el.className || '').toString().slice(0, 50),
        name: (el.getAttribute('aria-label') || el.innerText || el.value || '')
          .replace(/\s+/g, ' ').trim().slice(0, 45),
        indicator: changed,
      };
    });
    if (!info) break;
    visits.push(info);
    if (!info.indicator) noIndicator.push(info);

    const n = visits.length;
    if (n >= 3 && visits[n - 1].uid === visits[n - 2].uid && visits[n - 2].uid === visits[n - 3].uid) {
      trap = info;
      break;
    }
    if (seen.has(info.uid)) break; // wrapped around
    seen.add(info.uid);
  }

  return {
    stopsReached: seen.size,
    keyboardTrapDetected: !!trap,
    trapAt: trap,
    stopsWithoutFocusIndicator: noIndicator.length,
    noIndicatorSample: noIndicator.slice(0, 10),
  };
}

/* ---------------- runner ---------------- */
fs.mkdirSync(OUT, { recursive: true });
const results = [];
const browser = await chromium.launch({ ignoreHTTPSErrors: true });

for (const vp of VIEWPORTS) {
  // bypassCSP so axe can be injected on pages with a strict script-src.
  const ctx = await browser.newContext({
    viewport: { width: vp.width, height: vp.height },
    ignoreHTTPSErrors: true,
    bypassCSP: true,
  });

  for (const p of cfg.pages) {
    const url = BASE + p.url;
    const rec = { viewport: vp.id, size: `${vp.width}x${vp.height}`, id: p.id, label: p.label, url };
    const page = await ctx.newPage();
    try {
      const resp = await page.goto(url, { waitUntil: 'domcontentloaded', timeout: 45000 });
      rec.httpStatus = resp ? resp.status() : null;
      rec.finalUrl = page.url();
      if (rec.finalUrl !== url) rec.note = 'redirected — check this is the page you meant to test';
      await settle(page);
      rec.title = await page.title();
      rec.checks = await page.evaluate(structuralChecks);

      await page.addScriptTag({ content: axeSource });
      rec.axe = await page.evaluate(async () => {
        const run = async (tags) => {
          const r = await window.axe.run(document, {
            runOnly: { type: 'tag', values: tags },
            resultTypes: ['violations'],
          });
          return r.violations.map((v) => ({
            id: v.id, impact: v.impact, help: v.help,
            wcag: v.tags.filter((t) => /^wcag\d/.test(t)),
            nodes: v.nodes.length,
            sample: v.nodes.slice(0, 3).map((n) => ({
              target: n.target.join(' ').slice(0, 110),
              why: (n.failureSummary || '').replace(/\s+/g, ' ').slice(0, 200),
            })),
          }));
        };
        return {
          wcagAA: await run(['wcag2a', 'wcag2aa', 'wcag21a', 'wcag21aa']),
          bestPractice: await run(['best-practice']),
        };
      });
      rec.axeSummary = {
        violationTypes: rec.axe.wcagAA.length,
        affectedNodes: rec.axe.wcagAA.reduce((a, v) => a + v.nodes, 0),
      };
      rec.keyboard = await keyboardWalk(page);
    } catch (e) {
      rec.error = String(e).slice(0, 300);
      // A 403 here is usually bot protection, not a broken page.
      if (/403/.test(rec.error)) rec.note = 'blocked (bot protection?) — test this page manually';
    }
    await page.close();
    results.push(rec);

    console.log(
      `[${vp.id}] ${p.id.padEnd(12)} ` +
        (rec.error
          ? 'ERROR ' + rec.error.slice(0, 60)
          : `axe=${rec.axeSummary.violationTypes}t/${rec.axeSummary.affectedNodes}n · ` +
            `unlabeled=${rec.checks.unlabeledControls.length} · ` +
            `dupStops=${rec.checks.duplicateAdjacentTabStops} · ` +
            `noFocusRing=${rec.keyboard.stopsWithoutFocusIndicator}/${rec.keyboard.stopsReached} · ` +
            `trap=${rec.keyboard.keyboardTrapDetected}`)
    );
  }
  await ctx.close();
}
await browser.close();

const out = {
  generatedAt: new Date().toISOString(),
  base: BASE,
  tooling: { axeCore: axeVersion, engine: 'chromium (playwright)' },
  results,
};
fs.writeFileSync(path.join(OUT, 'audit.json'), JSON.stringify(out, null, 2));
console.log('\nWrote ' + path.join(OUT, 'audit.json'));
console.log('Reminder: a trap or duplicate-stop count from this sweep is a LEAD, not a finding. Verify it before it reaches a document.');
