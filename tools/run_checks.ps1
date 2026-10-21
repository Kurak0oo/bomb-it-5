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
    @{ Script = 'res://tests/mode_seam_check.gd'; Success = '^PASS: \d+ mode seam checks$' }
    @{ Script = 'res://tests/layout_check.gd'; Success = '^PASS: \d+ layout checks$' }
    @{ Script = 'res://tools/playthrough_check.gd'; Success = '^PASS: 3 full-board playthrough checks ' }
)
foreach ($suite in $suites) {
    $output = & $Godot --headless --path $projectRoot --script $suite.Script 2>&1
    $checkExitCode = $LASTEXITCODE
    $output | ForEach-Object { Write-Output $_ }
    if ($checkExitCode -ne 0 -or ($output -match '^(SCRIPT ERROR|ERROR):') -or
        -not ($output -match $suite.Success)) {
        exit 1
    }
}
exit 0
