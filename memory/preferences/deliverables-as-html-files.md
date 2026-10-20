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

**Design explorations too.** A UI concept or mockup ("take a crack at the design first")
is the same: a local HTML prototype, not the claude.ai Design canvas or any other
artifact type, even when a tool offers one or the request says "Claude design". Kaza,
on sisal 2026-10-07: *"we don't publish things to the claude.ai cloud, we work locally."*
Make it a working, responsive prototype he can resize and click, opened in his
browser (Firefox Developer Edition).

**POM maintenance records are the exception: they're committed** to
`.claude/docs/pom/` in the project (Kaza, cal 2026-10-19), so the record, the client's
approved copy and the round's notes travel together. See client-report §6, including the
WordPress check that `.claude/` isn't served.

**So are project docs the client answers, the ones that lead into a build** (Kaza, gif
2026-10-20). A scoping or plan doc with decisions for the client to fill in goes in
`.claude/docs/<topic>/` (gif: `.claude/docs/pipedrive/`), committed, with its
`technical-appendix.md` beside it. The copy that goes out is copied to `~/Desktop/` for the dev
to send; the repo copy is the record. When the client sends back the filled-in copy, it **replaces**
the original under the same name and is committed: one copy, holding their answers. The
answered doc plus the appendix is then the brief the build starts from, with nothing to
reconstruct. **Once the work is done, delete the folder** (Kaza, gif 2026-10-20). It was
scaffolding for the build, and the code and git history carry what's left. Everything
below still holds for other deliverables: one-off reports and findings pages.

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
