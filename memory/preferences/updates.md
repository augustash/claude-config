---
name: Post-update test notice
description: When setting up tests in a project, wire a composer post-update-cmd notice that lists exactly the test commands that project has installed
type: feedback
---

When a project has test suites installed (PHPUnit, Nightwatch, Unit, Functional, etc.), wire a `post-update-cmd` in the project's `composer.json` that prints a reminder + the exact commands to run. Every `composer update` (Claude, direct, or CI) then ends with a visible nudge to run tests before committing.

**Why:** Updates are the most common source of silent regressions — a minor version bump or `hook_update_N` can shift behavior in ways only tests catch. Relying on Claude's memory to remind only covers updates run through Claude; a composer hook covers everyone. By the time the notice exists in `composer.json`, tests are known to exist — no runtime detection needed. The notice's existence *is* the signal.

**How to apply:**

- **When setting up the first test suite in a project,** also add the post-update notice. When adding additional test types later (e.g., Nightwatch after PHPUnit), add a line for the new type. When removing a test type, remove its line.
- **The notice must be specific to what's installed** — don't hardcode a generic `phpunit` command in projects that don't have it. Every line in the notice must correspond to a real, runnable suite in that project.
- **Notice-only, never auto-run.** Forcing tests on every `composer update` wears out its welcome fast and devs will comment it out. A loud, helpful, copy-pasteable reminder wins in practice.

**Pattern (Drupal/ddev, adapt paths for the project):**

```json
"scripts": {
    "post-update-cmd": [
        "@post-update-notice"
    ],
    "post-update-notice": [
        "echo ''",
        "echo '\\033[33m▸ Updates complete, tests exist that should be ran:\\033[0m'",
        "echo '  PHPUnit:    ddev exec \"cd web && ../vendor/bin/phpunit -c core modules/custom\"'",
        "echo '  Nightwatch: ddev exec \"cd web/core && yarn test:nightwatch /var/www/html/web/modules/custom/\"'",
        "echo ''"
    ]
}
```

Drop any line whose suite isn't installed. Add a new line when a new suite is. The whole point is that the notice stays truthful — a reminder pointing at a broken command is worse than no reminder.

**Claude's role after updates:** When you run `composer update` (or trigger one) and the notice fires, surface it to the user and offer to run the listed commands. If a project has test suites but no post-update notice, suggest adding one using the pattern above.
