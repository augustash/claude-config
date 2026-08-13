---
name: caveats-with-delivery
description: before calling work "done" or deploying — say what's verified vs assumed up front, never surface caveats after the fact
metadata:
  type: feedback
---

Don't announce work as "good"/"done" and deploy it, then reveal known caveats or other
issues afterward. What's verified vs assumed, the limitations, the parts that could still be
wrong — those belong **with** the delivery, up front, not surfaced later (and never only
after the developer catches it).

**Why:** a "done" that gets walked back erodes trust more than the caveat ever would. On
V.I.N.CENT (Dane, Aug 2026) this bit hard — a detector was handed over as "built, reviewed,
deployed, verified — 7 findings, no spam," and only when Dane questioned one finding did its
wording turn out to be inaccurate. The caveat was knowable at delivery time; stating it then
is honesty, stating it after reads as spin. Dane's framing: mistakes are fine (dev, not live)
— "just show me them, be honest, and we're good."

**How to apply:** when handing off or deploying, lead with what's proven vs assumed, name the
known limitations and anything not yet verified, and don't call something "good" while sitting
on a known unknown. Show mistakes plainly rather than smoothing them over. Distinct from
[[status-updates-decision-relevant]] (that's not narrating pipeline side effects; this is not
overselling "done").
