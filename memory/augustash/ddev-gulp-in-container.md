---
name: ddev gulp's ddev/ddevWatch tasks die on an opaque JSON error
description: `ddev gulp ddevWatch` fails with "Unexpected token 'Y'... is not valid JSON" and nothing names ddev as the cause; use the plain watch task
type: project
---

Ash/aeon-derived theme gulpfiles (present in a dozen-plus projects — `web/themes/*/gulpfile.js`,
grep for `enableDdev`) ship four tasks: `default`, `watch`, `ddev`, `ddevWatch`. The two `ddev`
ones fail the moment they start, with an error that names JSON and never mentions ddev:

```
SyntaxError: Unexpected token 'Y', "You execut"... is not valid JSON
    at enableDdev (.../gulpfile.js:115:27)
```

`enableDdev` does `JSON.parse(execSync('ddev describe -j'))` to discover the site URL for
Browsersync. Run through `ddev gulp` (or any `ddev exec`), that command executes **inside the
web container**, where ddev replies:

> You executed 'ddev describe -j' inside the web container / but many DDEV commands are not
> available.

Plain text, so `JSON.parse` throws on the leading `Y`. Nothing is broken — the task just
cannot work from where it's being run.

**Use `ddev gulp watch` (or `ddev gulp` for a one-shot build).** Compilation is identical; the
only loss is Browsersync's proxy target, and ddev doesn't publish container port 3000 to the
host anyway, so the auto-reload URL was not reachable from the browser regardless. Compile,
then hard-refresh.

The project provides `.ddev/commands/web/gulp`, so `ddev gulp <task>` is the intended entry
point — the trap is only in *which* task you pick.
