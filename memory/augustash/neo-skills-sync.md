# Neo module skills — sync manually on update

Jacerider/Neo modules ship Claude skills inside the module at
`web/modules/contrib/<module>/install/skills/<skill-name>/`. The project's *live*
copies (what Claude actually loads) are in the repo at `.claude/skills/<skill-name>/`.

**There is no automatic mechanism to update project skills** (confirmed by Cyle).
`composer update` refreshes the module's `install/skills/` source, but does **not**
touch `.claude/skills/`. So a plain module bump silently leaves the project running
the *old* skill text.

**Rule: whenever you `composer update` a neo module that ships skills, re-sync its
skills into the project** and commit them alongside the module bump:

```bash
# per updated skill-shipping module:
cp -R web/modules/contrib/<module>/install/skills/. .claude/skills/
```

Diff first to see what actually changed (`diff -rq <module>/install/skills/<name> .claude/skills/<name>`);
`git status .claude/skills/` shows which skills the update moved.

**Neo modules that ship skills** (check each on update — the list grows):
- `neo_alchemist` → `neo-alchemist-dev`, `neo-component`
- `neo_animate` → `neo-animate`
- `neo_build` → `neo-build`
- `neo_color` → `neo-color-dev`
- `neo_font` → `neo-font-dev`

Generalizes beyond neo: any composer module carrying an `install/skills/` dir has
the same gap — sync on update. Project-authored skills (e.g. `dmx-component-design`)
have no module source and are left alone.
