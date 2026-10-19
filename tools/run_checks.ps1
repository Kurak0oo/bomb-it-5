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
