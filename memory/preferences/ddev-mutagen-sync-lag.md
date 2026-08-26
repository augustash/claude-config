---
name: ddev Mutagen sync lag makes container writes look like failures
description: Files written INSIDE the ddev container (drush cex, composer, generators) reach the host a few seconds later under Mutagen — reading them back immediately shows stale content and reads as "the command didn't work"
type: reference
---

On macOS, ddev runs with **Mutagen** (`ddev describe` → `Perf mode: mutagen`). It syncs host ↔ container two ways, but not instantly. Anything a command writes **inside** the container lands on the host filesystem a few seconds later.

## The failure mode

Run a command that writes files in the container, then read them back from the host in the same breath, and you get the **pre-command content**:

```bash
ddev drush cex -y                      # writes /var/www/html/config in the container
grep 'admin:' config/system.theme.yml  # host read — still shows the OLD value
```

The command succeeded. The file is correct in the container. The host just hasn't caught up.

**Why this is worse than a plain race:** the stale read is a plausible wrong answer, not an obvious error. It invites diagnosing a filtering problem that doesn't exist — on a Drupal site the natural suspects are `config_ignore`, `config_split` or `config_readonly`, and you can burn real time confirming they're innocent. Same shape for `composer` writes and any code generator.

## Verifying properly

- Read through the container, which is authoritative: `ddev exec cat config/system.theme.yml`
- Or force the sync and then read: `ddev mutagen sync`
- Or just look again a moment later — a subsequent tool call is usually enough, which is why `git status` often shows the truth when a `grep` seconds earlier did not

For config specifically, `ddev drush config:status` reports DB-vs-sync state from *inside* the container, so it is immune to this and worth preferring over eyeballing exported files.

## It lags host → container too

The same delay runs the other way, and there the symptom is not a stale read but a **missing
file**. Write a script on the host, run it immediately in the container, and you get
`bash: /var/www/html/build.sh: No such file or directory` (exit 127) — which reads as a wrong
path rather than a race, and it passes on the retry. `ddev mutagen sync` before the `ddev exec`.
See [[ddev-exec-var-expansion]], where this bites hardest.

## Don't conclude from one read

Before deciding a container-side write failed, re-read once through `ddev exec`. If both agree, it really failed.
