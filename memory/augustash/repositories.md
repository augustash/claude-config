---
name: Augustash repository sources
description: GitHub orgs where augustash internal and custom modules live, and who is behind each handle
type: reference
---

## GitHub organizations

- **github.com/augustash** — Company org. Internal projects, shared infrastructure, company-wide tooling.
- **github.com/jacerider** — Custom modules and contrib work, primarily Drupal, including all the `neo*` modules. Many augustash projects depend on this org.

## Handles are people

These are nicknames, not company names or third parties. Getting this wrong means
misattributing someone's work to an invented maintainer, out loud.

- **jacerider = Cyle.** The `neo*` modules are his, so a `jacerider/*` PR is a PR to Cyle.
- **KazaJhodo = Kaza.**

A personal fork sits between the two: work is committed to `kazajhodo/<module>` and PR'd to
`jacerider/<module>`, so a module's clone typically has `origin` = the fork and `upstream` =
jacerider. Check `git remote -v` before assuming which one a push reaches.

## How to apply

Before building custom functionality, check these orgs for existing modules that solve the problem. Many project-specific needs — especially in Drupal — already have a solution in one of these repos. Search by topic or keyword when a project requirement sounds like something the team may have solved before.
