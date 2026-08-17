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
output contract for the biggest case of this — `<report>.html` plus
`<report>.md`, self-contained, no external assets.

**How to apply:** build the page as a single file with inlined CSS and no CDN
references, so it opens offline. Keep the design work — the artifact-design
guidance on palette, type pairing, both-theme tokens and letting layout do the
spacing is all still worth applying to the HTML; it is only the *publishing
step* that changes. Ask where the file should live if it is not obvious;
a client-facing report usually belongs with the project, not in a scratch dir.

Pair with [[use-design-skill]] when the page has to match an existing look, and
[[reference-scripts-not-embeds]] for the related instinct that generated tooling
lives in a real file rather than pasted into a note.
