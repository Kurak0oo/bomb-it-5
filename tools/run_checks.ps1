param(
    [string]$Godot = (Join-Path $PSScriptRoot '../.scratch/godot-4.5/Godot_v4.5-stable_win64_console.exe')
)

$ErrorActionPreference = 'Stop'
$projectRoot = Split-Path $PSScriptRoot -Parent
$version = & $Godot --version
if ($LASTEXITCODE -ne 0 -or "$version" -notmatch '^4\.5\.') {
    throw "Checks require Godot 4.5; received: $version"
}

$suites = @(
    @{ Script = 'res://tests/command_boundary_check.gd'; Success = '^PASS: \d+ command boundary checks$' }
    @{ Script = 'res://tests/scheduler_check.gd'; Success = '^PASS: \d+ scheduler checks$' }
    @{ Script = 'res://tests/bomb_simulation_check.gd'; Success = '^PASS: \d+ bomb simulation checks$' }
    @{ Script = 'res://tests/round_play_check.gd'; Success = '^PASS: \d+ round play checks$' }
    @{ Script = 'res://tests/round_regression_check.gd'; Success = '^PASS: \d+ round regression checks$' }
    @{ Script = 'res://tests/fidelity_check.gd'; Success = '^PASS: \d+ fidelity checks$' }
    @{ Script = 'res://tests/game_scene_check.gd'; Success = '^PASS: \d+ game scene checks$' }
    @{ Script = 'res://tests/actor_display_check.gd'; Success = '^PASS: \d+ actor display checks$'; Skip = '^SKIP: actor display checks' }
    @{ Script = 'res://tests/mode_seam_check.gd'; Success = '^PASS: \d+ mode seam checks$' }
    @{ Script = 'res://tests/layout_check.gd'; Success = '^PASS: \d+ layout checks$' }
    @{ Script = 'res://tests/session_check.gd'; Success = '^PASS: \d+ session checks$' }
    @{ Script = 'res://tests/game_board_check.gd'; Success = '^PASS: \d+ game board checks$' }
    @{ Script = 'res://tests/flow_scene_check.gd'; Success = '^PASS: \d+ flow scene checks$' }
    @{ Script = 'res://tests/start_error_check.gd'; Success = '^PASS: \d+ start error checks$' }
    @{ Script = 'res://tests/capture_focus_check.gd'; Success = '^PASS: \d+ capture focus checks$' }
    @{ Script = 'res://tests/round_start_hitch_check.gd'; Success = '^PASS: \d+ round start hitch checks \(worst frame [0-9.]+ ms\)$'; Skip = '^SKIP: round start hitch checks' }
    @{ Script = 'res://tests/difficulty_check.gd'; Success = '^PASS: \d+ difficulty checks$' }
    @{ Script = 'res://tests/controls_check.gd'; Success = '^PASS: \d+ controls checks$' }
    @{ Script = 'res://tests/looks_check.gd'; Success = '^PASS: \d+ looks checks$' }
    @{ Script = 'res://tests/dress_up_check.gd'; Success = '^PASS: \d+ dress-up checks$' }
    @{ Script = 'res://tests/dress_up_after_game_check.gd'; Success = '^PASS: \d+ dress-up after game checks$' }
    @{ Script = 'res://tests/kill_check.gd'; Success = '^PASS: \d+ kill checks$' }
    @{ Script = 'res://tests/green_zone_check.gd'; Success = '^PASS: \d+ green zone checks$' }
    @{ Script = 'res://tests/respawn_input_check.gd'; Success = '^PASS: \d+ respawn input checks$' }
    @{ Script = 'res://tests/pac_man_check.gd'; Success = '^PASS: \d+ pac-man checks$' }
    @{ Script = 'res://tests/stage_features_check.gd'; Success = '^PASS: \d+ stage feature checks$' }
    @{ Script = 'res://tests/art_catalog_check.gd'; Success = '^PASS: \d+ art catalogue checks' }
    @{ Script = 'res://tests/hitmove_check.gd'; Success = '^PASS: \d+ hitmove checks$' }
    @{ Script = 'res://tests/audio_check.gd'; Success = '^PASS: \d+ audio checks$' }
    @{ Script = 'res://tests/quality_check.gd'; Success = '^PASS: \d+ quality checks$' }
    @{ Script = 'res://tests/ai_trace_check.gd'; Success = '^PASS: \d+ ai trace checks$' }
    @{ Script = 'res://tests/avm_random_check.gd'; Success = '^PASS: \d+ avm random checks$' }
    @{ Script = 'res://tools/playthrough_check.gd'; Success = '^PASS: \d+ full-board playthrough checks ' }
    @{ Script = 'res://tools/smoke_playthrough.gd'; Success = '^PASS: smoke playthrough '; Args = @('--fixed-fps', '35') }
)
foreach ($suite in $suites) {
    $extra = if ($suite.Args) { $suite.Args } else { @() }
    $output = & $Godot --headless --path $projectRoot @extra --script $suite.Script 2>&1
    $checkExitCode = $LASTEXITCODE
    $output | ForEach-Object { Write-Output $_ }
    if ($checkExitCode -ne 0 -or ($output -match '^(SCRIPT ERROR|ERROR):')) {
        exit 1
    }
    # A check that cannot run for a missing local pack reports SKIP (not a pass), and the
    # run continues: a clean checkout still succeeds without the original art.
    if ($suite.Skip -and ($output -match $suite.Skip)) {
        Write-Output "SKIP: $($suite.Script) (local pack missing)"
        continue
    }
    if (-not ($output -match $suite.Success)) {
        exit 1
    }
}
exit 0
