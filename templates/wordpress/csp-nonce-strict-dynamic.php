<?php
/**
 * Plugin Name:  CSP (nonce + strict-dynamic)
 * Description:  Front-end Content-Security-Policy that passes Google CSP Evaluator's script-src check WITHOUT a host allowlist: a per-request nonce + 'strict-dynamic', nonced at BOTH WordPress's script-printing layer and via an output buffer that auto-nonces every in-page <script>. Reference implementation — copy into a site plugin and adjust the directive set. See memory/wordpress/csp-nonce-strict-dynamic.md.
 * Version:      2.0.0
 * Author:       August Ash
 * Requires PHP: 7.4
 *
 * SINGLE-OWNER RULE: this must be the ONLY emitter of Content-Security-Policy.
 * If Really Simple SSL (or any other header plugin) also emits CSP, the browser
 * enforces the INTERSECTION of both and things break silently. Keep the others'
 * CSP feature OFF — and the header_remove() below strips any that slipped through
 * (e.g. RSSSL's PHP-emitted report-only header) before we set ours.
 *
 * A nonce covers <script> TAGS only. Inline on*= event handlers and javascript:
 * URIs are NOT nonce-able and ARE blocked once strict-dynamic disables
 * 'unsafe-inline' in modern browsers — fix those at the source (move the handler
 * into a real <script>, which this buffer then nonces).
 *
 * TWO nonce layers, both required. The output buffer alone MISSES some
 * wp_add_inline_script() output (emitted during wp_head in a way that escapes the
 * template_redirect buffer — e.g. Gravity Forms' `gform` foundation bootstrap),
 * and under strict-dynamic a single un-nonced inline script is BLOCKED. The
 * wp_inline_script_attributes / wp_script_attributes filters nonce enqueued
 * scripts at WP's source layer (WP 5.7+), independent of buffer timing; the buffer
 * remains the fallback for raw <script> echoed outside wp_enqueue.
 */

defined('ABSPATH') || exit;

/** Per-request nonce (base64 of 128 bits) — one value for the header + every injected tag. */
function aa_csp_nonce(): string {
	static $nonce = null;
	if ($nonce === null) {
		$nonce = base64_encode(random_bytes(16));
	}
	return $nonce;
}

/** Full policy for a nonce. Only script-src is unusual; the rest is a low-maintenance set. */
function aa_csp_policy(string $nonce): string {
	return implode('; ', [
		'upgrade-insecure-requests',
		"default-src 'self'",
		// nonce + strict-dynamic clears CSP Evaluator's script-src findings; trust
		// propagates from a nonced script to whatever it loads (gtm.js -> GA4/Ads),
		// so only the tags in the served HTML need a nonce. The trailing
		// https: 'unsafe-inline' is legacy fallback that strict-dynamic browsers
		// ignore (and the Evaluator does not flag). No 'unsafe-eval' — add it only
		// if a GTM tag needs eval (it is a standalone MEDIUM finding).
		"script-src 'nonce-{$nonce}' 'strict-dynamic' https: 'unsafe-inline'",
		"style-src 'self' 'unsafe-inline' https:",
		"img-src 'self' data: blob: https:",
		"font-src 'self' data: https:",
		"connect-src 'self' https:",
		"frame-src 'self' https:",
		"worker-src 'self' blob:",
		"object-src 'none'",
		"base-uri 'self'",
		"form-action 'self' https:",
		"frame-ancestors 'self'",
	]);
}

/** Add nonce="…" to every <script> that lacks one. ld+json/json blocks are a harmless no-op. */
function aa_csp_add_nonces(string $html): string {
	$nonce = aa_csp_nonce();
	$out = preg_replace_callback(
		'#<script\b(?![^>]*\bnonce=)([^>]*)>#i',
		static function (array $m) use ($nonce): string {
			return '<script nonce="' . $nonce . '"' . $m[1] . '>';
		},
		$html
	);
	// Never return null (would blank the page) — fall back to untouched HTML.
	return $out ?? $html;
}

/**
 * Front-end HTML only: emit the header, then buffer to inject nonces.
 * template_redirect never fires for admin/AJAX/REST; skip non-HTML documents and
 * bail if headers already went out (can't pair a header with the buffered nonces).
 */
add_action('template_redirect', static function (): void {
	if (is_feed() || is_robots() || is_trackback() || is_comment_feed()) {
		return;
	}
	if (headers_sent()) {
		return;
	}

	// Enforce the single-owner rule at runtime: strip any other CSP (e.g. a header
	// plugin's report-only variant) before emitting ours, so the browser never
	// enforces an intersection.
	header_remove('Content-Security-Policy');
	header_remove('Content-Security-Policy-Report-Only');

	$nonce = aa_csp_nonce();
	header('Content-Security-Policy: ' . aa_csp_policy($nonce));

	// Layer 1: nonce enqueued scripts at WP's printing layer, independent of buffer
	// timing (catches wp_add_inline_script output the buffer misses). Registered
	// here so the nonce matches the header just emitted; wp_head runs later.
	$add_nonce = static function (array $attr) use ($nonce): array {
		if (empty($attr['nonce'])) {
			$attr['nonce'] = $nonce;
		}
		return $attr;
	};
	add_filter('wp_inline_script_attributes', $add_nonce);
	add_filter('wp_script_attributes', $add_nonce);

	// Layer 2: buffer fallback for raw <script> echoed outside wp_enqueue.
	ob_start('aa_csp_add_nonces');
}, 0);
