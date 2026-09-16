---
name: status-updates-decision-relevant
description: Deploy/status narration should carry only what the dev must act on — skip side-effect trivia like Slack deploy pings
metadata:
  type: feedback
---

**When narrating deploys or multi-step operations, mention only what the developer must act
on or decide.** Routine side effects of the normal pipeline — the Slack deploy notification,
cache clears, build steps — are noise, and repeating them reads as stalling.

**Why:** Dane (kow, 2026-08-06) on a third mention of the deploy's Slack ping: "why even
mention the slack notification in this context." The first mention (a heads-up that a channel
ping would appear with an unexpected origin) was arguably useful; repeating it on every
subsequent deploy was not.

**How to apply:** Say what changed, where it is now, what's verified, and what needs a
decision. A side effect earns one mention only if the user would otherwise be confused or
needs to act on it — and once acknowledged, never again in the same stream of work.
