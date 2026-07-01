---
name: Internal package distribution
description: Distribute internal augustash composer packages via dev-master + prefer-source instead of tagged releases — avoids release ceremony for dev-tooling work; note prefer-source makes a dirty vendor working tree silently skip composer update hooks
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

**Gotcha — a dirty vendor working tree silently skips the update hook:** Because prefer-source makes the vendor copy a real git checkout, `composer update <package>` updates it through composer's `VcsDownloader`, which **refuses to touch a working tree that has uncommitted changes** — it aborts that package with `Source directory ... has uncommitted changes`. The lockfile reference may still get rewritten, so it *looks* like the update happened, but the source checkout and the package's composer hooks (`POST_PACKAGE_UPDATE` / `POST_PACKAGE_INSTALL`, e.g. claude-config's `wire()` that fixes `.claude/CLAUDE.md`) never run. The classic trigger is running the package's *own* test suite: PHPUnit writes `.phpunit.cache/`, build steps drop artifacts, etc., into the vendor tree — if those aren't gitignored *in the package repo*, every test run leaves the tree dirty and the next consumer `composer update` quietly no-ops the hook.

**How to apply:** Keep the package's git ignore list covering all test/build artifacts so running its suite never dirties the tree (PHPUnit 10 uses `.phpunit.cache/`, not the old `.phpunit.result.cache`). When an update seems to do nothing, check `git -C vendor/<vendor>/<package> status` and look for the `VcsDownloader` abort — clean the tree (commit, stash, or `git checkout --`) and re-run. Confirm success by the hook's own console output (`claude-config: normalized …`), not just the `Upgrading … ec54871 => …` lock line.

**Gotcha — an uninstall/prune hook must never mutate a committed, non-gitignored file:** Because these packages live in `require-dev`, a production build (Pantheon's `composer install --no-dev`) *uninstalls* them, firing `PRE_PACKAGE_UNINSTALL` / `POST_PACKAGE_UNINSTALL`. If that hook rewrites or deletes a tracked file, Pantheon's build verification aborts with `The build step affected files that are not ignored by git`. claude-config's `wire()`-managed outputs sidestep this two ways: `.claude/CLAUDE.md` and `AGENTS.md` are pure plugin output and get **gitignored** (`ensureGitignore()`), so their prune-on-uninstall leaves no tracked diff; but `.claude/settings.json` can hold the project's *own* hooks/permissions, so it can't be gitignored — its cleanup is instead gated on `PackageEvent::isDevMode()` (skip on a no-dev build, still clean up on a real `composer remove`). Rule of thumb for any new lifecycle hook: either the file it touches is 100% plugin-generated and gitignored, or the mutation is gated on `isDevMode()`. Diagnosis signature: a green `composer install` followed by `git reset --mixed`/`git status --porcelain` showing an unexpected `M <committed file>` in the build log.

**How to apply:** When adding an install/uninstall hook that writes project files, ask whether a `--no-dev` deploy will run it against a committed file. Reproduce locally by calling the mutating static method against `git show HEAD:<file>` and checking the result differs; test the gate by driving the handler with a mocked `PackageEvent` whose `isDevMode()` is false.
