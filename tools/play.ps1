param(
    [string]$Godot = (Join-Path $PSScriptRoot '../.scratch/godot-4.5/Godot_v4.5-stable_win64_console.exe')
)

$ErrorActionPreference = 'Stop'
$version = & $Godot --version
if ($LASTEXITCODE -ne 0 -or "$version" -notmatch '^4\.5\.') {
    throw "Play requires Godot 4.5; received: $version"
}
$root = Split-Path $PSScriptRoot -Parent
# The sound pack (original/audio) is built from the SWF; without it the game is silent.
$swf = Join-Path $root '.scratch/edition-5-research/agame-bomb-it-5-zh-fix.swf'
if ((Test-Path $swf) -and -not (Test-Path (Join-Path $root 'original/audio/index.json'))) {
    Write-Host 'Building the sound pack from the SWF...'
    & python (Join-Path $PSScriptRoot 'art_pipeline/original_audio.py')
    if ($LASTEXITCODE -ne 0) { Write-Warning 'Sound pack build failed: the game will be silent.' }
}
$arguments = @('--path', $root)
& $Godot @arguments
exit $LASTEXITCODE
