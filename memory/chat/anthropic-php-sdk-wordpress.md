---
name: Anthropic PHP SDK in a WordPress plugin
description: The SDK needs a PSR-18 client WordPress doesn't ship, weighs 24 MB vendored, and its list calls return Page objects; choices that held up on Pantheon.
metadata:
  type: reference
---

Building the [site-chat](../../skills/site-chat/SKILL.md) plugin on Enterprise Minnesota (WordPress on Pantheon,
2026-11) with `anthropic-ai/sdk` 1.x:

- **"No PSR-18 HTTP client or PSR-17 factory found"** on the first call. WordPress has no
  PSR-18 client. Add `php-http/curl-client` + `nyholm/psr7`, not Guzzle: plugins often
  bundle their own Guzzle and two copies collide.
- **Give the plugin its own `composer.json` and vendor/** when the site commits vendor and
  Pantheon runs no composer build. The SDK is about 24 MB and 3,800 files (generated
  types); runtime cost is nil since only used classes load. Kaza chose to keep the SDK
  over hand-rolled HTTP.
- `$client->models->list()` returns a `Page`; iterate `->pagingEachItem()`. Iterating the
  page itself throws "Property 'id' does not exist". `models->list()` is a free way to
  verify a key.
- Structured output: `outputConfig: ['effort' => 'low', 'format' => ['type' => 'json_schema',
  'schema' => …]]`; read the first text block and `json_decode`. Check
  `stopReason === 'refusal'` first.
- Real cost per call: `usage` tokens × the model's $/M price (which equals micro-dollars
  per token). Store it per request; it beats any estimate.
- Catch `AuthenticationException` / `PermissionDeniedException` separately and alert
  (admin notice + email, at most daily), or a revoked key fails silently.
