# Issue tracker: GitHub

Issues and specs live in GitHub Issues for `Kurak0oo/bomb-it-5`.
Use the `gh` CLI with `--repo Kurak0oo/bomb-it-5`.

## Operations

- Publish a spec or ticket with `gh issue create`.
- Read a ticket with `gh issue view <number> --comments`; fetch its labels too.
- List issues with `gh issue list`, using state and label filters.
- Comment with `gh issue comment`; change labels with `gh issue edit`.
- Close completed issues with `gh issue close`.
- For multiline bodies or comments, write the exact text to a temporary file and use `--body-file`.
- Resolve triage roles through [the label mapping](triage-labels.md).

## Relationships

Use native GitHub sub-issues for parent/child relationships and native issue
dependencies for blockers. Dependency API requests use the blocker's numeric
database ID, not its issue number or node ID.

If a relationship API is unavailable, record children in the parent's task list,
put `Part of #<parent>` in each child, and use `Blocked by: #<number>` lines.
A ticket is unblocked only when every blocker is closed.

## Pull requests as a triage surface

**PRs as a request surface: no.**

## Wayfinding

A wayfinding map is one issue labelled `wayfinder:map`; child tickets use
`wayfinder:research`, `wayfinder:prototype`, `wayfinder:grilling` or
`wayfinder:task`. Choose the first open, unassigned child in map order with
no open blockers. Claim it by assigning the driving developer. On resolution,
record the answer, close the child and add a linked decision summary to the map.
