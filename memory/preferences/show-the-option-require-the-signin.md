---
name: Show the option and require the sign-in, don't hide it
description: An affordance hidden because the visitor hasn't met a precondition they could satisfy in two taps reads as a broken interface, not a clean one — show it and let them satisfy the precondition.
metadata:
  type: feedback
---

# Show the option and require the sign-in, don't hide it

When a feature is available only to visitors in some state — signed in to a
wallet, holding an account, having a saved address — **show the control and let
them get into that state**. Do not hide it until they happen to already qualify.

Kaza's words, on Apple Pay in Stripe's Express Checkout element
(sisal, 2026-09-09):

> It's much better to always display it, and require login, then not provide the
> option at all unless they happen to be logged in. In fact, I think not
> displaying is closer to a ui error than good ui.

**Why:** a missing control is indistinguishable from a broken one. Someone who
uses Apple Pay everywhere else and doesn't see it here concludes the site
doesn't take it — they don't conclude they're signed out. The hidden-until-
qualified version optimises the tap count for people already in the right state
and gives everyone else nothing at all, which is the wrong trade: the extra
sign-in step is a cost only for the people who would otherwise have had no
option.

The counter-argument to weigh, not to be talked out of: showing it means some
people tap expecting one-tap payment and get a sign-in flow. That is a worse
*moment* but a better *outcome*, and it is recoverable — an absent button is not.

**How to apply:** where a vendor SDK offers a visibility mode, prefer the one
that always renders. In Stripe's Express Checkout element that is
`paymentMethods.applePay = 'always'` rather than the default `'auto'`, which
Stripe honours only on Safari — so on every other desktop browser Apple Pay
silently never appears. Same instinct anywhere a precondition gates a control.

Related: [[fix-what-nobody-sees]] — the same refusal to let something invisible
count as something acceptable.
