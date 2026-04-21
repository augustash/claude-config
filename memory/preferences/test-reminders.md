---
name: Remind devs about tests when work overlaps
description: When modifying code that has existing test coverage, surface those tests and suggest updating them; when adding new behavior, suggest tests for it
type: feedback
---

When work is touching an area with existing test coverage, surface that fact *before wrapping up* — don't let the dev finish and commit without at least hearing that tests exist and may need updates. When adding new functionality of any real substance, suggest adding test coverage for it too.

**Why:** Tests silently rotting is a common way quality slips. It's easy to ship a behavior change and forget that existing tests now assert the wrong thing, or to add new functionality without any coverage. Claude's job is to surface these moments before they're forgotten — not to block the work, just to make the gap visible so the dev can decide.

**How to apply:**

- **When reading or modifying a file,** check whether a corresponding test exists. For Drupal modules that typically means `tests/src/Kernel/`, `tests/src/Unit/`, `tests/src/Functional/` under the same module. For project-specific testing conventions, check `.claude/memory/testing/` in the project repo — if a memory file exists there, it tells you where the tests for that domain live and what they cover.
- **If tests exist that cover the modified behavior:** mention them by name/path once the work is substantially done (or before commit). Offer concretely: "the existing `FooTest::testBar()` case is no longer accurate given this change — worth updating alongside?" Don't ask; propose the concrete edit.
- **If new functionality is added that isn't exercised by any test:** name it and ask whether to add coverage. Don't silently leave a gap.
- **If modifying behavior in code that has no test coverage at all:** flag the gap once, when the change is substantial (not for typo fixes, formatting, or trivial refactors). "This module has no tests — worth adding coverage around this behavior before we modify it further?" Mention it once per session per area; don't re-raise it on every subsequent edit.
- **Don't be preachy.** One sentence at the right moment, not a lecture. If the user has already said "no tests this round," drop it.
- **Project-level memory wins.** If `.claude/memory/testing/{domain}.md` exists, read it before commenting — it may already spell out what's covered and what the test conventions are for that project.
