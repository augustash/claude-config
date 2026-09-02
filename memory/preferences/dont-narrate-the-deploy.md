---
name: dont-narrate-the-deploy
description: After handing commits over, don't walk the dev through post-push deploy steps — their deployment script already runs updb/cim/cr across environments. Report the payload the deploy has to carry, not the procedure.
metadata:
  type: feedback
---

Once the commits are handed over ([[commit-handoff]]), the deploy is **not** a subject to
explain. Kaza's deployment script already runs the post-deploy Drupal work — `updb`, `cim`,
`cr` — across each environment; spelling out a `terminus drush <site>.<env> -- deploy`
sequence tells a senior Drupal architect something he has run hundreds of times.

This has been corrected more than once, which is what puts it here: *"Yeah, I know how to do a
deploy."* / *"We've talked about this a bunch, my deployment script does it all."*

**Why:** it isn't only redundant, it inverts the value of the report. The dev cannot see what
a round left pending without asking; he can see how to deploy without being told. Spending the
last paragraph on the procedure crowds out the one thing only Claude currently knows.

## What *is* worth saying

The **payload** — what the deploy has to carry, in numbers he can sanity-check against his own
run:

> 22 update hooks and 40 config items. The `webform_submission_data` index rebuild is the only
> one that touches a production-sized table.

And anything the platform is doing that a local `git push` doesn't reveal — the Pantheon build
still running behind the code log is the standing example
([[pantheon-build-lag]]). That check was welcome in the same breath the deploy steps were not,
which is the distinction: **platform state he can't see, yes; procedure he owns, no.**

Same rule for `.test`/`.live`: [[confirm-before-live-terminus]] governs Claude *running*
anything there. It is not a licence to narrate what the dev should run instead.

**How to apply:** end an update round with what moved, what was held, what was verified, and
what the deploy still has to apply. Then stop. If a step genuinely is unusual — a manual
one-off the script won't cover — name that single step and say why it's an exception, rather
than restating the whole sequence around it.
