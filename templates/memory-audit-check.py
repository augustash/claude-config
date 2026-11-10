#!/usr/bin/env python3
"""SessionStart hook: remind to run the shared-memory audit when it's stale.

Reads `last_audit: YYYY-MM-DD` from this package's memory/preferences/memory-audit.md
and, if it's more than AUDIT_MAX_AGE_DAYS old, emits a reminder as SessionStart
additionalContext so Claude proposes running the audit (the "daily floor" the
audit process defines, actually enforced).

Wired as a SessionStart hook pointing at this file in the installed package:
  vendor/augustash/claude-config/templates/memory-audit-check.py
Also checks living documents: any memory whose frontmatter `metadata` carries
`reviewed: YYYY-MM-DD` and `review_every_days: N` is flagged once it's older than N days
(the ADA rule memory, for one, which client records build from).

Silent (no output, exit 0) when fresh, when the date can't be parsed, or on any
error — a hook must never block or noise up session start.
"""

import datetime
import json
import pathlib
import re
import sys

AUDIT_MAX_AGE_DAYS = 1

# memory-audit.md lives at ../memory/preferences/ relative to this templates/ file.
AUDIT_FILE = (
    pathlib.Path(__file__).resolve().parent.parent
    / "memory"
    / "preferences"
    / "memory-audit.md"
)


MEMORY_DIR = AUDIT_FILE.parent.parent


def stale_living_docs() -> list:
    """Memories that declare a review cycle and are past it."""
    out = []
    try:
        files = sorted(MEMORY_DIR.rglob("*.md"))
    except Exception:
        return out
    for f in files:
        try:
            head = f.read_text(encoding="utf-8").split("\n---", 1)[0]
        except Exception:
            continue
        r = re.search(r"\breviewed:\s*(\d{4}-\d{2}-\d{2})", head)
        n = re.search(r"\breview_every_days:\s*(\d+)", head)
        if not (r and n):
            continue
        try:
            age = (datetime.date.today() - datetime.date.fromisoformat(r.group(1))).days
        except ValueError:
            continue
        if age > int(n.group(1)):
            out.append(f"{f.relative_to(MEMORY_DIR)} (reviewed {r.group(1)}, every {n.group(1)} days)")
    return out


def main() -> int:
    # Drain stdin (SessionStart passes JSON); we don't need it, but read to be tidy.
    try:
        sys.stdin.read()
    except Exception:
        pass

    try:
        text = AUDIT_FILE.read_text(encoding="utf-8")
    except Exception:
        return 0  # package not where expected / unreadable — stay silent.

    match = re.search(r"last_audit:\s*(\d{4}-\d{2}-\d{2})", text)
    if not match:
        return 0

    try:
        last = datetime.date.fromisoformat(match.group(1))
    except ValueError:
        return 0

    age = (datetime.date.today() - last).days
    living = stale_living_docs()
    if age <= AUDIT_MAX_AGE_DAYS and not living:
        return 0

    parts = []
    if living:
        parts.append(
            "Living documents due for review against their sources: " + "; ".join(living)
            + ". Re-check each one's sources for changes (rulings, amendments), update it, "
            "and bump its `reviewed` date."
        )
    if age > AUDIT_MAX_AGE_DAYS:
        parts.append((
        f"Shared-memory audit is {age} days stale (last_audit: {last.isoformat()}, "
        f"floor is {AUDIT_MAX_AGE_DAYS} day). Per memory-audit.md, run the pre-check "
        "(`git -C vendor/augustash/claude-config log --since=<last_audit>`); if nothing "
        "changed, just bump last_audit to today, else do a review pass. Fold it into "
        "this session's work rather than making it a separate ceremony."
    ))
    reminder = " ".join(parts)

    # SessionStart hooks surface additionalContext to the model.
    print(
        json.dumps(
            {"hookSpecificOutput": {"hookEventName": "SessionStart", "additionalContext": reminder}}
        )
    )
    return 0


if __name__ == "__main__":
    sys.exit(main())
