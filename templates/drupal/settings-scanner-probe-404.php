<?php

/**
 * Scanner probes (*.php, wp-*) get a bare 404 before Drupal boots.
 *
 * Paste near the top of settings.php, after the @file docblock. Extend the
 * allowlist if the site serves any other real .php entry point.
 */
$probe_path = parse_url($_SERVER['REQUEST_URI'] ?? '', PHP_URL_PATH) ?: '';
if (PHP_SAPI !== 'cli'
  && preg_match('#(^/wp-|\.php$)#i', $probe_path)
  && !preg_match('#^/(index|update)\.php$|^/core/(install|rebuild|authorize)\.php$#', $probe_path)) {
  header('Cache-Control: public, max-age=86400');
  http_response_code(404);
  exit;
}
unset($probe_path);
