# Patched firefox-devtools MCP: stable tab handles

Pins `@mozilla/firefox-devtools-mcp` and patches it so Claude can address tabs by
a **stable id** instead of a positional index.

    ./install.sh                  # -> ~/.local/share/firefox-devtools-mcp-patched
    ./install.sh /some/other/dir

## Why

Upstream identifies a tab by its **index** into `getAllWindowHandles()` -- a flat
list of every tab in every window, with no window grouping. Two consequences,
both bad when the dev is using the same browser via `--connectExisting`:

**1. The index is not stable.** Open, close or reorder a tab and every index
after it shifts. Claude's "page 3" silently becomes a different page. The dev
breaks Claude's run just by using their own browser -- without doing anything
wrong.

**2. Every page operation rebuilds the entire tab list.** `refreshTabs()` loops
over every open tab calling `switchTo().window()` + `getCurrentUrl()` +
`getTitle()` -- 3 Marionette round-trips per tab -- and `select_page`,
`navigate_page`, `close_page` and `list_pages` all call it unconditionally.
With 15 tabs open that is ~45 round-trips to perform one click. It is also the
cause of the **visible strobing**: each switch focuses that tab and raises its
window, so the dev watches Firefox walk every tab they have open.

Addressing by index is not even a speed win over URL matching -- both pay the
same full walk, because the walk is what builds the index in the first place.

The fix is already sitting in the code: `refreshTabs()` stores each tab's
Marionette window handle as `actor`, and `selectTab()` ends at a single
`switchTo().window(handle)`. Handles are stable for the tab's lifetime -- they
survive reordering, other tabs closing, and moving a tab between windows. The
handle was simply never exposed through the tool schema.

**Result: 3n round-trips collapse to 1, no strobing, and no cross-talk with the
dev's own tab usage.**

## What the patch changes

All edits are in `dist/index.js` (the shipped bundle is readable, not minified).

| Site | Change |
|------|--------|
| tabs class, after `selectTab()` | Adds `selectTabByHandle(handle)` -- one `switchTo().window()`, no walk. Stale handle raises a clear "call list_pages" error. |
| wrapper class, after `getTabs()` | Delegates `selectTabByHandle()`. |
| `formatPageList()` | Emits `[idx\|pageId]` so the handle is discoverable. |
| `selectPageTool` schema | Accepts `pageId`. |
| `handleSelectPage` | `pageId` fast path, before `refreshTabs()`. |
| `handleNewPage` | Returns `[idx\|pageId]`, so a tab Claude opens never needs a lookup. |
| `navigatePageTool` schema | Accepts `pageId`. |
| `handleNavigatePage` | Optional `pageId` target; drops a `refreshTabs()` that only fed a null check -- `navigate()` acts on the current context anyway. Pure dead weight. |

`pageId` is always optional. Index, URL and title addressing still work exactly
as before, so the patch is additive and nothing regresses if it is dropped.

## Maintaining across upgrades

The patch is managed by `patch-package` and applied by the `postinstall` hook,
so it re-applies automatically on `npm install`.

**Upstream is 0.10.2 as of 2026-09-17 -- this is the latest published version,
and it does not expose handles.** Check whether it still needs carrying:

    npm view @mozilla/firefox-devtools-mcp version

To move to a newer upstream:

1. Bump the version in `package.json`, `npm install`.
2. `patch-package` will say if a hunk no longer applies. If it applies cleanly,
   re-cut for the new version and delete the old patch file:

       npx patch-package @mozilla/firefox-devtools-mcp

3. If it conflicts, re-apply the table above by hand against the new bundle,
   then re-cut. The anchors are small and the surrounding code is stable.
4. Verify: `node --check node_modules/@mozilla/firefox-devtools-mcp/dist/index.js`
   then boot the server and confirm `select_page` lists `pageId` in its schema.

**If upstream ever exposes handles itself, drop this entire directory** and go
back to plain `npx @mozilla/firefox-devtools-mcp@latest`. Worth filing upstream
so that happens -- the handle is already cached, so it is a small change for
them and removes this maintenance burden.

## Gotcha when re-cutting by hand

The bundle writes the arrow in response strings as a literal six-character
`→` escape, not a `->` character. Some heredocs will silently convert it
when you paste an anchor through a shell, and the match then fails. Keep the
arrow out of match anchors entirely.
