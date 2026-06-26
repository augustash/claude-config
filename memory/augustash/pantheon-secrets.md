# Pantheon Secrets (Terminus core) — two systems, and the multiline trap

Pantheon's secrets feature moved from the deprecated `terminus-secrets-manager-plugin` (and the deprecated `pantheon_secrets` EA Drupal module) into **Terminus core** (4.2.0+). Commands: `terminus secret:site:set|list|delete <site[.env]> <name> <value>`.

## It is NOT the legacy files/private/secrets.json

These are **two independent systems** that coexist; don't conflate them:

- **Legacy:** a real `secrets.json` file you place in the environment's `files/private/`. Read via `file_get_contents`. Many augustash sites still use this (slack_url, msp_* keys). Survives because the platform still serves the file.
- **New (Terminus core):** stored **Pantheon-side, encrypted at rest** — NOT a file on the mount. `terminus secret:site:list` shows them; the legacy file's keys do NOT appear there (and vice versa). Read at runtime via the **`pantheon_get_secret('name')`** function (auto-available on Pantheon, needs `--scope=web`) or the Customer Secrets PHP SDK. `secret:site:local-generate` pulls them into a local `./secrets.json` for dev only.

Verified empirically: set a value with `secret:site:set`, then on the env `pantheon_get_secret()` returns it AND `files/private/secrets.json` still exists separately (unchanged). So a value set via Terminus is invisible to a `file_get_contents('private://secrets.json')` reader unless you also write the file.

**App-read pattern:** make the credential reader prefer `pantheon_get_secret($key)` when `function_exists()`, fall back to the local `private://secrets.json` file otherwise (so the same `get()` works on Pantheon and locally). Avoids a new module dependency (don't need the deprecated `pantheon_secrets` Drupal module + Key for a couple of keys).

## set: create vs update, and scope/type

- `secret:site:set <site> ...` (no env) = base value for **all environments**; `<site.env>` = per-env override. Most credentials want the site-level base (omit env).
- **`--type`/`--scope` only on initial CREATE.** Updating an existing secret must OMIT them or it errors `Secret 'X' already exists. To update the value, omit type and scopes options.` Types: `env, runtime, composer`. Scopes: `ic, user, web`. For app-readable runtime values use **`--type=runtime --scope=web`**.

## Multiline values fail — base64-encode PEMs/certs

`secret:site:set` **cannot accept a multiline value** — Terminus's (Symfony Console) arg parser splits on newlines, so a PEM private key (multi-line) makes it error with the bare usage signature (`secret:site:set [--type ...] <siteenv> <name> <value>`), i.e. "too many arguments." Confirmed it's the newlines, not shell quoting: it fails even via `escapeshellarg()`; a single-line value of the same length sets fine.

**Fix: store multi-line secrets base64-encoded** (single line, transport-safe), decode on read in the app. Pattern in the consuming code: try `base64_decode($v, TRUE)`; if it decodes to something containing `-----BEGIN`, use the decoded PEM, else treat `$v` as already-raw PEM (so a base64 Pantheon value AND a raw-PEM local-file fallback both work). See sisal `sisal_product_signals` `Ga4Client::normalizeKey()`.
