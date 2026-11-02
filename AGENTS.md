# Agent notes

Read [docs/development.md](docs/development.md) first: it holds the restart plan, the
rules of work and the current checkpoint. Work only on the current checkpoint.

- UI and art are placeholders until the owner confirms them. Never close a UI or art
  ticket on automated checks alone; the comparison loop only says a screen is ready
  for review.
- Generate positions, scales, button states and timing from SWF data. Do not type in
  coordinates or measure screenshots.
- Port AS3 close to line for line, keep the original class and method names, and
  cite the source method in a comment.
- Before implementing recovered behavior or parity checks, read
  [docs/evidence/README.md](docs/evidence/README.md) and the relevant records. Link
  behavior to its source.
- Use and update [GLOSSARY.md](GLOSSARY.md) for domain terms; it holds definitions only.
- Older decisions, specs, ADRs and verification records are under the `pre-restart`
  tag. Read them there when a task needs history; do not restore them.
- Before export work, read [docs/douyin.md](docs/douyin.md) and verify its platform
  claims against current official documentation.
- Original art, audio and the SWF stay in the ignored local pack; never commit them.

Do not copy files from `C:\Users\Eiji\Github\bomb-it-1`.

## Agent skills

### Issue tracker

For specs and tickets, use GitHub Issues in `Kurak0oo/bomb-it-5`. Read
[tracker conventions](docs/agents/issue-tracker.md) before tracker operations.

### Triage labels

For triage roles and issue labels, use the [label mapping](docs/agents/triage-labels.md).

### Domain docs

This is a single-context project. Before domain exploration, read the
[domain documentation rules](docs/agents/domain.md).
