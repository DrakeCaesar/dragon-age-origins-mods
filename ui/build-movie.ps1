<#
.SYNOPSIS
    Rebuilds a patched UI movie from its pinned base export plus its patches.

.DESCRIPTION
    Each movie lives in ui\movies\<Movie>\:

        vanilla.swf   the unpatched movie (BioWare's; not stored in this repo)
        _base\        pinned pristine FFDec export the patches are made against
        _work\        editable tree; patches are diffed from _base
        _build\       scratch
        patches\      one .patch per changed script

    FFDec's export is NOT deterministic, so the base is pinned rather than
    regenerated each build. Run make-patches.ps1 -Movie <name> -Refresh to
    (re)create it.

    The build copies _base to _build, applies every patch, verifies the
    expected edits are present, then imports the scripts into the movie and
    writes ui\<Movie>.swf.

.PARAMETER Movie
    Movie to build: the folder name under ui\movies\. Default: levelup

.PARAMETER FfdecJar
    Path to ffdec.jar.

.PARAMETER Java
    Java executable.

.PARAMETER Out
    Output path. Default: ui\<Movie>.swf, or ui\<Movie>_ten.swf with
    -AttributeFloor Ten.

.PARAMETER AttributeFloor
    Lowest an attribute may be refunded to.
      Starting (default) - 10 + race + class: the character's real starting
                           values, so points it never spent cannot come back.
      Ten                - a flat 10 on every attribute, so a rebuild starts
                           from scratch, at the cost of the starting values.
    Both are built and shipped as separate movies; see build\ui-base.ps1.

.EXAMPLE
    powershell -File ui\build-movie.ps1 -Movie levelup -Java "C:\Program Files\Zulu\zulu-24\bin\java.exe"
#>
[CmdletBinding()]
param(
    [string] $Movie = 'levelup',
    [string] $FfdecJar,
    [string] $Java = 'java',
    [string] $Out,
    [ValidateSet('Starting', 'Ten')]
    [string] $AttributeFloor = 'Starting'
)

$ErrorActionPreference = 'Stop'

$here     = if ($PSScriptRoot) { $PSScriptRoot } else { Split-Path -Parent $MyInvocation.MyCommand.Definition }
$movieDir = Join-Path $here "movies\$Movie"
if (-not (Test-Path -LiteralPath $movieDir)) { throw "Movie folder not found: '$movieDir'." }

$floorSuffix = if ($AttributeFloor -eq 'Ten') { '_ten' } else { '' }

if (-not $FfdecJar) { $FfdecJar = Join-Path $env:TEMP 'ffdec\ffdec.jar' }
if (-not $Out)      { $Out      = Join-Path $here "$Movie$($floorSuffix).swf" }

$vanilla    = Join-Path $movieDir 'vanilla.swf'
$baseExport = Join-Path $movieDir '_base'
$patches    = Join-Path $movieDir 'patches'
$stage      = Join-Path $movieDir '_build'

if (-not (Test-Path -LiteralPath $vanilla))    { throw "Movie not found: '$vanilla'." }
if (-not (Test-Path -LiteralPath $FfdecJar))   { throw "ffdec.jar not found: '$FfdecJar'." }
if (-not (Test-Path -LiteralPath $baseExport)) { throw "Pinned base not found: '$baseExport'. Run ui\make-patches.ps1 -Movie $Movie -Refresh." }
if (-not (Test-Path -LiteralPath $patches))    { throw "Patch folder not found: '$patches'." }

# Applying patches succeeding is not proof they landed, so verify by looking
# for identifiers that only exist once patched (and, where a patch removes
# something, identifiers that must now be gone).
$checks = @{
    'levelup' = @{
        expected = @{
            'scripts\__Packages\AbilityScene.as'                  = @('RevertPoints', 'RestoreUnlearned', 'IsPrereqOfOwned', 'IsCombatTrainingPrereqOfOwned')
            'scripts\__Packages\AttributesScene.as'               = @('SeedExistingAllocations', 'AttributeFloor', 'ClassAttributeBonus', 'AdjustFromTable', 'AdjustColumnFor', 'StrAdjust', 'IntAdjust', 'ConAdjust', 'Get2DAValueByColumnName', 'IsAttributeRequiredAbove', 'LevelUp.RevertAllChanges()', 'if(_loc1_ - 1 < AttributesScene.AttributeFloor(nID))')
            'scripts\__Packages\AttributeAdjuster.as'             = @('CanRemovePoint')
            'scripts\__Packages\SkillsScene.as'                   = @('aUnlearnedPoints', 'nInitialPoints')
            'scripts\__Packages\SpellsTalentsScene.as'            = @('aUnlearnedPoints', 'nInitialPoints')
            'scripts\__Packages\LevelUp.as'                       = @('aUnlearnedSpecs', 'RestoreUnlearnedSpecs', 'HasAbilityRequiringSpec', 'Number(_loc1_) != 0')
            'scripts\__Packages\SharedLibrary\BookAbilityIcon.as' = @('bLevelUp')
        }
        forbidden = @{
            'scripts\__Packages\ClassButton.as' = @('IsNewSpecialization')
            # The attribute bonus must be resolved from RACE_base by name. Hard-coded
            # id comparisons are the bug that credits Willpower with Dwarf's +2 Con.
            'scripts\__Packages\AttributesScene.as' = @('nID == 1 || nID == 2', 'nID == 5 || nID == 6')
            # Diagnostic markers from an earlier debugging round. They must never
            # reappear: the level-up name field is not ours to write to.
            'scripts\__Packages\LevelUp.as'     = @('RSP8', 'RSP10')
        }
    }
    # Same edits, layered onto FtG UI Mod's level-up movie instead of vanilla.
    # Its LevelUp.as is restructured, so the guard uses its own variable name,
    # and InitBookMenu proves the build really is based on their movie.
    'levelup_ftg' = @{
        expected = @{
            'scripts\__Packages\AbilityScene.as'                  = @('RevertPoints', 'RestoreUnlearned', 'IsPrereqOfOwned', 'IsCombatTrainingPrereqOfOwned')
            'scripts\__Packages\AttributesScene.as'               = @('SeedExistingAllocations', 'AttributeFloor', 'ClassAttributeBonus', 'AdjustFromTable', 'AdjustColumnFor', 'StrAdjust', 'IntAdjust', 'ConAdjust', 'Get2DAValueByColumnName', 'IsAttributeRequiredAbove', 'LevelUp.RevertAllChanges()', 'if(_loc1_ - 1 < AttributesScene.AttributeFloor(nID))')
            'scripts\__Packages\AttributeAdjuster.as'             = @('CanRemovePoint')
            'scripts\__Packages\SkillsScene.as'                   = @('aUnlearnedPoints', 'nInitialPoints')
            'scripts\__Packages\SpellsTalentsScene.as'            = @('aUnlearnedPoints', 'nInitialPoints')
            'scripts\__Packages\LevelUp.as'                       = @('aUnlearnedSpecs', 'RestoreUnlearnedSpecs', 'HasAbilityRequiringSpec', 'Number(_loc2_) != 0', 'InitBookMenu')
            'scripts\__Packages\SharedLibrary\BookAbilityIcon.as' = @('bLevelUp')
        }
        forbidden = @{
            'scripts\__Packages\ClassButton.as' = @('IsNewSpecialization')
            'scripts\__Packages\AttributesScene.as' = @('nID == 1 || nID == 2', 'nID == 5 || nID == 6')   # see above
            'scripts\__Packages\LevelUp.as'     = @('RSP8', 'RSP10')   # see above
        }
    }
}

# -------------------------------------------------------------- 1. base copy
if (Test-Path -LiteralPath $stage) { Remove-Item -Recurse -Force $stage }
Copy-Item -LiteralPath $baseExport -Destination $stage -Recurse
if (-not (Test-Path -LiteralPath (Join-Path $stage 'scripts'))) { throw "Pinned base has no 'scripts' folder." }
Write-Host "Base    : $baseExport -> $stage"

# ---------------------------------------------------------------- 2. patch
Push-Location $stage
try {
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

# ------------------------------------------- 2b. pick the attribute floor
# Both floors are the same source with the flag flipped, so one patch set and
# one movie base produce both variants and they cannot drift apart.
$floorFile = Join-Path $stage 'scripts\__Packages\AttributesScene.as'
if (Test-Path -LiteralPath $floorFile) {
    $text = Get-Content -LiteralPath $floorFile -Raw
    $want = if ($AttributeFloor -eq 'Ten') { 'false' } else { 'true' }
    $new  = [regex]::Replace($text, '(static var UseStartingValueFloor = )(true|false)(;)', { param($m) $m.Groups[1].Value + $want + $m.Groups[3].Value })
    if ($new -eq $text -and $text -notlike "*UseStartingValueFloor = $want*") {
        throw "Could not set UseStartingValueFloor in '$floorFile'."
    }
    Set-Content -LiteralPath $floorFile -Value $new -Encoding utf8 -NoNewline
    Write-Host "Floor   : $AttributeFloor (UseStartingValueFloor = $want)"
}

# ----------------------------------------------------- 3. verify the edits
if ($checks.ContainsKey($Movie)) {
    foreach ($rel in $checks[$Movie].expected.Keys) {
        $path = Join-Path $stage $rel
        if (-not (Test-Path -LiteralPath $path)) { throw "Expected file missing after patching: '$rel'." }
        $text = Get-Content -LiteralPath $path -Raw
        foreach ($needle in $checks[$Movie].expected[$rel]) {
            if ($text -notlike "*$needle*") { throw "Patch verification failed: '$needle' not found in '$rel'." }
        }
    }
    foreach ($rel in $checks[$Movie].forbidden.Keys) {
        $path = Join-Path $stage $rel
        if (-not (Test-Path -LiteralPath $path)) { throw "Expected file missing after patching: '$rel'." }
        $text = Get-Content -LiteralPath $path -Raw
        foreach ($needle in $checks[$Movie].forbidden[$rel]) {
            if ($text -like "*$needle*") { throw "Patch verification failed: '$needle' still present in '$rel'." }
        }
    }
    Write-Host "Verify  : all expected edits present"
} else {
    Write-Warning "No verification checks defined for movie '$Movie'."
}

# ---------------------------------------------------------------- 4. import
Write-Host "Import  : $vanilla + patched scripts -> $Out"
& $Java -jar $FfdecJar -importScript $vanilla $Out $stage 2>&1 | Select-Object -Last 1
if (-not (Test-Path -LiteralPath $Out)) { throw "FFDec import produced no output movie." }

Write-Host ""
Write-Host "Built   : $Out  ($((Get-Item -LiteralPath $Out).Length) bytes)"

