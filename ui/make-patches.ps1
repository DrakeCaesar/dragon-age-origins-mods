<#
.SYNOPSIS
    Regenerates ui\movies\<Movie>\patches\*.patch by diffing the pinned base
    export against the edited working tree.

.DESCRIPTION
    FFDec's script export is NOT deterministic, so patches are diffed against a
    single pinned export (ui\movies\<Movie>\_base) rather than a fresh one. The
    working tree (_work) must itself be derived from that same base, otherwise
    unrelated FFDec artefacts show up as patches.

    Typical loop:
        powershell -File ui\make-patches.ps1 -Movie levelup -Refresh
        # edit ui\movies\levelup\_work\scripts\...
        powershell -File ui\make-patches.ps1 -Movie levelup

    Every patch is rewritten, and patches whose file no longer differs are
    deleted, so patches cannot silently go stale.

.PARAMETER Movie
    Movie to work on: the folder name under ui\movies\. Default: levelup

.PARAMETER Refresh
    Re-export the movie's ActionScript into _base first. Use after changing
    which SWF is being patched.

.PARAMETER Vanilla
    Movie to export when -Refresh is used. Default: ui\movies\<Movie>\vanilla.swf

.PARAMETER FfdecJar
    Path to ffdec.jar.

.PARAMETER Java
    Java executable.

.EXAMPLE
    powershell -File ui\make-patches.ps1 -Movie levelup -Java "C:\Program Files\Zulu\zulu-24\bin\java.exe"
#>
[CmdletBinding()]
param(
    [string] $Movie = 'levelup',
    [switch] $Refresh,
    [string] $Vanilla,
    [string] $FfdecJar,
    [string] $Java = 'java'
)

$ErrorActionPreference = 'Stop'

$here     = if ($PSScriptRoot) { $PSScriptRoot } else { Split-Path -Parent $MyInvocation.MyCommand.Definition }
$movieDir = Join-Path $here "movies\$Movie"
if (-not (Test-Path -LiteralPath $movieDir)) { throw "Movie folder not found: '$movieDir'." }

if (-not $Vanilla)  { $Vanilla  = Join-Path $movieDir 'vanilla.swf' }
if (-not $FfdecJar) { $FfdecJar = Join-Path $env:TEMP 'ffdec\ffdec.jar' }

$baseExport = Join-Path $movieDir '_base'
$work       = Join-Path $movieDir '_work'
$patches    = Join-Path $movieDir 'patches'

if ($Refresh) {
    if (-not (Test-Path -LiteralPath $Vanilla))  { throw "Movie not found: '$Vanilla'." }
    if (-not (Test-Path -LiteralPath $FfdecJar)) { throw "ffdec.jar not found: '$FfdecJar'." }
    if (Test-Path -LiteralPath $baseExport) { Remove-Item -Recurse -Force $baseExport }
    Write-Host "Export  : $Vanilla -> $baseExport"
    # FFDec writes warnings to stderr, which 'Stop' turns into a terminating
    # error, so run it with 'Continue' and check the exit code instead.
    $prevEap = $ErrorActionPreference
    $ErrorActionPreference = 'Continue'
    try {
        & $Java -jar $FfdecJar -export script $baseExport $Vanilla 2>&1 | Select-Object -Last 1
    } finally {
        $ErrorActionPreference = $prevEap
    }
    if ($LASTEXITCODE -ne 0) { throw "FFDec export failed (exit $LASTEXITCODE)." }
}

if (-not (Test-Path -LiteralPath $baseExport)) { throw "Pinned base not found: '$baseExport'. Pass -Refresh." }
if (-not (Test-Path -LiteralPath $work))       { throw "Work tree not found: '$work'." }
if (-not (Test-Path -LiteralPath $patches))    { New-Item -ItemType Directory -Force -Path $patches | Out-Null }

$bRoot = Join-Path $baseExport 'scripts'
$wRoot = Join-Path $work 'scripts'

$changed = 0

# git writes to stderr; keep it from becoming a terminating error.
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
        Write-Host ("Patch   : {0,-34} {1} hunk(s)" -f $name, $hunks)
        $changed++
    }
} finally {
    $ErrorActionPreference = $prevEap
}

if ($changed -eq 0) { Write-Warning "No differences found -- no patches written." }
Write-Host ""
Write-Host "$Movie : $changed patch(es) in $patches"
