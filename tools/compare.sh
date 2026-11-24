#!/usr/bin/env bash
# Comparison loop entry point (macOS bash 3.2 and Linux): tools/compare.sh <action> [case]
# Actions: record, check, run, all, accept. See tools/compare/compare.py.
# Results to an issue for the owner: python3 tools/compare/post_review.py ISSUE CASE... [--post]
# Shorthand: `tools/compare.sh main-menu` runs `run main-menu`.
set -eu
here="$(cd "$(dirname "$0")" && pwd)"
case "${1:-}" in
	record|check|run|all|accept) exec python3 "$here/compare/compare.py" "$@" ;;
	"") exec python3 "$here/compare/compare.py" --help ;;
	*) exec python3 "$here/compare/compare.py" run "$@" ;;
esac
