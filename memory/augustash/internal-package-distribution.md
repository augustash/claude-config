---
name: Internal package distribution
description: Distribute internal augustash composer packages via dev-master + prefer-source instead of tagged releases — avoids release ceremony for dev-tooling work
type: project
---

For augustash-internal composer packages whose purpose is dev tooling, shared config, or memory (e.g. `augustash/claude-config`), distribute via the `master` branch HEAD rather than tagged releases.

**Why:** Tag-and-release cycles add friction to small, frequent updates — pushing a memory tweak or a config refinement shouldn't require cutting a version. With `dev-master`, every push to `master` is immediately available; consumers pull via `composer update <package>`. Combined with `composer config preferred-install.<vendor>/<package> source`, the vendor checkout is a real git working tree on the `master` branch, so authors edit, commit, and push from inside `vendor/` without checking out a branch first.

**How to apply:**

- For new internal packages: don't tag releases. Document the install as
  ```bash
  composer config preferred-install.<vendor>/<package> source && composer require --dev '<vendor>/<package>:dev-master'
  ```
- For existing internal packages on tags: switch consuming projects to `dev-master`, delete the now-meaningless tags (`git push origin --delete <tag>`), and refresh project lockfiles.
- Place internal dev-tooling packages in `require-dev`, not `require` — they shouldn't reach production builds.
- This convention applies to internal-only packages where the team controls both producer and consumer. Public packages or runtime-critical libraries should still use semver tags.
