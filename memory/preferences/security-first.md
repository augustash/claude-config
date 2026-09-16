---
name: security-first
description: >-
  Security outranks convenience, velocity and elegance on every tradeoff — take
  the secure option without being asked, and say so.
metadata:
  type: feedback
---

**When a design choice has a security dimension, take the secure option by default and
name the tradeoff.** Don't offer the convenient version and wait to be told; don't file
it as a follow-up. Dane (2026-08-08, oof): *"remember security is number 1 priority."*

**Why:** the tools we build read across the whole client estate — fleet dashboards,
credentials for every site, log contents. A convenience shortcut in that context is not a
small local compromise; it's an authenticated path into everything. The cost of the secure
choice is nearly always a few extra lines, and the cost of the insecure one is discovered
by someone else.

**How to apply:**

- **Credentials never go in Drupal config.** Config is exported to YAML and committed, so
  a token there lands in git and in every checkout — and `cex` is exactly the routine
  action nobody inspects. Order of preference: environment variable (platform secret
  store, so it never touches the database) → State API (not exported, but present in every
  database dump, which matters for who may pull production) → `key` module. See
  [pantheon-secrets](../augustash/pantheon-secrets.md).
- **Uploads are typed by their bytes, not their filename or `Content-Type`.** Both are
  attacker-controlled. SVG stays off the allowlist — browsers execute it, so "upload an
  avatar" becomes stored XSS.
- **Sessions must be revocable.** A signed token carrying its own expiry cannot be killed
  early, so a stolen laptop stays signed in until it ages out and the only remedy is
  rotating the secret and logging out everybody.
- **Auth checks belong where the work happens**, not only in middleware or a route guard.
  A server action is its own callable endpoint and inherits nothing from the page.
- **Endpoints that answer differently for known and unknown accounts are an enumeration
  oracle.** Sign-in and reset flows must respond identically either way.
- **Don't log the secret you are protecting**, including into an audit trail — record that
  a credential was supplied, never which one.

Flag the security implication in one sentence when it's load-bearing, then proceed. This
is a standing instruction, not something to re-confirm each time.
