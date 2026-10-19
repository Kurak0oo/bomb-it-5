# Agent notes

Read [DESIGN.md](DESIGN.md) before editing for the accepted specification, then [docs/development.md](docs/development.md) for the current work boundary and prerequisites. The two initial interview questions are settled; do not ask them again.

- When interviewing, work the decision frontier in development.md: ask independent, ready decisions together, recommend an answer, and wait before resolving dependent choices. Look up facts rather than asking the user to supply facts available in the repo.
- When a decision is accepted, update DESIGN.md and its frontier entry together. Keep unanswered recommendations out of the accepted specification. Record consequential rationale in `docs/adr/`; update the current spec when an ADR is superseded.
- When defining domain language, read and update [GLOSSARY.md](GLOSSARY.md). It contains definitions, not implementation rules.
- Before implementing recovered behavior or parity checks, read [docs/evidence/README.md](docs/evidence/README.md) and the relevant records. Link behavior to its source; an accepted design choice is not SWF evidence.
- Before export work, read [docs/douyin.md](docs/douyin.md) and verify its inherited platform claims against current official documentation.

Leave `scenes/main.tscn` empty of gameplay during command-boundary work. Do not copy files from `C:\Users\Eiji\Github\bomb-it-1`.
