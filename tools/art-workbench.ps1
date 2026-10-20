param(
    [string]$Godot = (Join-Path $PSScriptRoot '../.scratch/godot-4.5/Godot_v4.5-stable_win64_console.exe')
)

$ErrorActionPreference = 'Stop'
$version = & $Godot --version
if ($LASTEXITCODE -ne 0 -or "$version" -notmatch '^4\.5\.') {
    throw "Art Workbench requires Godot 4.5; received: $version"
}
& $Godot --path (Split-Path $PSScriptRoot -Parent) --resolution 1600x900 res://scenes/art_workbench.tscn
exit $LASTEXITCODE
