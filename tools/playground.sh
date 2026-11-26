#!/usr/bin/env bash
# Dev-only compare playground (tools/playground/playground.gd): load a compare case, pause at a
# capture, step and play the real game frame by frame.
#
#   tools/playground.sh [--case NAME] [--capture NAME]
set -euo pipefail
root="$(cd "$(dirname "$0")/.." && pwd)"
exec "${GODOT:-godot}" --path "$root" res://tools/playground/playground.tscn -- "$@"
