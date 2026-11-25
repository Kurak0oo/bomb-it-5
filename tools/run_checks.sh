#!/usr/bin/env bash
# Linux counterpart of run_checks.ps1: same suites, same success patterns.
set -u
godot="${GODOT:-godot}"
root="$(cd "$(dirname "$0")/.." && pwd)"
version="$("$godot" --version)"
[[ "$version" == 4.5.* ]] || { echo "Checks require Godot 4.5; received: $version" >&2; exit 1; }
# The project must start cleanly before any suite runs (tools/launch_gate.sh).
GODOT="$godot" "$root/tools/launch_gate.sh" || exit 1
suites=(
	"res://tests/command_boundary_check.gd|^PASS: [0-9]+ command boundary checks$"
	"res://tests/scheduler_check.gd|^PASS: [0-9]+ scheduler checks$"
	"res://tests/bomb_simulation_check.gd|^PASS: [0-9]+ bomb simulation checks$"
	"res://tests/round_play_check.gd|^PASS: [0-9]+ round play checks$"
	"res://tests/round_regression_check.gd|^PASS: [0-9]+ round regression checks$"
	"res://tests/fidelity_check.gd|^PASS: [0-9]+ fidelity checks$"
	"res://tests/game_scene_check.gd|^PASS: [0-9]+ game scene checks$"
	"res://tests/actor_display_check.gd|^PASS: [0-9]+ actor display checks$||^SKIP: actor display checks"
	"res://tests/walk_stop_check.gd|^PASS: [0-9]+ walk stop checks$||^SKIP: walk stop check needs the local actors pack"
	"res://tests/mode_seam_check.gd|^PASS: [0-9]+ mode seam checks$"
	"res://tests/layout_check.gd|^PASS: [0-9]+ layout checks$"
	"res://tests/session_check.gd|^PASS: [0-9]+ session checks$"
	"res://tests/game_board_check.gd|^PASS: [0-9]+ game board checks$"
	"res://tests/flow_scene_check.gd|^PASS: [0-9]+ flow scene checks$"
	"res://tests/start_error_check.gd|^PASS: [0-9]+ start error checks$"
	"res://tests/capture_focus_check.gd|^PASS: [0-9]+ capture focus checks$"
	"res://tests/round_start_hitch_check.gd|^PASS: [0-9]+ round start hitch checks \(worst frame [0-9.]+ ms\)$||^SKIP: round start hitch checks"
	"res://tests/difficulty_check.gd|^PASS: [0-9]+ difficulty checks$"
	"res://tests/controls_check.gd|^PASS: [0-9]+ controls checks$"
	"res://tests/looks_check.gd|^PASS: [0-9]+ looks checks$"
	"res://tests/dress_up_check.gd|^PASS: [0-9]+ dress-up checks$"
	"res://tests/dress_up_after_game_check.gd|^PASS: [0-9]+ dress-up after game checks$"
	"res://tests/kill_check.gd|^PASS: [0-9]+ kill checks$"
	"res://tests/green_zone_check.gd|^PASS: [0-9]+ green zone checks$"
	"res://tests/respawn_input_check.gd|^PASS: [0-9]+ respawn input checks$"
	"res://tests/pac_man_check.gd|^PASS: [0-9]+ pac-man checks$"
	"res://tests/stage_features_check.gd|^PASS: [0-9]+ stage feature checks$"
	"res://tests/art_catalog_check.gd|^PASS: [0-9]+ art catalogue checks"
	"res://tests/hitmove_check.gd|^PASS: [0-9]+ hitmove checks$"
	"res://tests/audio_check.gd|^PASS: [0-9]+ audio checks$"
	"res://tests/quality_check.gd|^PASS: [0-9]+ quality checks$"
	"res://tests/ai_trace_check.gd|^PASS: [0-9]+ ai trace checks$"
	"res://tests/avm_random_check.gd|^PASS: [0-9]+ avm random checks$"
	"res://tools/playthrough_check.gd|^PASS: [0-9]+ full-board playthrough checks "
	"res://tools/smoke_playthrough.gd|^PASS: smoke playthrough |--fixed-fps 35"
)
for suite in "${suites[@]}"; do
	IFS='|' read -r script pattern extra skip <<< "$suite"
	# shellcheck disable=SC2086
	output="$("$godot" --headless --path "$root" $extra --script "$script" 2>&1)"
	code=$?
	printf '%s\n' "$output"
	if [[ $code -ne 0 ]] || grep -qE '^(SCRIPT ERROR|ERROR):' <<<"$output"; then
		exit 1
	fi
	# A check that cannot run for a missing local pack reports SKIP (not a pass), and the
	# run continues: a clean checkout still succeeds without the original art.
	if [[ -n "$skip" ]] && grep -qE "$skip" <<<"$output"; then
		echo "SKIP: $script (local pack missing)"
		continue
	fi
	if ! grep -qE "$pattern" <<<"$output"; then
		exit 1
	fi
done
