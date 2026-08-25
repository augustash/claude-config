---
name: commit-handoff
description: Claude commits shared claude-config memory, module-clone work, and project-level work. Pushing project code stays with the developer. Commit granularity — one idea per commit — matters more than who types it.
metadata:
  type: feedback
---

Committing is Claude's to do. What differs by zone is **pushing**:

- **Shared memory (`vendor/augustash/claude-config/`):** Claude commits *and pushes*. This is
  package distribution — leaving local-only edits would defeat the purpose since other
  projects depend on the published package.
- **Project repo:** Claude commits. **The developer pushes.** On Pantheon-style projects a push
  to the tracked branch is a deploy, so that stays an explicit human action — ask, don't
  assume, even right after a batch of approved commits.
- **Module clones (`~/Projects/<module>/`):** Claude commits and pushes; the developer opens the
  PR. See [[module-fixes-on-develop]] — that memory owns the branching rule and the "match the
  upstream author's conventions" half.

**Why:** the review the old hand-off rule protected turned out to be better served by tight,
well-scoped commits than by a gate on who runs `git commit`. A dev can read five commits that
each do one thing far faster than one diff they have to take apart.

## Granularity is the actual rule

**One commit is one idea — the unit you would want to revert as a whole.** Don't split one idea
across several commits, and don't combine unrelated ones. Keep the message concise: subject plus
a tight *why*; the diagnosis belongs in the PR, not the commit (see [[commit-messages]]).

This is where it goes wrong in practice, in both directions. On ar-md (2026-08-02) a single
long delegated stretch produced **31 commits for one feature**, several of them a single CSS
value — which fails the revert test exactly as badly as one giant commit does. Being handed the
commits is not licence to commit at every keystroke; commit at the granularity the dev would
have chosen.

## Prose deliverables get one commit, not a commit per revision

A written deliverable under active revision — a client report, an audit record, a findings
page — is **one commit for the whole revision pass**, landed when the editing settles. Do not
commit each wording change as you make it, even though each one is individually sound and the
file is valid after every edit.

The reason is the reader, not the rule: nobody benefits from seeing a sentence reworded three
times, a claim softened, and a contradiction reconciled as separate history. Those are drafting
moves, not decisions anyone would revert. On sisal (2026-08-24), an accessibility record sent in
response to an ADA demand took roughly a dozen edits in one sitting — restating the client's
request, correcting a statement the deploy had falsified, reconciling two paragraphs that
disagreed. One commit; the intermediate states are noise.

This is the same single-idea test, applied to a document: the idea is *this revision of the doc*,
not each sentence in it. Code differs because a code change usually is a discrete decision.

**How to apply:** when a document is going to be edited repeatedly, say up front that commits are
being held, keep the file in a valid committable state throughout so the dev can call time
whenever they like, and land it once. Ask before splitting into more than one.

## How to apply

Finish the work, leave a clean state (files saved, lint/tests passing), then commit it in
idea-sized pieces. Say what landed and what is still uncommitted. For project repos, stop at the
commit and let the dev push. Run `cex` first when a Drupal project's config may have drifted
(see [[cex-before-commit]]).
