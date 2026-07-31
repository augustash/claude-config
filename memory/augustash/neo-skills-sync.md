---
name: Sync neo module skills with drush neo:build:install
description: "Jacerider/Neo modules ship Claude skills inside the module; the project's live copies in .claude/skills/ are what Claude loads, and composer update does not touch them. `drush neo:build:install` re-copies them from every enabled module — but it also rewrites package.json, tsconfig.json and vite.config.ts and edits .ddev/config.yaml, so check git status after."
type: reference
---

# Neo module skills — sync with `drush neo:build:install`

Jacerider/Neo modules ship Claude skills inside the module at
`web/modules/contrib/<module>/install/skills/<skill-name>/`. The project's *live* copies —
what Claude actually loads — are in the repo at `.claude/skills/<skill-name>/`.

**`composer update` refreshes the module's `install/skills/` source but does not touch
`.claude/skills/`.** So a plain module bump silently leaves the project running the *old*
skill text. That part has always been true.

## The command

```bash
ddev drush neo:build:install     # alias: neo-install
```

It aggregates `install/skills/` from **every enabled module**, keyed by relative path to
dedupe, and copies each file into `.claude/skills/` with `FileExists::Replace`. Because it
walks the whole module list rather than a hard-coded set, it also catches modules that start
shipping skills later — which a hand-written `cp` loop does not.

⚠ **It is not a skills-only command.** The same method regenerates `package.json`,
`tsconfig.json` and `vite.config.ts` from templates (`FileExists::Replace`, with `[ROOT]` /
`[DOC-ROOT]` / `[MODULE-DIR]` token substitution) and appends the Vite entry to
`web_extra_exposed_ports` in `.ddev/config.yaml`. On a settled project those regenerate
byte-identical, but **check `git status` on those four paths after running it** rather than
assuming. Diff the skills first if you want to know what the update actually moved:

```bash
diff -rq web/modules/contrib/<module>/install/skills/<name> .claude/skills/<name>
```

**Rule: run it whenever you `composer update` a neo module, and commit the refreshed skills
alongside the module bump.**

## Correction

This memory previously said there was **no** mechanism and to `cp -R` by hand, attributed to
Cyle. That is wrong — Kaza recalled a drush command existing, and it does
(`neo_build/src/Commands/DrushCommands.php::neoBuildInstall()`). The manual copy still
produces an identical result, so the old advice was not harmful, just more work and blind to
modules outside the hard-coded list. Verified on md 2026-07-31 against neo_build 1.0.58 /
neo_alchemist 1.0.114: the command and a manual `cp -R` produced byte-identical
`.claude/skills/`, and the four non-skill files regenerated with no churn.

Generalizes beyond neo: any composer module carrying an `install/skills/` dir has the same
gap. Project-authored skills (no module source) are left alone by the command.
