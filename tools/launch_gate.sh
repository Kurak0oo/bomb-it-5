#!/usr/bin/env bash
# Launch gate: the game must start headless and run without engine or script errors.
#
#   tools/launch_gate.sh [FRAMES]
#
# Boots the main scene, then every generated screen on its own (`-- --screen <id>`, one per
# layout in scenes/swf that the app can open), each for FRAMES frames (default 120), and
# fails on any `SCRIPT ERROR`, `ERROR`, `Parse Error` or non-zero exit. Run it before every
# commit: GDScript errors surface only at run time, so a project that imports can still
# fail to start. Headless traps it avoids: it always passes `--quit-after` (a headless run
# without it never ends) and never `-d` (a script error under the debugger stops at an
# interactive `debug>` prompt and floods the log).
set -u
godot="${GODOT:-godot}"
root="$(cd "$(dirname "$0")/.." && pwd)"
frames="${1:-120}"
version="$("$godot" --version 2>/dev/null)" || { echo "launch gate: cannot run Godot ($godot); set GODOT" >&2; exit 2; }
[[ "$version" == 4.5.* ]] || { echo "launch gate: needs Godot 4.5, got $version" >&2; exit 2; }

# Screens with no layout of their own (data files beside the layouts) are not booted.
screens=()
for layout in "$root"/scenes/swf/*.json; do
	id="$(basename "$layout" .json)"
	case "$id" in localization|score_tip_art) continue ;; esac
	screens+=("$id")
done

failed=0
boot() {
	local label="$1"; shift
	local output code
	output="$(timeout 300 "$godot" --headless --path "$root" --quit-after "$frames" "$@" 2>&1)"
	code=$?
	local errors
	errors="$(grep -E '^(SCRIPT ERROR|ERROR|USER ERROR|Parse Error)|Parse Error:' <<<"$output")"
	if [[ $code -ne 0 || -n "$errors" ]]; then
		echo "FAIL: $label (exit $code)"
		[[ -n "$errors" ]] && grep -E -A2 '^(SCRIPT ERROR|ERROR|USER ERROR|Parse Error)|Parse Error:' <<<"$output" | head -20
		failed=$((failed + 1))
	else
		echo "ok: $label"
	fi
}

boot "main scene"
for id in "${screens[@]}"; do
	boot "--screen $id" -- --screen "$id"
done

if [[ $failed -ne 0 ]]; then
	echo "FAIL: launch gate, $failed boot(s) with errors"
	exit 1
fi
echo "PASS: launch gate, $((${#screens[@]} + 1)) boots of $frames frames"
