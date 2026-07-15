<?php
/**
 * Plugin Name:  Tier 1 CSP
 * Description:  Right-sized Content-Security-Policy for a marketing/brochure WordPress site. Clears a scanner's default-src findings (no *, no 'unsafe-inline', no data: in default-src) WITHOUT a host allowlist to maintain — so it cannot silently blackhole a newly added GTM/marketing tag.
 * Version:      1.0.0
 * Author:       August Ash
 * Requires PHP: 7.4
 *
 * TEMPLATE — copy into wp-content/plugins/<site>-csp/ and rename. See the
 * "RSSSL Pro CSP enforce breaks analytics" memory for when/why to use this.
 *
 * SINGLE-OWNER RULE: this plugin must be the ONLY emitter of Content-Security-Policy.
 * If Really Simple SSL (or Headers Security Advanced/HSTS, etc.) is installed, its CSP
 * feature must stay OFF. Two CSP headers = the browser enforces the INTERSECTION of
 * both = silent breakage of whatever the stricter one omits (classic GA/Ads killer).
 *
 * Tier 2 (strict host allowlist) is rarely justified on a brochure site — see the memory.
 */

defined('ABSPATH') || exit;

add_action('send_headers', static function (): void {
	// Front end only. wp-admin / login manage their own needs and aren't what a scanner sees.
	if (is_admin()) {
		return;
	}

	$policy = implode('; ', [
		'upgrade-insecure-requests',

		// default-src 'self' is what satisfies the flagged default-src findings.
		"default-src 'self'",

		// Expensive directives — permissive by SCHEME (https:), not by host list.
		// Nothing to maintain; a new tag can never be silently blocked.
		// 'unsafe-inline' + 'unsafe-eval' are mandatory for WordPress + Google Tag Manager.
		"script-src 'self' 'unsafe-inline' 'unsafe-eval' https:",
		"style-src 'self' 'unsafe-inline' https:",
		"img-src 'self' data: blob: https:",
		"font-src 'self' data: https:",
		"connect-src 'self' https:",
		"frame-src 'self' https:",
		"worker-src 'self' blob:",

		// Cheap wins kept strict — real protection, zero maintenance, zero break risk.
		"object-src 'none'",
		"base-uri 'self'",
		"form-action 'self' https:",   // tighten to just 'self' if no form posts off-site
		"frame-ancestors 'self'",
	]);

	header('Content-Security-Policy: ' . $policy);
}, 99);
