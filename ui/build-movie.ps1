<#
.SYNOPSIS
    Rebuilds ui\levelup.swf from the pinned base export plus ui\patches.

.DESCRIPTION
    FFDec's script export is NOT deterministic -- exporting the same movie
    twice can differ by injected `var` declarations. Patches are therefore
    generated against, and applied to, one pinned export (ui\_base) instead of
    a fresh one, so the build stays reproducible.

    1. copies ui\_base (the pinned pristine export) to ui\_build
    2. applies every patch in ui\patches
    3. verifies the expected edits are present in the result
    4. imports the patched scripts into the movie

    Run ui\make-patches.ps1 -Refresh to (re)create ui\_base.

.PARAMETER Vanilla
    The unpatched vanilla movie, used as the import source. It is BioWare's
    and is deliberately not stored in this repo.

.PARAMETER FfdecJar
    Path to ffdec.jar (JPEXS Free Flash Decompiler).

.PARAMETER Java
    Java executable to run FFDec with.

.PARAMETER Out
    Where to write the patched movie. Default: ui\levelup.swf

.EXAMPLE
    powershell -File ui\build-movie.ps1 -Java "C:\Program Files\Zulu\zulu-24\bin\java.exe"
#>
[CmdletBinding()]
param(
    [string] $Vanilla,
    [string] $FfdecJar,
    [string] $Java = 'java',
    [string] $Out
)

$ErrorActionPreference = 'Stop'

$here = if ($PSScriptRoot) { $PSScriptRoot } else { Split-Path -Parent $MyInvocation.MyCommand.Definition }
if (-not $Vanilla)  { $Vanilla  = Join-Path $here 'vanilla_levelup.swf' }
if (-not $FfdecJar) { $FfdecJar = Join-Path $env:TEMP 'ffdec\ffdec.jar' }
if (-not $Out)      { $Out      = Join-Path $here 'levelup.swf' }

$baseExport = Join-Path $here '_base'
$patches    = Join-Path $here 'patches'
$stage      = Join-Path $here '_build'

if (-not (Test-Path -LiteralPath $Vanilla))     { throw "Vanilla movie not found: '$Vanilla'. Pass -Vanilla." }
if (-not (Test-Path -LiteralPath $FfdecJar))    { throw "ffdec.jar not found: '$FfdecJar'. Pass -FfdecJar." }
if (-not (Test-Path -LiteralPath $baseExport))  { throw "Pinned base export not found: '$baseExport'. Run ui\make-patches.ps1 -Refresh." }
if (-not (Test-Path -LiteralPath $patches))     { throw "Patch folder not found: '$patches'." }

# -------------------------------------------------------------- 1. base copy
if (Test-Path -LiteralPath $stage) { Remove-Item -Recurse -Force $stage }
Copy-Item -LiteralPath $baseExport -Destination $stage -Recurse
$scripts = Join-Path $stage 'scripts'
if (-not (Test-Path -LiteralPath $scripts)) { throw "Pinned base has no 'scripts' folder." }
Write-Host "Base    : $baseExport -> $stage"

# ---------------------------------------------------------------- 2. patch
Push-Location $stage
try {
    # git writes progress to stderr, which PowerShell 5.1 would turn into a
    # terminating error while $ErrorActionPreference is 'Stop'.
    $prevEap = $ErrorActionPreference
    $ErrorActionPreference = 'Continue'
    try {
        foreach ($patch in Get-ChildItem $patches -Filter '*.patch' | Sort-Object Name) {
            & git apply -p1 $patch.FullName
            $code = $LASTEXITCODE
            if ($code -ne 0) { throw "Failed to apply patch '$($patch.Name)' (git apply exited $code)." }
            Write-Host "Patch   : applied $($patch.Name)"
        }
    } finally {
        $ErrorActionPreference = $prevEap
    }
} finally {
    Pop-Location
}

# ----------------------------------------------------- 3. verify the edits
# Applying patches silently succeeding is not proof they landed; check for
# identifiers that only exist in the patched movie.
$expected = @{
    'scripts\__Packages\AbilityScene.as'                  = @('RevertPoints', 'RestoreUnlearned', 'IsPrereqOfOwned')
    'scripts\__Packages\AttributesScene.as'               = @('SeedExistingAllocations', 'RaceAttributeBonus', 'IsAttributeRequiredAbove')
    'scripts\__Packages\AttributeAdjuster.as'             = @('CanRemovePoint')
    'scripts\__Packages\SkillsScene.as'                   = @('aUnlearnedPoints', 'nInitialPoints')
    'scripts\__Packages\SpellsTalentsScene.as'            = @('aUnlearnedPoints', 'nInitialPoints')
    'scripts\__Packages\LevelUp.as'                       = @('aUnlearnedSpecs', 'RestoreUnlearnedSpecs')
    'scripts\__Packages\SharedLibrary\BookAbilityIcon.as' = @('bLevelUp')
}
foreach ($rel in $expected.Keys) {
    $path = Join-Path $stage $rel
    if (-not (Test-Path -LiteralPath $path)) { throw "Expected file missing after patching: '$rel'." }
    $text = Get-Content -LiteralPath $path -Raw
    foreach ($needle in $expected[$rel]) {
        if ($text -notlike "*$needle*") { throw "Patch verification failed: '$needle' not found in '$rel'." }
    }
}

# Some patches remove code rather than add it, so also assert that gated
# sessions-only conditions are gone.
$forbidden = @{
    'scripts\__Packages\ClassButton.as' = @('IsNewSpecialization')
}
foreach ($rel in $forbidden.Keys) {
    $path = Join-Path $stage $rel
    if (-not (Test-Path -LiteralPath $path)) { throw "Expected file missing after patching: '$rel'." }
    $text = Get-Content -LiteralPath $path -Raw
    foreach ($needle in $forbidden[$rel]) {
        if ($text -like "*$needle*") { throw "Patch verification failed: '$needle' still present in '$rel'." }
    }
}
Write-Host "Verify  : all expected edits present"

# ---------------------------------------------------------------- 4. import
Write-Host "Import  : $scripts -> $Out"
& $Java -jar $FfdecJar -importScript $Vanilla $Out $stage 2>&1 | Select-Object -Last 1
if (-not (Test-Path -LiteralPath $Out)) { throw "FFDec import produced no output movie." }

Write-Host ""
Write-Host "Built   : $Out  ($((Get-Item -LiteralPath $Out).Length) bytes)"
Write-Host "Deploy with:  powershell -File build\deploy.ps1"
