# Deliverables are HTML files, not Claude artifacts

When the job is to *generate a document* — a client report, an audit, a findings
page, a punch list, anything meant to be read rather than run — write a
self-contained `.html` file with the Write tool. Do **not** publish it as a
Claude artifact, even though the Artifact tool is available and the content
would render there fine.

**Why:** the deliverable has to be a file the team owns and can hand over —
opened by double-click, zipped for email, dropped in a repo, versioned with the
work that produced it. An artifact is a page hosted on claude.ai behind an
account; it is not the thing that gets sent to a client, and routing a client's
data through an external host to produce it is a step nobody asked for. The
[client-report](../../skills/client-report/SKILL.md) skill already codifies the
output contract for the biggest case of this — one self-contained `<report>.html`
with no external assets. **No markdown twin**: the skill is explicit that a
parallel `<report>.md` is not wanted, because nobody reads it and it is a second
copy to keep in sync. (Markdown is still right for the internal
`technical-appendix.md`, which is a different document, not a copy of the same one.)

**Not in the site repo either.** Kaza's rule, on atr 2026-08-26: *"I don't want
these committed or stored in the site."* A report written during a maintenance
round went to `private/reports/` on the reasoning below — and on a
Pantheon/WP-Engine project every tracked file *is* the deploy artifact, so a
client document in the repo ships to production and lives in its history. It
also isn't site code; it doesn't want reverting, reviewing or versioning with
the release. Hand it over instead — `~/Desktop/` unless somewhere else is
agreed — and if it did land in a commit, amend it out rather than adding a
deletion commit on top.

**How to apply:** build the page as a single file with inlined CSS and no CDN
references, so it opens offline. Keep the design work — the artifact-design
guidance on palette, type pairing, both-theme tokens and letting layout do the
spacing is all still worth applying to the HTML; it is only the *publishing
step* that changes. Then ask where it should go, and default to handing over the
file rather than filing it anywhere.

Pair with [[use-design-skill]] when the page has to match an existing look, and
[[reference-scripts-not-embeds]] for the related instinct that generated tooling
lives in a real file rather than pasted into a note.
