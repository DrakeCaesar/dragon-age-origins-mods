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

function Get-DaoLevelupMovie {
    <#
    .SYNOPSIS
        Picks the level-up movie to ship for the current addin state.
    .OUTPUTS
        Hashtable: File (repo-relative), Base ('vanilla' or 'ftg'),
        FtgEnabled (whether the addin is on), Note (warning text or $null).
    #>
    param(
        [Parameter(Mandatory)] [string] $AddInsXml,
        [Parameter(Mandatory)] [string] $Root,
        [switch] $ForceFtg
    )

    $ftgEnabled = $false
    if (Test-Path -LiteralPath $AddInsXml) {
        $item = [regex]::Match((Get-Content -LiteralPath $AddInsXml -Raw), '(?s)<AddInItem[^>]*UID="FTG_UIMOD"[^>]*>')
        if ($item.Success -and $item.Value -match 'Enabled="1"') { $ftgEnabled = $true }
    }

    if (-not ($ForceFtg -or $ftgEnabled)) {
        return @{ File = 'ui\levelup.swf'; Base = 'vanilla'; FtgEnabled = $false; Note = $null }
    }

    if (Test-Path -LiteralPath (Join-Path $Root 'ui\levelup_ftg.swf')) {
        return @{ File = 'ui\levelup_ftg.swf'; Base = 'ftg'; FtgEnabled = $ftgEnabled; Note = $null }
    }

    if ($ForceFtg) {
        throw "ui\levelup_ftg.swf not found. Build it with ui\build-movie.ps1 -Movie levelup_ftg."
    }
    return @{
        File       = 'ui\levelup.swf'
        Base       = 'vanilla'
        FtgEnabled = $true
        Note       = "FtG UI Mod is enabled but ui\levelup_ftg.swf is missing, so the vanilla-based movie is being shipped and that mod's level-up changes will be hidden. Build it with: ui\build-movie.ps1 -Movie levelup_ftg -Java <java>"
    }
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
