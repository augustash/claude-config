// Visits Worker: one Analytics Engine data point per page view, recorded at the edge.
//
// Runs on the zone's page routes, ahead of the cache, and passes the request through
// untouched, so caching and the response are exactly what they were without it. It exists
// because visits from AI answers are invisible elsewhere: the apps send no referrer, and
// the landing page is served from the edge cache, so the origin log never sees it.
//
// No cookies, no stored IPs. `visitor` is a hash of IP + UA under a key that changes
// every UTC day, so one person counts once a day and can't be followed across days.
//
// Columns (the SQL in visits.sh depends on this order; append, never reorder):
//   blob1 host        blob2 path          blob3 referrer host   blob4 utm_source
//   blob5 utm_medium  blob6 utm_campaign  blob7 country         blob8 class
//   blob9 agent       blob10 cache status blob11 method         blob12 content type
//   blob13 visitor
//   double1 status    double2 ASN
//   index1 host (Analytics Engine samples per index, so one per site keeps sites even)

// Named fetchers, checked in order: first match wins. `ai` = fetching for an answer
// engine, `search` = a search index, `preview` = link unfurling, `bot` = anything else
// that says it is one.
const AGENTS = [
  ['ChatGPT-User', 'ai'], ['OAI-SearchBot', 'ai'], ['GPTBot', 'ai'],
  ['Perplexity-User', 'ai'], ['PerplexityBot', 'ai'],
  ['Claude-User', 'ai'], ['Claude-SearchBot', 'ai'], ['ClaudeBot', 'ai'],
  ['MistralAI-User', 'ai'], ['DuckAssistBot', 'ai'], ['meta-externalagent', 'ai'],
  ['Amazonbot', 'ai'], ['Bytespider', 'ai'], ['CCBot', 'ai'],
  ['meta-webindexer', 'search'], ['bingbot', 'search'], ['Googlebot', 'search'],
  ['Applebot', 'search'], ['DuckDuckBot', 'search'], ['YandexBot', 'search'],
  ['facebookexternalhit', 'preview'], ['LinkedInBot', 'preview'], ['Slackbot', 'preview'],
  ['Twitterbot', 'preview'], ['Discordbot', 'preview'],
];
const GENERIC_BOT = /bot|crawl|spider|slurp|scan|fetch|python|curl|wget|go-http|java\/|headless|lighthouse/i;

export default {
  async fetch(request, env, ctx) {
    // A bug in here must never cost a visitor: on an exception the request goes
    // straight to the origin as if no Worker existed.
    ctx.passThroughOnException();

    let upstream = request;
    // Test mode (workers.dev only, no route): proxy to the real site, since fetching our
    // own workers.dev hostname would loop.
    if (env.TEST_ORIGIN) {
      const url = new URL(request.url);
      url.host = env.TEST_ORIGIN;
      upstream = new Request(url, request);
    }

    const response = await fetch(upstream);
    try {
      env.VISITS.writeDataPoint(await point(upstream, response, env));
    } catch (e) {
      // Counting is best-effort; the response is already in hand.
    }
    return response;
  },
};

async function point(request, response, env) {
  const url = new URL(request.url);
  const ua = request.headers.get('user-agent') || '';
  const [agent, cls] = classify(ua);
  const q = url.searchParams;
  const cf = request.cf || {};
  return {
    indexes: [url.host],
    blobs: [
      url.host,
      url.pathname,
      referrerHost(request.headers.get('referer'), url.host),
      (q.get('utm_source') || '').toLowerCase(),
      (q.get('utm_medium') || '').toLowerCase(),
      (q.get('utm_campaign') || '').toLowerCase(),
      cf.country || '',
      cls,
      agent,
      response.headers.get('cf-cache-status') || '',
      request.method,
      (response.headers.get('content-type') || '').split(';')[0],
      await visitor(request.headers.get('cf-connecting-ip') || '', ua, env.VISITOR_SECRET || ''),
    ],
    doubles: [response.status, cf.asn || 0],
  };
}

function classify(ua) {
  if (!ua) return ['', 'bot'];
  const lower = ua.toLowerCase();
  for (const [name, cls] of AGENTS) {
    if (lower.includes(name.toLowerCase())) return [name, cls];
  }
  return GENERIC_BOT.test(ua) ? ['', 'bot'] : ['', 'browser'];
}

// Same-site referrers are internal navigation; keep only where a visit came from.
function referrerHost(referer, host) {
  if (!referer) return '';
  try {
    const h = new URL(referer).host;
    return h === host ? '' : h;
  } catch {
    return '';
  }
}

async function visitor(ip, ua, secret) {
  const day = new Date().toISOString().slice(0, 10);
  const data = new TextEncoder().encode(`${secret}|${day}|${ip}|${ua}`);
  const hash = new Uint8Array(await crypto.subtle.digest('SHA-256', data));
  return [...hash.slice(0, 8)].map((b) => b.toString(16).padStart(2, '0')).join('');
}
