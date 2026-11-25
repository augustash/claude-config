<?php
/**
 * Plugin Name: Add to cart redirect
 * Description: Redirects after a non-AJAX add to cart, so a refresh or Back can't add the item again.
 * Author: August Ash
 * Version: 1.0.0
 *
 * WHY THIS EXISTS
 *
 * WooCommerce only redirects after a form add to cart when "redirect to the
 * cart" is on, which it usually isn't. Otherwise the page the customer lands on
 * is the POST response itself, so refreshing it (and accepting the browser's
 * "resend" prompt) or going Back submits the add again: one item becomes
 * two. A customer refreshing to "fix" the count makes it worse each time.
 *
 * Install as wp-content/mu-plugins/add-to-cart-redirect.php. Background and how to
 * confirm the cause from the access log: claude-config
 * memory/wordpress/woocommerce-add-to-cart-resubmit.md.
 *
 * Redirecting to the same URL as a GET (Post/Redirect/Get) ends that. The
 * "added to your cart" notice lives in the session, so it still shows.
 */

add_filter( 'woocommerce_add_to_cart_redirect', function ( $url, $product = null ) {
	// Something else already redirects (Flatsome Buy Now runs later and wins
	// anyway), or this is the script-params call with no product.
	if ( $url || ! $product || wp_doing_ajax() ) {
		return $url;
	}
	// The cart-redirect setting handles its own redirect.
	if ( 'yes' === get_option( 'woocommerce_cart_redirect_after_add' ) ) {
		return $url;
	}

	// Strip the add-to-cart args so archive ?add-to-cart=ID links don't re-add
	// either.
	return remove_query_arg( [ 'add-to-cart', 'quantity', 'variation_id' ], home_url( wp_unslash( $_SERVER['REQUEST_URI'] ?? '/' ) ) );
}, 10, 2 );
