#!/usr/bin/env bash
# Converter, one command on the SWF machine: tools/convert.sh [case]
#   1. record the case's goldens with the reference player (tools/compare.sh record)
#   2. record each screen's timeline and interactive states (record_screen.py timeline/states)
#   3. regenerate the screen layouts from the goldens (tools/convert/layout.py), with the
#      en-US strings of the localised text fields (tools/convert/localization.py; needs the
#      decompiled AS3 in .scratch/as3, else the committed scenes/swf/localization.json stays)
#   4. render every piece and sequence frame, and export the fonts, into the ignored local pack
#   5. check Godot against the goldens, with pixels (tools/compare.sh check)
# Commit tests/goldens/ and scenes/swf/ afterwards; original/ stays local.
# Needs Python 3.10+ with numpy and pillow; set PYTHON to choose the interpreter.
set -eu
here="$(cd "$(dirname "$0")" && pwd)"
py="${PYTHON:-python3}"
case_name="${1:-main-menu}"
"$py" "$here/compare/compare.py" record "$case_name"
"$py" "$here/convert/record_screen.py" timeline "$case_name"
"$py" "$here/convert/record_screen.py" states "$case_name"
"$py" "$here/convert/localization.py" || echo "keeping the committed scenes/swf/localization.json"
"$py" "$here/convert/layout.py"
"$py" "$here/convert/record_screen.py" art "$case_name"
"$py" "$here/convert/record_screen.py" fonts "$case_name"
"$py" "$here/compare/compare.py" check "$case_name"
