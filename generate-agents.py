#!/usr/bin/env python3
"""Generate AGENTS.md from CLAUDE.md's memory index.

AGENTS.md is the emerging cross-tool convention (Cursor, Codex, Aider, and
others respect a root AGENTS.md). We ship one inside this composer package;
the Plugin drops a pointer line into each consuming project's AGENTS.md so
non-Claude tools find the shared team context at vendor/augustash/claude-config/AGENTS.md.

Source of truth is CLAUDE.md's "### Current global memories" bullet list.
Edit CLAUDE.md and rerun this script. Consider wiring it into a pre-commit
hook in this repo so the two files never drift.
"""

import re
import sys
from collections import OrderedDict
from pathlib import Path

SCRIPT_DIR = Path(__file__).resolve().parent
CLAUDE_MD = SCRIPT_DIR / "CLAUDE.md"
OUTPUT = SCRIPT_DIR / "AGENTS.md"

# Friendly titles for known topic directories. Unknown topics fall back to a
# title-cased version of the directory name.
TOPIC_TITLES = {
    "preferences": "Preferences & collaboration",
    "drupal": "Drupal",
    "wordpress": "WordPress",
    "augustash": "Augustash internal modules",
}

# Preferences first — they're cross-cutting and set the collaboration tone.
# Everything else follows in insertion order from CLAUDE.md.
TOPIC_ORDER_PRIORITY = ["preferences"]

ENTRY_RE = re.compile(
    r"^- \[(?P<title>[^\]]+)\]\((?P<path>memory/[^)]+)\)\s+—\s+(?P<desc>.+)$"
)


def extract_entries(text):
    """Yield (title, path, description) from the memory index section."""
    in_section = False
    for line in text.splitlines():
        if line.startswith("### Current global memories"):
            in_section = True
            continue
        if in_section and line.startswith("### "):
            break
        if in_section:
            m = ENTRY_RE.match(line)
            if m:
                yield m.group("title"), m.group("path"), m.group("desc").strip()


def group_by_topic(entries):
    groups = OrderedDict()
    for title, path, desc in entries:
        # memory/<topic>/<file>.md — topic is the first segment after "memory/"
        parts = path.split("/")
        if len(parts) < 3:
            continue
        topic = parts[1]
        groups.setdefault(topic, []).append((title, path, desc))
    return groups


def topic_title(topic):
    return TOPIC_TITLES.get(topic, topic.replace("-", " ").replace("_", " ").title())


def order_topics(groups):
    seen = set()
    ordered = []
    for t in TOPIC_ORDER_PRIORITY:
        if t in groups:
            ordered.append((t, groups[t]))
            seen.add(t)
    for t, items in groups.items():
        if t not in seen:
            ordered.append((t, items))
    return ordered


def render(groups):
    lines = []
    lines.append("# August Ash — team conventions for AI assistants")
    lines.append("")
    lines.append(
        "Shared context for AI coding assistants (Cursor, Codex, Aider, Claude "
        "Code, and any tool that reads `AGENTS.md`) working on augustash "
        "projects. When a task touches one of the topics below, read the "
        "referenced file before proceeding — the team has accumulated "
        "conventions and hard-won lessons there that generic defaults won't "
        "match."
    )
    lines.append("")
    lines.append(
        "These files are authoritative and kept current by the team. Prefer "
        "conventions here over generic defaults. When you learn something "
        "worth sharing, update or add a file in the `augustash/claude-config` "
        "repo's `memory/` directory and commit it — everyone on the team "
        "benefits on their next `composer update`."
    )
    lines.append("")
    lines.append(
        "> *Generated from `CLAUDE.md`. Don't edit this file directly — edit "
        "`CLAUDE.md` and rerun `generate-agents.py`.*"
    )
    lines.append("")

    for topic, items in order_topics(groups):
        lines.append(f"## {topic_title(topic)}")
        lines.append("")
        for title, path, desc in items:
            lines.append(f"- **{title}** — `vendor/augustash/claude-config/{path}`  ")
            lines.append(f"  {desc}")
        lines.append("")

    return "\n".join(lines).rstrip() + "\n"


def main():
    if not CLAUDE_MD.exists():
        print(f"Error: {CLAUDE_MD} not found.", file=sys.stderr)
        return 1

    text = CLAUDE_MD.read_text()
    entries = list(extract_entries(text))
    if not entries:
        print(
            f"Error: no memory entries under '### Current global memories' in "
            f"{CLAUDE_MD}.",
            file=sys.stderr,
        )
        return 1

    groups = group_by_topic(entries)
    new_content = render(groups)

    # Skip the write if nothing changed — keeps mtime stable so setup.sh /
    # launchd don't thrash downstream consumers.
    if OUTPUT.exists() and OUTPUT.read_text() == new_content:
        print(f"AGENTS.md already up to date ({len(entries)} entries).")
        return 0

    OUTPUT.write_text(new_content)
    print(f"Wrote {OUTPUT} ({len(entries)} entries across {len(groups)} topics).")
    return 0


if __name__ == "__main__":
    sys.exit(main())
