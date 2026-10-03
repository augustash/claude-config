---
name: deploy-hook-order
description: pending hook_deploy_NAME functions are sorted by full function name before running, so hooks that build on each other break when several are pending at once — typically on the environment that receives them all together, i.e. live
metadata:
  type: reference
---
# Deploy hooks run in alphabetical order, not file order

`drush deploy` runs pending `hook_deploy_NAME()` functions after `cim`. It does **not** run
them in the order they are written in `MODULE.deploy.php`, nor in the order they were added.
`UpdateRegistry` collects every pending function name across all modules and calls `sort()`
on them (`core/lib/Drupal/Core/Update/UpdateRegistry.php`, `getAvailableUpdateFunctions()` /
`getPendingUpdateFunctions()`). Order is plain string order of the full function name —
module first, then the name.

## Why it bites only on one environment

On an environment you deploy to often (dev), hooks arrive **one deploy at a time**, so each
runs alone and the file order looks like it is being honoured. The environment that receives
a batch of them together (live, after a feature waits on review) runs them sorted — and a hook
that expects the state an earlier one leaves behind finds the state from before it instead.

Seen on ar-md (DMX Power), 2026-10-02. Three content hooks rewrote the same component prop in
sequence: `…_contact_pages_to_sales_map`, then `…_contact_pages_own_jobs`, then
`…_contact_sales_big_map_icon`. On dev they ran across three deploys, in that order. On live
all three were pending: `own_jobs` sorts before `to_sales_map`, so it ran first, and the last
two each met text they did not expect. Each was guarded on a hash of the text it expected, so
they **left the blocks alone and said so** rather than writing over them — the guard is what
turned a silent wrong page into a reported one, and a one-off guarded write fixed it.

## How to apply

- **Hooks that depend on each other: make the names sort in the order they must run.** A
  numeric segment does it — `MODULE_deploy_0101_contact_copy`, `…_0102_contact_icon` — or fold
  the steps into one hook. "Appended later in the file" is not an order.
- **Or make each hook independent of the others**: guard on what it needs and go straight to
  the final state, not to the next step.
- **Guard content writes on the exact prior value** (a hash of the prop) and report when it
  doesn't match, never overwrite blindly — that is what makes an out-of-order run recoverable.
- Before a live deploy carrying several hooks, list them sorted (`grep -ho
  'function [a-z_]*_deploy_[a-z0-9_]*' */*.deploy.php | sort`) — that is the run order.

Related: [[update-hook-testing]] (when a hook deserves a test), [[launcher-deploy]] (how the
deploy that runs them is invoked).
