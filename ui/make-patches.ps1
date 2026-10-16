<#
.SYNOPSIS
    Regenerates ui\patches\*.patch by diffing the pinned base export against
    the edited working tree.

.DESCRIPTION
    FFDec's script export is NOT deterministic, so patches are diffed against a
    single pinned export (ui\_base) rather than a fresh one. The working tree
    (ui\_work) must itself be derived from that same base, otherwise unrelated
    FFDec artefacts show up as patches.

    Typical loop:
        powershell -File ui\make-patches.ps1 -Refresh     # pin the base
        # edit ui\_work\scripts\...
        powershell -File ui\make-patches.ps1              # regenerate patches

    Every patch is rewritten, and patches whose file no longer differs are
    deleted, so patches cannot silently go stale.

.PARAMETER Refresh
    Re-export the vanilla movie's scripts into ui\_base first. Use after
    changing which movie is being patched.

.PARAMETER Vanilla
    The unpatched vanilla movie to export when -Refresh is used.

.PARAMETER Work
    Edited tree to diff against the base. Default: ui\_work

.PARAMETER FfdecJar
    Path to ffdec.jar.

.PARAMETER Java
    Java executable.

.EXAMPLE
    powershell -File ui\make-patches.ps1 -Java "C:\Program Files\Zulu\zulu-24\bin\java.exe"
#>
[CmdletBinding()]
param(
    [switch] $Refresh,
    [string] $Vanilla,
    [string] $Work,
    [string] $FfdecJar,
    [string] $Java = 'java'
)

$ErrorActionPreference = 'Stop'

$here = if ($PSScriptRoot) { $PSScriptRoot } else { Split-Path -Parent $MyInvocation.MyCommand.Definition }
if (-not $Vanilla)  { $Vanilla  = Join-Path $here 'vanilla_levelup.swf' }
if (-not $FfdecJar) { $FfdecJar = Join-Path $env:TEMP 'ffdec\ffdec.jar' }
if (-not $Work)     { $Work     = Join-Path $here '_work' }

$baseExport = Join-Path $here '_base'
$patches    = Join-Path $here 'patches'

if ($Refresh) {
    if (-not (Test-Path -LiteralPath $Vanilla))  { throw "Vanilla movie not found: '$Vanilla'." }
    if (-not (Test-Path -LiteralPath $FfdecJar)) { throw "ffdec.jar not found: '$FfdecJar'." }
    if (Test-Path -LiteralPath $baseExport) { Remove-Item -Recurse -Force $baseExport }
    Write-Host "Export  : $Vanilla -> $baseExport"
    & $Java -jar $FfdecJar -export script $baseExport $Vanilla 2>&1 | Select-Object -Last 1
}

if (-not (Test-Path -LiteralPath $baseExport)) { throw "Pinned base not found: '$baseExport'. Pass -Refresh." }
if (-not (Test-Path -LiteralPath $Work))       { throw "Work tree not found: '$Work'." }
if (-not (Test-Path -LiteralPath $patches))    { New-Item -ItemType Directory -Force -Path $patches | Out-Null }

$bRoot = Join-Path $baseExport 'scripts'
$wRoot = Join-Path $Work 'scripts'

$changed = 0
$kept    = @()

$prevEap = $ErrorActionPreference
$ErrorActionPreference = 'Continue'
try {
    foreach ($file in Get-ChildItem $bRoot -Recurse -File -Filter '*.as') {
        $rel   = $file.FullName.Substring($bRoot.Length + 1) -replace '\\', '/'
        $wPath = Join-Path $wRoot ($rel -replace '/', '\')
        $name  = (Split-Path $rel -Leaf) + '.patch'
        $out   = Join-Path $patches $name

        if (-not (Test-Path -LiteralPath $wPath)) { throw "File missing from work tree: '$rel'." }

        if ((Get-FileHash $file.FullName).Hash -eq (Get-FileHash $wPath).Hash) {
            if (Test-Path -LiteralPath $out) { Remove-Item -LiteralPath $out -Force }
            continue
        }

        $raw = & git --no-pager diff --no-index --no-color $file.FullName $wPath 2>$null
        $body = foreach ($l in $raw) {
            if     ($l -like 'diff --git *') { "diff --git a/scripts/$rel b/scripts/$rel" }
            elseif ($l -like '--- *')        { "--- a/scripts/$rel" }
            elseif ($l -like '+++ *')        { "+++ b/scripts/$rel" }
            else                             { $l }
        }
        Set-Content -LiteralPath $out -Value $body -Encoding utf8

        $hunks = ($body | Where-Object { $_ -match '^@@' } | Measure-Object).Count
        Write-Host ("Patch   : {0,-32} {1} hunk(s)" -f $name, $hunks)
        $changed++
        $kept += $name
    }
} finally {
    $ErrorActionPreference = $prevEap
}

if ($changed -eq 0) { Write-Warning "No differences found -- no patches written." }
Write-Host ""
Write-Host "$changed patch(es) in $patches"
