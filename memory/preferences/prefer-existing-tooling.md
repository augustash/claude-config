---
name: Check what already exists before writing code we maintain
description: Before building a mechanism, check whether the framework, an installed contrib module, or an existing config setting already provides it — and whether it is switched on. Every line we write is a line we own forever.
metadata:
  type: feedback
---

Before writing a mechanism — a cron, a queue, a cleanup routine, a sync, an expiry policy —
**check whether the stack already provides it.** Core, the installed contrib modules, and the
project's own config are all cheaper than code we maintain.

**Why:** custom code is a permanent liability. It needs testing, it drifts from upstream, it
breaks on major upgrades, and the next person has to discover it exists. Contrib does not.
Kaza's rule: *"check if things already exist that we can utilise, before we're writing our own
code to maintain."*

## The check, in order

1. **Does the framework already do this?** Grep the relevant contrib module for `Cron`,
   `QueueWorker`, `*.services.yml`, `config/schema/` before assuming it doesn't.
2. **Is it already configured, and on?** A feature can exist *and* be enabled *and* still not
   be doing what you expect. Read the setting rather than inferring from the symptom.
3. **If it exists but doesn't fit — extend it, don't clone it.** Query tags
   (`hook_query_TAG_alter`), events, plugin managers and service decoration are published
   seams. Prefer widening the existing mechanism over standing a parallel one beside it.
4. **Only then write something**, and say plainly what gap it fills that the existing tooling
   structurally cannot.

## The case that produced this

On sisal (2026-08), abandoned carts were being refreshed thousands of times each. The first
move was to write a `StaleCartCleaner` service plus a cron hook. Kaza asked *"shouldn't there be
some sort of cleanup policy already? what does core commerce do?"* — and there was:
`commerce_cart` ships `Cron.php` and a `CartExpiration` queue worker, and the site **already had
it configured** at 30 days.

It genuinely didn't catch these carts, but for a structural reason worth finding rather than
routing around: Commerce expires on `changed`, and the refresh loop bumps `changed` on every
render, so the carts stayed permanently ahead of the window. The fix that shipped was ~15 lines
of `hook_query_commerce_cart_expiration_alter()` widening Commerce's own tagged query — reusing
its cron, batching and delete logic — instead of a parallel cron to maintain forever.

Two lessons, and the second is the sharper one: the custom service would have *worked*, which is
exactly why nobody would have questioned it. And "it isn't configured" was wrong — it was
configured, and reporting that without reading the setting sent the diagnosis the wrong way.

See also [[follow-site-conventions]], which covers the sibling case: matching how *this
codebase* already does something, rather than what the framework provides.
