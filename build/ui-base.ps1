# Which level-up movie to ship, and why it has to be decided at install time.
#
# FtG UI Mod ships its own levelup.swf in the same "core" mount point as this
# mod, and the two movies are different assets: their ActionScript differs (book
# menu scaling) and so does the art. One resource name cannot hold both, and the
# engine has no way to pick between them at run time, so the choice can only be
# made outside the game. Doing it here means one recipe covers both cases:
#
#   FtG UI Mod enabled  -> layer this mod's patches onto FtG's movie, so the
#                          screen keeps that mod's changes and gains ours
#   FtG UI Mod disabled -> layer them onto the vanilla movie
#
# Both install paths (build\deploy.ps1 and build\dazip.ps1 -Install) and the
# packaging path use this, so they cannot disagree about which movie to use.

function Get-DaoVariants {
    <#
    .SYNOPSIS
        The four level-up movie variants: two movie bases times two floors.
    .OUTPUTS
        Array of hashtables: Dir, Ftg, Floor, Title, Blurb, Movie, Dazip.
    .DESCRIPTION
        Defined once so deploy.ps1 (build + package + install) and dazip.ps1
        (package one) cannot disagree about names or which movie is which.
    #>
    return @(
        @{ Dir = 'vanilla-starting'; Ftg = $false; Floor = 'Starting'
           Title = 'Interactive Respec - vanilla UI, starting-value floor'
           Blurb = 'Use this with the unmodded level-up screen. Attributes cannot be refunded below whatever character creation gave this character (10 plus its race and class adjustments).'
           Movie = 'ui\levelup.swf';        Dazip = 'respec_proto.dazip' }
        @{ Dir = 'vanilla-ten';      Ftg = $false; Floor = 'Ten'
           Title = 'Interactive Respec - vanilla UI, flat 10 floor'
           Blurb = 'Use this with the unmodded level-up screen. Every attribute can be refunded down to a flat 10, so a build can be rebuilt from scratch. This also refunds the race and class points.'
           Movie = 'ui\levelup_ten.swf';    Dazip = 'respec_proto_ten.dazip' }
        @{ Dir = 'ftg-starting';     Ftg = $true;  Floor = 'Starting'
           Title = 'Interactive Respec - FtG UI Mod, starting-value floor'
           Blurb = 'ONLY for players running FtG UI Mod. Attributes cannot be refunded below whatever character creation gave this character (10 plus its race and class adjustments).'
           Movie = 'ui\levelup_ftg.swf';    Dazip = 'respec_proto_ftg.dazip' }
        @{ Dir = 'ftg-ten';          Ftg = $true;  Floor = 'Ten'
           Title = 'Interactive Respec - FtG UI Mod, flat 10 floor'
           Blurb = 'ONLY for players running FtG UI Mod. Every attribute can be refunded down to a flat 10, so a build can be rebuilt from scratch. This also refunds the race and class points.'
           Movie = 'ui\levelup_ftg_ten.swf'; Dazip = 'respec_proto_ftg_ten.dazip' }
    )
}

function Get-DaoLevelupMovie {
    <#
    .SYNOPSIS
        Picks the level-up movie to ship for the current addin state.
    .OUTPUTS
        Hashtable: File (repo-relative), Base ('vanilla' or 'ftg'),
        Floor ('starting' or 'ten'), Note (warning text or $null).
    .DESCRIPTION
        Four movies can be built, from the two movie bases times the two
        attribute floors:

            ui\levelup.swf          vanilla base, starting-value floor
            ui\levelup_ten.swf      vanilla base, flat 10 floor
            ui\levelup_ftg.swf      FtG base,     starting-value floor
            ui\levelup_ftg_ten.swf  FtG base,     flat 10 floor

        The vanilla base is the default: this mod now deploys against the
        unmodded level-up screen, so the replaced UI mod's movie is not used
        even when that add-in is still installed. -ForceFtg opts into the FtG
        base explicitly for anyone still running it.

        A missing flat-10 build falls back to the starting-value one, because
        that is the accurate behaviour rather than the permissive one.
    #>
    param(
        [Parameter(Mandatory)] [string] $AddInsXml,
        [Parameter(Mandatory)] [string] $Root,
        [switch] $ForceFtg,
        [ValidateSet('starting', 'ten')]
        [string] $Floor = 'starting'
    )

    # Deliberately not keyed off whether FtG UI Mod is installed or enabled: its
    # UI may have been replaced by another mod, in which case the vanilla movie
    # is the correct base. Only an explicit -ForceFtg selects FtG's.
    $useFtg = $ForceFtg.IsPresent
    $base   = if ($useFtg) { 'ftg' } else { 'vanilla' }
    $name   = 'levelup' + $(if ($useFtg) { '_ftg' } else { '' }) + $(if ($Floor -eq 'ten') { '_ten' } else { '' })
    $rel    = "ui\$name.swf"

    if (Test-Path -LiteralPath (Join-Path $Root $rel)) {
        return @{ File = $rel; Base = $base; Floor = $Floor; Note = $null }
    }

    # Missing flat-10 build: ship the accurate starting-value one instead.
    if ($Floor -eq 'ten') {
        $fallback = 'ui\levelup' + $(if ($useFtg) { '_ftg' } else { '' }) + '.swf'
        if (Test-Path -LiteralPath (Join-Path $Root $fallback)) {
            return @{
                File  = $fallback
                Base  = $base
                Floor = 'starting'
                Note  = "$rel not found, so the starting-value floor is being shipped instead of the flat-10 one. Build it with: ui\build-movie.ps1 -Movie $name -AttributeFloor Ten -Java <java>"
            }
        }
    }

    throw "$rel not found. Build it with: ui\build-movie.ps1 -Movie $(if ($useFtg) { 'levelup_ftg' } else { 'levelup' }) -AttributeFloor $(if ($Floor -eq 'ten') { 'Ten' } else { 'Starting' })."
}

function Install-DaoLevelupOverride {
    <#
    .SYNOPSIS
        Copies a level-up movie to packages\core\override, where no addin can
        outrank it. Returns a line describing what it did.
    #>
    param(
        [Parameter(Mandatory)] [string] $Docs,
        [Parameter(Mandatory)] [string] $Movie
    )

    $ovrDir  = Join-Path $Docs 'packages\core\override'
    $ovrFile = Join-Path $ovrDir 'levelup.swf'
    if (-not (Test-Path -LiteralPath $ovrDir)) { New-Item -ItemType Directory -Force -Path $ovrDir | Out-Null }

    $line = "$Movie -> $ovrFile  (outranks every addin's levelup.swf)"
    if (Test-Path -LiteralPath $ovrFile) {
        $same = (Get-FileHash -LiteralPath $ovrFile).Hash -eq (Get-FileHash -LiteralPath $Movie).Hash
        if (-not $same -and -not (Test-Path -LiteralPath "$ovrFile.bak")) {
            Copy-Item -LiteralPath $ovrFile -Destination "$ovrFile.bak"
            $line = "$line  [previous file kept as levelup.swf.bak]"
        }
    }
    Copy-Item -LiteralPath $Movie -Destination $ovrFile -Force
    return $line
}
