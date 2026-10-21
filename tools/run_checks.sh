#!/usr/bin/env bash
# Linux counterpart of run_checks.ps1: same suites, same success patterns.
set -u
godot="${GODOT:-godot}"
root="$(cd "$(dirname "$0")/.." && pwd)"
version="$("$godot" --version)"
[[ "$version" == 4.5.* ]] || { echo "Checks require Godot 4.5; received: $version" >&2; exit 1; }
suites=(
	"res://tests/command_boundary_check.gd|^PASS: [0-9]+ command boundary checks$"
	"res://tests/scheduler_check.gd|^PASS: [0-9]+ scheduler checks$"
	"res://tests/bomb_simulation_check.gd|^PASS: [0-9]+ bomb simulation checks$"
	"res://tests/round_play_check.gd|^PASS: [0-9]+ round play checks$"
	"res://tests/round_regression_check.gd|^PASS: [0-9]+ round regression checks$"
	"res://tests/fidelity_check.gd|^PASS: [0-9]+ fidelity checks$"
	"res://tests/game_scene_check.gd|^PASS: [0-9]+ game scene checks$"
	"res://tests/mode_seam_check.gd|^PASS: [0-9]+ mode seam checks$"
	"res://tests/layout_check.gd|^PASS: [0-9]+ layout checks$"
	"res://tests/session_check.gd|^PASS: [0-9]+ session checks$"
	"res://tests/flow_scene_check.gd|^PASS: [0-9]+ flow scene checks$"
	"res://tools/playthrough_check.gd|^PASS: 3 full-board playthrough checks "
)
for suite in "${suites[@]}"; do
	script="${suite%%|*}"
	pattern="${suite#*|}"
	output="$("$godot" --headless --path "$root" --script "$script" 2>&1)"
	code=$?
	printf '%s\n' "$output"
	if [[ $code -ne 0 ]] || grep -qE '^(SCRIPT ERROR|ERROR):' <<<"$output" || ! grep -qE "$pattern" <<<"$output"; then
		exit 1
	fi
done
