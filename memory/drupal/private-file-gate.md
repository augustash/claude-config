---
name: Gating a Drupal file takes three things, and file_managed reports success after one
description: a restricted PDF still downloads though file_managed says private:// — the scheme, the referencing entity's publish state and a webserver path rule are three separate gates, and a migration that strips schemes silently opens all three
type: reference
---

Making a file non-public in Drupal is **three** independent gates. Close one and the
DB looks correct while the bytes still serve. Verified the hard way on md, where 82
restricted dealer documents were downloadable by anyone.

| gate | what it stops | what it does NOT stop |
|---|---|---|
| `private://` scheme | the webserver handing the file over directly | anything Drupal chooses to grant |
| referencing entity unpublished / access-controlled | `hook_file_download` granting the download | direct requests to the file's real path |
| webserver rule on the private dir | direct requests to the real path | nothing — it's the last line |

## The scheme alone does nothing if the entity is public

`private://` doesn't deny — it routes the request through `hook_file_download`, and
core's `media_file_download()` (same for `file_file_download()`) **grants** the
download to anyone who can view the referencing entity:

```
anonymous has 'view media' + the media is published
  → /system/files/vendorfiles/thing.pdf → 200
```

So moving bytes to `private://` and stopping there changes nothing for a published
media. Unpublishing it (or giving the bundle real role access) is the second gate.

## The private dir is inside the docroot, and nginx ignores its .htaccess

The conventional path is `sites/default/files/private` — *inside* the webroot. Core
drops an `.htaccess` there, which is an **Apache** rule. nginx never reads it, so on
any nginx stack the raw path serves the file and walks straight past Drupal:

```
/system/files/vendorfiles/thing.pdf          → 403   ← Drupal's answer
/sites/default/files/private/vendorfiles/…   → 200   ← nginx's answer
```

On Pantheon (nginx, [no `.htaccess` support](https://docs.pantheon.io/guides/filesystem))
close it in `pantheon.yml`:

```yaml
protected_web_paths:
  - /sites/default/files/private
```

⚠ **This gate is not locally verifiable on ddev** — `protected_web_paths` is a Pantheon
directive with no ddev equivalent, so the raw path keeps returning 200 locally no matter
what you write. Check it on a real Pantheon environment; it's the one part taken on
documentation rather than observation.

## How a migration opens all three at once

A D7 `private://` file lands **public** whenever the path helper strips the scheme and
the destination re-adds a fixed one. On md, `MdMigrateFile::relativePath()` strips both
`public://` and `private://`, and the migration concats onto a `dest_public: 'public://'`
constant — so every private file was re-homed public, silently and by construction, with
nothing reading the source's restricted flag.

**Check this on any D7→D10/11 migration that had private files.** The tell:

```sql
SELECT SUBSTRING_INDEX(uri,'://',1) AS scheme, COUNT(*) FROM file_managed GROUP BY scheme;
```

Zero `private` rows on a site whose source had them is the bug, not a clean result. And
fixing the data doesn't fix the migration — a re-run re-opens it.

## Verify from outside, anonymously, or you verify nothing

`file_managed` said `private://` for all 82 while two of the three gates were still
open. The DB is not the check:

```
curl -sI <public path>/thing.pdf     → 404   restricted file, old path
curl -sI /system/files/…/thing.pdf   → 403   restricted file, Drupal route
curl -sI <public path>/allowed.pdf   → 200   a file that MUST stay public
```

That third line matters as much as the first two — gating by directory or by a name
pattern happily takes public files with it. Assert something that should still serve.

Reference implementation: md's `scripts/gate-restricted-documents.php` (derives the
restricted set from the legacy DB, refuses to move a file whose media is referenced by
other content, dry-run by default).
