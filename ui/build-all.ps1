<#
.SYNOPSIS
    Builds every level-up movie variant: two movie bases times two attribute
    floors, four movies in all.

.DESCRIPTION
    The variants exist because the attribute floor is a behavioural choice
    rather than a bug fix. build\deploy.ps1 -AttributeFloor and
    build\dazip.ps1 -AttributeFloor pick which one ships.

        ui\levelup.swf          vanilla base, start-value floor
        ui\levelup_ten.swf      vanilla base, flat 10 floor
        ui\levelup_ftg.swf      FtG base,     start-value floor
        ui\levelup_ftg_ten.swf  FtG base,     flat 10 floor

    Each variant is the same patch set with UseStartingValueFloor flipped at
    build time, so the four cannot drift apart. A variant is skipped when its
    movie base is missing (vanilla.swf is not in the repo), so this is safe to
    run on a machine that only has some of the bases.

.EXAMPLE
    powershell -File ui\build-all.ps1 -Java "C:\Program Files\Zulu\zulu-24\bin\java.exe"
#>
[CmdletBinding()]
param(
    [string] $FfdecJar,
    [string] $Java = 'java'
)

$ErrorActionPreference = 'Stop'

$here = if ($PSScriptRoot) { $PSScriptRoot } else { Split-Path -Parent $MyInvocation.MyCommand.Definition }
$build = Join-Path $here 'build-movie.ps1'

$variants = @(
    @{ Movie = 'levelup';     Floor = 'Starting'; Label = 'vanilla base, starting-value floor' }
    @{ Movie = 'levelup';     Floor = 'Ten';      Label = 'vanilla base, flat 10 floor' }
    @{ Movie = 'levelup_ftg'; Floor = 'Starting'; Label = 'FtG base, starting-value floor' }
    @{ Movie = 'levelup_ftg'; Floor = 'Ten';      Label = 'FtG base, flat 10 floor' }
)

$failed = @()
foreach ($v in $variants) {
    $base = Join-Path $here "movies\$($v.Movie)\vanilla.swf"
    if (-not (Test-Path -LiteralPath $base)) {
        Write-Host "Skip    : $($v.Movie) / $($v.Floor) -- $base is missing"
        continue
    }

    Write-Host ""
    Write-Host "-- $($v.Movie) / $($v.Floor)  ($($v.Label))"
    $args = @('-NoProfile', '-File', $build, '-Movie', $v.Movie, '-AttributeFloor', $v.Floor, '-Java', $Java)
    if ($FfdecJar) { $args += @('-FfdecJar', $FfdecJar) }
    # Native stderr (Java warnings, FFDec progress) must not become a
    # terminating error here, or one warning would fail the whole variant.
    $prevEap = $ErrorActionPreference
    $ErrorActionPreference = 'Continue'
    try {
        & powershell @args 2>&1 | ForEach-Object {
            if ($_ -match '^(Built|Floor|Verify|Patch|Import|Base)') { Write-Host "  $_" }
        }
    } finally {
        $ErrorActionPreference = $prevEap
    }
    if ($LASTEXITCODE -ne 0) { $failed += "$($v.Movie)/$($v.Floor)" }
}

Write-Host ""
if ($failed.Count -gt 0) {
    Write-Host "FAILED : $($failed -join ', ')"
    exit 1
}
Write-Host "All available variants built."
