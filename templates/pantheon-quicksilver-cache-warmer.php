<?php

/**
 * @file
 * Drop-in Quicksilver post-deploy cache warmer.
 *
 * Copy to web/private/scripts/cache_warm.php in a Pantheon Drupal site, swap
 * the $paths list, and wire it into pantheon.yml under workflows.deploy.after
 * as a `webphp` step. See the shared note pantheon-quicksilver-cache-warmer.md.
 *
 * After a deploy the FPM container bounces and APCu empties; the first real
 * requests then race to rebuild Drupal's metadata layer from cold, which on a
 * heavy page produces slow responses and 502/503s. Warming the heaviest pages
 * once, sequentially, populates the shared caches before real traffic lands.
 */

// Live only — other envs deploy too often to justify the extra deploy time,
// and their cold-cache pain isn't user-facing.
if (($_ENV['PANTHEON_ENVIRONMENT'] ?? '') !== 'live') {
  echo "[cache-warm] Skipping — not on live.\n";
  exit(0);
}

// Swap this list per site: homepage + the heaviest cacheable pages, ordered by
// request volume. Exclude per-session/dynamic paths (/cart, /checkout, /user),
// per-query pages (/search), and infra endpoints (/pantheon_healthcheck,
// /batch). Mine the nginx access log for status-200, query-stripped page hits.
$paths = [
  '/',
];

$env = $_ENV['PANTHEON_ENVIRONMENT'] ?? 'unknown';
$site = $_ENV['PANTHEON_SITE_NAME'] ?? 'unknown';
// Hit the platform origin, not a CDN-/Cloudflare-fronted custom domain — the
// custom domain may serve the warm request from the edge and never reach
// origin, so it wouldn't populate Drupal's caches.
$base = "https://{$env}-{$site}.pantheonsite.io";

echo "[cache-warm] Starting on {$env} ({$base})\n";
$total_start = microtime(TRUE);

foreach ($paths as $path) {
  $ch = curl_init($base . $path);
  curl_setopt_array($ch, [
    CURLOPT_RETURNTRANSFER => TRUE,
    // Set above your slowest cold page.
    CURLOPT_TIMEOUT => 45,
    CURLOPT_CONNECTTIMEOUT => 5,
    CURLOPT_FOLLOWLOCATION => TRUE,
    CURLOPT_USERAGENT => 'Pantheon-Quicksilver-Cache-Warmer/1.0',
  ]);

  $start = microtime(TRUE);
  curl_exec($ch);
  $duration = microtime(TRUE) - $start;
  $code = curl_getinfo($ch, CURLINFO_HTTP_CODE);
  $error = curl_error($ch);
  curl_close($ch);

  $status = ($code >= 200 && $code < 400) ? 'OK ' : 'ERR';
  echo $error
    ? sprintf("[cache-warm] ERR %s %.2fs %s — %s\n", $code, $duration, $path, $error)
    : sprintf("[cache-warm] %s %d %.2fs %s\n", $status, $code, $duration, $path);
}

printf("[cache-warm] Done in %.2fs\n", microtime(TRUE) - $total_start);
