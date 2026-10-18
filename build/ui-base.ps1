# Which level-up movie to ship.
#
# FtG UI Mod is no longer supported: the mod ships one movie, built from the
# vanilla screen, and installs it through packages\core\override so it wins over
# any other addin that ships a levelup.swf in the same "core" mount point.
#
# Both install paths (build\deploy.ps1 and build\dazip.ps1 -Install) and the
# packaging path use this file, so they cannot disagree about which movie to use.

function Get-DaoVariants {
    <#
    .SYNOPSIS
        The two level-up movie variants, one per attribute floor.
    .OUTPUTS
        Array of hashtables: Dir, Floor, Title, Blurb, Movie, Dazip.
    .DESCRIPTION
        Defined once so deploy.ps1 (build + package + install) and dazip.ps1
        (package one) cannot disagree about names or which movie is which.
    #>
    return @(
        @{ Dir = 'vanilla-starting'; Floor = 'Starting'
           Title = 'Interactive Respec - starting-value floor'
           Blurb = 'Attributes cannot be refunded below whatever character creation gave this character (10 plus its race and class adjustments).'
           Movie = 'ui\levelup.swf';        Dazip = 'respec_proto.dazip' }
        @{ Dir = 'vanilla-ten';      Floor = 'Ten'
           Title = 'Interactive Respec - flat 10 floor'
           Blurb = 'Every attribute can be refunded down to a flat 10, so a build can be rebuilt from scratch. This also refunds the race and class points.'
           Movie = 'ui\levelup_ten.swf';    Dazip = 'respec_proto_ten.dazip' }
    )
}

function Get-DaoLevelupMovie {
    <#
    .SYNOPSIS
        Picks the level-up movie to ship for the requested attribute floor.
    .OUTPUTS
        Hashtable: File (repo-relative), Base, Floor ('starting' or 'ten'),
        Note (warning text or $null).
    .DESCRIPTION
        Two movies can be built, one per attribute floor:

            ui\levelup.swf      starting-value floor
            ui\levelup_ten.swf  flat 10 floor

        A missing flat-10 build falls back to the starting-value one, because
        that is the accurate behaviour rather than the permissive one.
    #>
    param(
        [Parameter(Mandatory)] [string] $AddInsXml,
        [Parameter(Mandatory)] [string] $Root,
        [ValidateSet('starting', 'ten')]
        [string] $Floor = 'starting'
    )

    $base = 'vanilla'
    $name = 'levelup' + $(if ($Floor -eq 'ten') { '_ten' } else { '' })
    $rel  = "ui\$name.swf"

    if (Test-Path -LiteralPath (Join-Path $Root $rel)) {
        return @{ File = $rel; Base = $base; Floor = $Floor; Note = $null }
    }

    # Missing flat-10 build: ship the accurate starting-value one instead.
    if ($Floor -eq 'ten') {
        $fallback = 'ui\levelup.swf'
        if (Test-Path -LiteralPath (Join-Path $Root $fallback)) {
            return @{
                File  = $fallback
                Base  = $base
                Floor = 'starting'
                Note  = "$rel not found, so the starting-value floor is being shipped instead of the flat-10 one. Build it with: ui\build-movie.ps1 -Movie levelup -AttributeFloor Ten -Java <java>"
            }
        }
    }

    throw "$rel not found. Build it with: ui\build-movie.ps1 -Movie levelup -AttributeFloor $(if ($Floor -eq 'ten') { 'Ten' } else { 'Starting' })."
}

function Install-DaoMovieOverride {
    <#
    .SYNOPSIS
        Copies a patched UI movie to packages\core\override, where no addin can
        outrank it. Returns a line describing what it did.
    .PARAMETER Name
        Resource name the movie is installed as. Default: levelup
    #>
    param(
        [Parameter(Mandatory)] [string] $Docs,
        [Parameter(Mandatory)] [string] $Movie,
        [string] $Name = 'levelup'
    )

    $ovrDir  = Join-Path $Docs 'packages\core\override'
    $ovrFile = Join-Path $ovrDir "$Name.swf"
    if (-not (Test-Path -LiteralPath $ovrDir)) { New-Item -ItemType Directory -Force -Path $ovrDir | Out-Null }

    $line = "$Movie -> $ovrFile  (outranks every addin's $Name.swf)"
    if (Test-Path -LiteralPath $ovrFile) {
        $same = (Get-FileHash -LiteralPath $ovrFile).Hash -eq (Get-FileHash -LiteralPath $Movie).Hash
        if (-not $same -and -not (Test-Path -LiteralPath "$ovrFile.bak")) {
            Copy-Item -LiteralPath $ovrFile -Destination "$ovrFile.bak"
            $line = "$line  [previous file kept as $Name.swf.bak]"
        }
    }
    Copy-Item -LiteralPath $Movie -Destination $ovrFile -Force
    return $line
}
