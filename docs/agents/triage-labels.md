# Triage labels

| Canonical role | Tracker label | Meaning |
| --- | --- | --- |
| needs-triage | needs-triage | Maintainer evaluation needed |
| needs-info | needs-info | More information needed |
| ready-for-agent | ready-for-agent | Fully specified for agent implementation |
| ready-for-human | ready-for-human | Human implementation required |
| wontfix | wontfix | Will not be actioned |
| ui-art | ui-art | UI or art work: only the owner closes it (`.github/workflows/owner-gate.yml` reopens it otherwise) |
| ready-for-owner-review | ready-for-owner-review | Passes the comparison loop; waiting for the owner to look (`tools/compare/post_review.py`) |

Skills use this mapping whenever they refer to a triage role.
