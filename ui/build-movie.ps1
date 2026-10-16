<#
.SYNOPSIS
    Rebuilds ui\levelup.swf: the vanilla level-up movie with the ActionScript
    patches in ui\patches applied.

.DESCRIPTION
    1. exports the movie's ActionScript with FFDec into a scratch tree
    2. applies every patch in ui\patches (git apply, -p1)
    3. re-imports the scripts into the movie to produce the patched .swf

    The unpatched vanilla movie is deliberately NOT stored in this repo -- it
    is BioWare's. Pass its path with -Vanilla. It can be extracted from
    guiexport.erf in the game install (it is a headerless SWF; prepending an
    8-byte "FWS" + length + rect header makes it parseable by FFDec).

.PARAMETER Vanilla
    Path to the unpatched vanilla level-up SWF.

.PARAMETER FfdecJar
    Path to ffdec.jar (JPEXS Free Flash Decompiler).

.PARAMETER Java
    Java executable to run FFDec with.

.PARAMETER Out
    Where to write the patched movie. Default: ui\levelup.swf

.EXAMPLE
    powershell -File ui\build-movie.ps1
#>
[CmdletBinding()]
param(
    [string] $Vanilla,
    [string] $FfdecJar,
    [string] $Java = 'java',
    [string] $Out
)

$ErrorActionPreference = 'Stop'

# $PSScriptRoot is not populated while parameters are being bound under
# PowerShell 5.1, so resolve the defaults here instead.
$here = if ($PSScriptRoot) { $PSScriptRoot } else { Split-Path -Parent $MyInvocation.MyCommand.Definition }
if (-not $Vanilla)  { $Vanilla  = Join-Path $here 'vanilla_levelup.swf' }
if (-not $FfdecJar) { $FfdecJar = Join-Path $env:TEMP 'ffdec\ffdec.jar' }
if (-not $Out)      { $Out      = Join-Path $here 'levelup.swf' }

$patches = Join-Path $here 'patches'
$stage   = Join-Path $here '_build'

if (-not (Test-Path -LiteralPath $Vanilla))  { throw "Vanilla movie not found: '$Vanilla'. Pass -Vanilla." }
if (-not (Test-Path -LiteralPath $FfdecJar)) { throw "ffdec.jar not found: '$FfdecJar'. Pass -FfdecJar." }
if (-not (Test-Path -LiteralPath $patches))  { throw "Patch folder not found: '$patches'." }

if (Test-Path -LiteralPath $stage) { Remove-Item -Recurse -Force $stage }

# ---------------------------------------------------------------- 1. export
Write-Host "Export  : $Vanilla -> $stage"
& $Java -jar $FfdecJar -export script $stage $Vanilla 2>&1 | Select-Object -Last 1
$scripts = Join-Path $stage 'scripts'
if (-not (Test-Path -LiteralPath $scripts)) { throw "FFDec export produced no 'scripts' folder." }

# ---------------------------------------------------------------- 2. patch
Push-Location $stage
try {
    # Patch paths are 'scripts/__Packages/...', i.e. relative to the staging
    # root, so apply from $stage (not from $scripts).
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

# ---------------------------------------------------------------- 3. import
Write-Host "Import  : $scripts -> $Out"
& $Java -jar $FfdecJar -importScript $Vanilla $Out $stage 2>&1 | Select-Object -Last 1
if (-not (Test-Path -LiteralPath $Out)) { throw "FFDec import produced no output movie." }

Write-Host ""
Write-Host "Built   : $Out  ($((Get-Item -LiteralPath $Out).Length) bytes)"
Write-Host "Deploy with:  powershell -File build\deploy.ps1"
