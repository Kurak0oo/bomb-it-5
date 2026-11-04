#!/usr/bin/env bash
# Checkpoint 2 converter, one command on the SWF machine: tools/convert.sh [case]
#   1. record the case's goldens with the reference player (tools/compare.sh record)
#   2. regenerate the screen layouts from the goldens (tools/convert/layout.py)
#   3. render each screen's art pieces into the ignored local pack (render_pieces.py)
#   4. check Godot against the goldens, with pixels (tools/compare.sh check)
# Commit tests/goldens/ and scenes/swf/ afterwards; original/ stays local.
# Needs Python 3.10+ with numpy and pillow; set PYTHON to choose the interpreter.
set -eu
here="$(cd "$(dirname "$0")" && pwd)"
py="${PYTHON:-python3}"
case_name="${1:-main-menu}"
"$py" "$here/compare/compare.py" record "$case_name"
"$py" "$here/convert/layout.py"
"$py" "$here/convert/render_pieces.py" "$case_name"
"$py" "$here/compare/compare.py" check "$case_name"
