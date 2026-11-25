---
name: test-before-live
description: A change reaches live already tested; a snapshot taken before it is a record for reference, never the safety net that makes an untested change acceptable.
metadata:
  type: feedback
---

**What goes live is already tested, or it doesn't go live.** A backup, export or ruleset
snapshot taken beforehand is a *record of what was there*, kept for reference. It is not a
fallback that makes trying something on production acceptable. Kaza rarely rolls back, and
treats "take a backup in case, so we can restore if it goes sideways" (the database-rollback
habit) as unacceptable reasoning.

**Why:** a fallback plan is a way of shipping untested work, and the restore is rarely clean.
Traffic, orders and edits made in between are lost or collide. Correctness has to come from
testing, not from being able to undo.

**How to apply:**

- **Test where it can be tested first:** locally, then dev or a multidev, against real data
  shapes. Only then deploy.
- **Describe snapshots as records:** "the rules as they stood before", "reference". Never
  "rollback snapshot" or "fallback", in replies, memory or tool output (`cf-rules.sh` was
  reworded for this on 2026-11-25).
- **When a change genuinely can't be tested before live, say so up front, before applying
  it.** Examples: a Cloudflare custom rule on the Free plan, which has no staging and no
  log-only action, or a matcher only real traffic can exercise. State what was verified, what
  can only be proven live, and why the risk is acceptable. Then verify it live at once. Don't
  lean on "we have a snapshot" as the justification. On atrix (2026-11-25), a rule blocking
  Meta's ASN was applied, its UA clauses and exceptions checked by curl immediately, and the
  ASN clause left to be proven against the next real crawl.

Related: [[confirm-before-live-terminus]], [[local-config-in-settings-local]]
