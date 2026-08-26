---
name: ddev exec expands your variables before bash sees them
description: `ddev exec bash -c '...'` dies with "X: unbound variable" on a variable you set one line earlier — ddev re-quotes the command in double quotes, so the outer container shell expands it first
metadata:
  type: reference
---

Any `ddev exec bash -c '...'` that sets a variable and uses it fails:

```bash
ddev exec bash -c 'X=hello; echo "got:$X"'
# bash: line 1: X: unbound variable
```

The script is correct. **ddev rebuilds the command line with double quotes** before handing it
to the container — the error output shows what it actually ran:

```
Failed to execute command `bash -c "X=hello; echo \"got:$X\""`
```

So `$X` is expanded by the *outer* container shell, which runs with `set -u` (`echo $-` there
prints `ehuBc`), and that shell has never heard of `X`. Your `bash -c` is never reached.

Single-quoting the inner string doesn't help — ddev's re-quote happens after, so
`echo got:$X` fails identically. The quoting you wrote is not the quoting that runs.

## What works

**Escape the dollar signs.** Simplest, and needs no file:

```bash
ddev exec bash -c 'X=hello; echo "got:\$X"'   # got:hello
```

**Or put the script in a file** under the project (mounted at `/var/www/html`) and run that —
the right call once there's nested quoting, a heredoc, or an inline Python block, where
escaping stops being winnable:

```bash
cat > build.sh <<'SH'
SRC=/tmp/thing
cp -r "$SRC" /tmp/copy
SH
ddev mutagen sync            # see below — do not skip
ddev exec bash /var/www/html/build.sh
```

**That `mutagen sync` is load-bearing.** A file you just wrote on the host may not exist in the
container yet, and the failure is `bash: /var/www/html/build.sh: No such file or directory`
(exit 127) — which reads as a wrong path, not a race. It is the host→container half of
[[ddev-mutagen-sync-lag]], and it is intermittent: the same command fails, then succeeds
seconds later untouched.
