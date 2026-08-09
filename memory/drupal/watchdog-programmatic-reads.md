---
name: watchdog-programmatic-reads
description: Reading watchdog from drush for analysis — the message arrives truncated by default, and D7's CSV has no header row, which silently fabricates findings rather than erroring
type: project
---

**`drush watchdog:show` truncates the message, and Drupal 7's CSV output has no header row.
Both fail silently and produce confident, wrong output rather than an error.**

## Truncation

Without `--extended`, drush cuts the message at roughly 188 characters. That is comfortably
enough to look correct in a terminal and to lose the part that carries meaning — the error
code, the file path, the stack frame. Any pattern matching on the tail of a message will
simply never fire, and nothing anywhere reports that a string was shortened.

```
drush watchdog:show --count=200 --format=csv --extended
```

`--format=json` is silently ignored by `watchdog:show` and returns nothing; `csv` is the
format that actually carries the `Location` and `Hostname` columns.

## The D7 header trap

Modern Drupal emits a header row (`type,severity,message,date,…`). **Drupal 7 does not** — it
emits bare positional rows: `Wid, Date, Type, Severity, Message`.

Parsing D7 as though the first row were a header consumes a real log entry as column names
and then misaligns every field. `Type` becomes `undefined`, severity becomes garbage, and the
message column holds a date. The parse *succeeds*; it just describes something that never
happened. On a fleet sweep this produced roughly thirty confident act-now findings out of
column misalignment.

Detect the format rather than assuming it:

```js
const looksLikeHeader = first.some((h) =>
  /^(type|severity|message|date|hostname|location)$/i.test(h));
```

**The tell that something is wrong is uniformity.** Every site reporting *exactly* the same
entry count, or every finding sharing one implausible type like `unknown`, means a parse
failure and not a fleet-wide coincidence. A real log is ragged.

## Age is not in the window

`watchdog:show --count=N` returns the last N entries however old they are. A row from six
weeks ago is byte-identical to one from six minutes ago, so anything that acts on "this is
happening now" has to read and bound the `Date` column itself — an assumption of recency is
wrong on any quiet site, where the last 200 entries can span months.

Related: [[mail-transport-vs-recipient-failure]] for what the untruncated message is needed
for, [[test-tags]] for where the coverage belongs.
