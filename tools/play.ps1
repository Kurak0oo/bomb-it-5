param(
    [string]$Godot = (Join-Path $PSScriptRoot '../.scratch/godot-4.5/Godot_v4.5-stable_win64_console.exe'),
    # Development launch straight onto the fixed practice board instead of the main menu.
    [switch]$Practice
)

$ErrorActionPreference = 'Stop'
$version = & $Godot --version
if ($LASTEXITCODE -ne 0 -or "$version" -notmatch '^4\.5\.') {
    throw "Play requires Godot 4.5; received: $version"
}
$arguments = @('--path', (Split-Path $PSScriptRoot -Parent))
if ($Practice) { $arguments += @('--', '--practice') }
& $Godot @arguments
exit $LASTEXITCODE
