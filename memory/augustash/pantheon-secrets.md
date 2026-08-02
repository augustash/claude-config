---
name: Pantheon Secrets (Terminus core) — two systems, and the multiline trap
description: Pantheon secrets moved to Terminus core (4.2.0+); it's a separate system from the legacy files/private/secrets.json — don't conflate them, and watch the multiline-value trap.
type: reference
---

# Pantheon Secrets (Terminus core) — two systems, and the multiline trap

Pantheon's secrets feature moved from the deprecated `terminus-secrets-manager-plugin` into **Terminus core** (4.2.0+). Commands: `terminus secret:site:set|list|delete <site[.env]> <name> <value>`.

> ⚠ **Correction (2026-08-02).** An earlier version of this note also called the `pantheon_secrets` **Drupal module** deprecated. That was wrong — it conflated the module with the Secrets **EA program** its README references. The module is actively maintained: 1.1.0 released 2026-07-03, stable, security-team covered, `^10 || ^11`. Verified on drupal.org, and adopted on ar-md. Don't avoid it on the strength of the old wording here.

## It is NOT the legacy files/private/secrets.json

These are **two independent systems** that coexist; don't conflate them:

- **Legacy:** a real `secrets.json` file you place in the environment's `files/private/`. Read via `file_get_contents`. Many augustash sites still use this (slack_url, msp_* keys). Survives because the platform still serves the file.
- **New (Terminus core):** stored **Pantheon-side, encrypted at rest** — NOT a file on the mount. `terminus secret:site:list` shows them; the legacy file's keys do NOT appear there (and vice versa). Read at runtime via the **`pantheon_get_secret('name')`** function (auto-available on Pantheon, needs `--scope=web`) or the Customer Secrets PHP SDK. `secret:site:local-generate` pulls them into a local `./secrets.json` for dev only.

Verified empirically: set a value with `secret:site:set`, then on the env `pantheon_get_secret()` returns it AND `files/private/secrets.json` still exists separately (unchanged). So a value set via Terminus is invisible to a `file_get_contents('private://secrets.json')` reader unless you also write the file.

## Reading them in Drupal — prefer Key + pantheon_secrets

**Default to `drupal/pantheon_secrets`**, which provides a **Key provider plugin**, so each credential becomes one Key entity and only the secret's *name* is in exported config. Reasons to prefer it over a hand-rolled reader:

- `drupal/key` is often already installed and enabled (Turnstile, and most mail/API modules require it), so it is usually not a new dependency at all — check `core.extension.yml` before assuming it is.
- Contrib that wants a credential (Symfony Mailer/Postmark, Turnstile) consumes a **Key entity** natively. A bespoke reader has to be adapted to each one; a Key entity is just selected.

**Set the secret** `--type=runtime --scope=web`, and **site-level (omit the env)** so dev/test/live all resolve it with nothing to redo at launch.

⚠ **Omit `base64_encoded` from `key_provider_settings`.** The module's config schema (`key.provider.pantheon`) declares only `secret_name`, so including it makes the exported config schema-invalid and Drupal warns on save. `getKeyValue()` guards it with `isset()`, so leaving it out is safe for any value that is not encoded.

⚠ **Locally the Pantheon provider has no platform to call.** Override the provider per key in `settings.local.php` rather than editing the entity, so exported config keeps the Pantheon provider:

```php
$config['key.key.<id>']['key_provider'] = 'config';
$config['key.key.<id>']['key_provider_settings'] = ['key_value' => '…'];
```

**Hand-rolled alternative**, still fine for a site with one or two credentials and no Key module: prefer `pantheon_get_secret($key)` when `function_exists()`, fall back to `$settings[…]` from `settings.local.php` or the local `private://secrets.json`, so the same `get()` works on and off Pantheon.

## set: create vs update, and scope/type

- `secret:site:set <site> ...` (no env) = base value for **all environments**; `<site.env>` = per-env override. Most credentials want the site-level base (omit env).
- **`--type`/`--scope` only on initial CREATE.** Updating an existing secret must OMIT them or it errors `Secret 'X' already exists. To update the value, omit type and scopes options.` Types: `env, runtime, composer`. Scopes: `ic, user, web`. For app-readable runtime values use **`--type=runtime --scope=web`**.

## Multiline values fail — base64-encode PEMs/certs

`secret:site:set` **cannot accept a multiline value** — Terminus's (Symfony Console) arg parser splits on newlines, so a PEM private key (multi-line) makes it error with the bare usage signature (`secret:site:set [--type ...] <siteenv> <name> <value>`), i.e. "too many arguments." Confirmed it's the newlines, not shell quoting: it fails even via `escapeshellarg()`; a single-line value of the same length sets fine.

**Fix: store multi-line secrets base64-encoded** (single line, transport-safe), decode on read in the app. Pattern in the consuming code: try `base64_decode($v, TRUE)`; if it decodes to something containing `-----BEGIN`, use the decoded PEM, else treat `$v` as already-raw PEM (so a base64 Pantheon value AND a raw-PEM local-file fallback both work). See sisal `sisal_product_signals` `Ga4Client::normalizeKey()`.
