#!/usr/bin/env python3
"""SessionStart hook: remind to run the shared-memory audit when it's stale.

Reads `last_audit: YYYY-MM-DD` from this package's memory/preferences/memory-audit.md
and, if it's more than AUDIT_MAX_AGE_DAYS old, emits a reminder as SessionStart
additionalContext so Claude proposes running the audit (the "daily floor" the
audit process defines, actually enforced).

Wired as a SessionStart hook pointing at this file in the installed package:
  vendor/augustash/claude-config/templates/memory-audit-check.py
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
    if age <= AUDIT_MAX_AGE_DAYS:
        return 0

    reminder = (
        f"Shared-memory audit is {age} days stale (last_audit: {last.isoformat()}, "
        f"floor is {AUDIT_MAX_AGE_DAYS} day). Per memory-audit.md, run the pre-check "
        "(`git -C vendor/augustash/claude-config log --since=<last_audit>`); if nothing "
        "changed, just bump last_audit to today, else do a review pass. Fold it into "
        "this session's work rather than making it a separate ceremony."
    )

    # SessionStart hooks surface additionalContext to the model.
    print(
        json.dumps(
            {"hookSpecificOutput": {"hookEventName": "SessionStart", "additionalContext": reminder}}
        )
    )
    return 0


if __name__ == "__main__":
    sys.exit(main())
