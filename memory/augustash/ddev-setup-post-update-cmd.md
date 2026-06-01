---
name: ddev-setup-post-update-cmd
description: Wiring augustash/ddev-drupal|ddev-wordpress's post-update-cmd hook via `ddev composer config --json '[...]'` mangles the backslashes in the `Augustash\Ddev` namespace, storing a quoted string instead of an array — `composer update` then dies with `Class "[\"Augustash\Ddev ... is not autoloadable`. Set it scalar, or edit composer.json by hand.
metadata:
  type: reference
---

The `augustash/ddev-drupal` and `augustash/ddev-wordpress` packages need two
Composer script hooks wired into the consuming project's `composer.json`:
`scripts.ddev-setup` → `Augustash\Ddev::postPackageInstall` and
`scripts.post-update-cmd` → `Augustash\Ddev::postUpdate` (the latter auto-runs
setup in update mode on every `composer update`).

**The trap.** The old README install one-liner set the array hook with:

```bash
ddev composer config --json --merge scripts.post-update-cmd '["Augustash\\Ddev::postUpdate"]'
```

Those values contain backslashes (the PHP namespace separator). Passed as inline
JSON through `ddev composer` the value crosses **two** shells (host → container),
which eats the backslashes, so Composer can't parse it as JSON and stores the
whole literal as a scalar **string**:

```json
"post-update-cmd": "[\"Augustash\\\\Ddev::postUpdate\"]"
```

On the next `composer update`, Composer treats that string as the callable name
and fails: `Class "["Augustash\Ddev is not autoloadable, can not call
post-update-cmd script` (note the leading `["` — the smoking gun). This has bitten
multiple sites. The `extra.drupal-scaffold.allowed-packages` `--json` line is
*safe* because its value has no backslashes; the `ddev-setup` scalar line is safe
because it isn't `--json`. Only the backslash-bearing `--json` array mangles.

**Fix / correct wiring.** Set the hook as a scalar (a single hook is a valid
scalar script value) — the shell-safe form the READMEs now use:

```bash
ddev composer config scripts.post-update-cmd "Augustash\\Ddev::postUpdate"
```

Or, when the project already has a `post-update-cmd` you must preserve (e.g. a
Pantheon `DrupalComposerManaged\ComposerScripts::postUpdate` hook — scalar config
would *replace* it), edit `composer.json` directly so both run:

```json
"post-update-cmd": [
    "DrupalComposerManaged\\ComposerScripts::postUpdate",
    "Augustash\\Ddev::postUpdate"
]
```

Editing the file directly is always safe — the mangling is purely a
shell-escaping artifact of `ddev composer config --json`, not a JSON-file issue.

Related: [[ddev-drupal-pantheon-site-var]], [[ddev-workflow]]
