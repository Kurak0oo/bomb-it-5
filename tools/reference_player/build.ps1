param(
    [string]$Checkout = (Join-Path $PSScriptRoot '../../.scratch/edition-5-research/ruffle-runtime'),
    [switch]$CheckOnly,
    [switch]$Baseline,
    [switch]$Fixtures,
    [switch]$Events,
    [switch]$Compact,
    [switch]$Focus
)
$ErrorActionPreference = 'Stop'
$revision = '45366370ed7d1a59c89aa3cf7b765c7a274407cd'
$Checkout = [IO.Path]::GetFullPath($Checkout)
function Invoke-Checked([string]$Program, [string[]]$Arguments) {
    & $Program @Arguments
    if ($LASTEXITCODE -ne 0) { throw "$Program exited with $LASTEXITCODE" }
}
if (!(Test-Path -LiteralPath (Join-Path $Checkout '.git'))) {
    New-Item -ItemType Directory -Force -Path $Checkout | Out-Null
    Invoke-Checked git @('init', $Checkout)
    Invoke-Checked git @('-C', $Checkout, 'remote', 'add', 'origin', 'https://github.com/ruffle-rs/ruffle')
    Invoke-Checked git @('-C', $Checkout, 'fetch', '--depth', '1', 'origin', $revision)
    Invoke-Checked git @('-C', $Checkout, 'checkout', '--detach', 'FETCH_HEAD')
}
$actual = & git -C $Checkout rev-parse HEAD
if ($LASTEXITCODE -ne 0 -or $actual -ne $revision) { throw 'Reference checkout has the wrong revision' }
if (& git -C $Checkout diff --cached --name-only -- core) {
    throw 'Staged core changes are not allowed in the reference checkout'
}
New-Item -ItemType Directory -Force -Path (Join-Path $Checkout 'probe/src') | Out-Null
Copy-Item -LiteralPath (Join-Path $PSScriptRoot 'Cargo.toml') -Destination (Join-Path $Checkout 'probe/Cargo.toml')
Copy-Item -LiteralPath (Join-Path $PSScriptRoot 'Cargo.lock') -Destination (Join-Path $Checkout 'Cargo.lock')
Copy-Item -LiteralPath (Join-Path $PSScriptRoot 'src/main.rs') -Destination (Join-Path $Checkout 'probe/src/main.rs')
# Copy-Item preserves source timestamps. A source edited during an earlier build
# can otherwise look older than that build's completion and evade Cargo's check.
foreach ($relative in @('probe/Cargo.toml', 'probe/src/main.rs')) {
    (Get-Item -LiteralPath (Join-Path $Checkout $relative)).LastWriteTimeUtc = [DateTime]::UtcNow
}
$workspacePath = Join-Path $Checkout 'Cargo.toml'
$workspace = [IO.File]::ReadAllText($workspacePath)
if ($workspace -notmatch '(?m)^\s*"probe",?\s*$') {
    $workspace = $workspace.Replace('"exporter",', '"exporter",' + "`n" + '    "probe",')
    if ($workspace -notmatch '(?m)^\s*"probe",?\s*$') { throw 'Workspace insertion point not found' }
    [IO.File]::WriteAllText($workspacePath, $workspace)
}
Push-Location $Checkout
try {
    $patches = @('reference-observer.patch', 'reference-fixtures.patch', 'reference-events.patch',
        'reference-compact.patch', 'reference-focus.patch', 'reference-actors.patch',
        'reference-geometry.patch', 'reference-drops.patch', 'reference-session-state.patch',
        'reference-class-names.patch', 'reference-actor-bombs.patch', 'reference-ai-returns.patch', 'reference-move-step.patch', 'reference-active-pickups.patch') |
        ForEach-Object { [IO.Path]::GetFullPath((Join-Path $PSScriptRoot $_)) }
    if ($Baseline -and ($Fixtures -or $Events -or $Compact -or $Focus)) { throw 'A baseline requires all research command features disabled' }
    if ($Baseline -and ((& git diff HEAD --name-only -- core) -or (& git ls-files --others --exclude-standard -- core))) {
        throw 'Baseline requires an unchanged core; use a separate checkout'
    }
    if (!$Baseline) {
        # Undo only exact matching research patches, then reapply the documented
        # chain. Reject unrelated core work rather than mixing it into evidence.
        for ($i = $patches.Count - 1; $i -ge 0; $i--) {
            & git apply --reverse --check --ignore-space-change $patches[$i] 2>$null
            if ($LASTEXITCODE -eq 0) { Invoke-Checked git @('apply', '--reverse', '--ignore-space-change', $patches[$i]) }
        }
        if ((& git diff HEAD --name-only -- core) -or (& git ls-files --others --exclude-standard -- core)) {
            throw 'Core differs from the pinned revision beyond the matching research patches'
        }
        foreach ($entry in $patches) { Invoke-Checked git @('apply', '--ignore-space-change', $entry) }
    }
    $features = @()
    if ($Baseline) { $features = @('--no-default-features') }
    $featureNames = @()
    if ($Fixtures) { $featureNames += 'reference-fixtures' }
    if ($Events) { $featureNames += 'reference-events' }
    if ($Compact) { $featureNames += 'reference-compact' }
    if ($Focus) { $featureNames += 'reference-focus' }
    if ($featureNames.Count) { $features = @('--features', ($featureNames -join ',')) }
    Invoke-Checked cargo (@('check', '--locked', '-p', 'probe') + $features)
    if (!$CheckOnly) { Invoke-Checked cargo (@('build', '--locked', '-p', 'probe', '--profile', 'ci', '--jobs', '6') + $features) }
    & git diff HEAD | Set-Content -LiteralPath reference-changes.patch -Encoding utf8
    $manifest = [ordered]@{
        revision = $actual
        rustc = (& rustc -Vv) -join "`n"
        cargo = (& cargo -V)
        platform = [Environment]::OSVersion.VersionString
        operation = $(if ($CheckOnly) { 'cargo-check-only' } else { 'cargo-check-and-build' })
        profile = $(if ($CheckOnly) { 'dev' } else { 'ci' })
        observer = !$Baseline
        fixtures = [bool]$Fixtures
        events = [bool]$Events
        compact = [bool]$Compact
        focus = [bool]$Focus
        installed_patches = @(if (!$Baseline) { $patches | ForEach-Object {
            @{ name = [IO.Path]::GetFileName($_); sha256 = (Get-FileHash -LiteralPath $_ -Algorithm SHA256).Hash.ToLowerInvariant() }
        } })
        lock_sha256 = (Get-FileHash -LiteralPath Cargo.lock -Algorithm SHA256).Hash.ToLowerInvariant()
        source_sha256 = (Get-FileHash -LiteralPath probe/src/main.rs -Algorithm SHA256).Hash.ToLowerInvariant()
        tracked_changes = (& git diff HEAD --stat) -join "`n"
        untracked_core_files = @(& git ls-files --others --exclude-standard -- core)
    }
    if (!$CheckOnly) { $manifest.player_sha256 = (Get-FileHash -LiteralPath target/ci/probe.exe -Algorithm SHA256).Hash.ToLowerInvariant() }
    $manifest | ConvertTo-Json -Depth 5 | Set-Content -LiteralPath reference-build.json -Encoding utf8
} finally { Pop-Location }
