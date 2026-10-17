<#
.SYNOPSIS
    One-shot deploy for the Interactive Respec mod: builds the addin,
    refreshes its resources and (re)registers it.

.DESCRIPTION
    Everything needed to get a change into the game, in one command:

      1. rebuilds the module erf from the newest Toolset-compiled respec1.ncs
      2. rebuilds the core erf from ui\levelup.swf  (unless -NoUi)
      3. creates/refreshes the addin tree under
         <Documents>\BioWare\Dragon Age\AddIns\<UID>\
      4. (re)writes this addin's <AddInItem> in AddIns.xml, taken verbatim from
         dazip\Manifest.xml, so target/description changes always take effect
      5. backs up AddIns.xml before touching it, and verifies it still parses

    Safe to run repeatedly. Refuses to run while the game is open, since DAO
    rewrites its state on exit.

.PARAMETER Ncs
    Explicit path to a compiled .ncs. Default: newest Toolset export found
    under AddIns\*\module\override\toolsetexport\respec1.ncs.

.PARAMETER NoUi
    Skip the core erf / level-up UI; deploy the script only.

.EXAMPLE
    powershell -File build\deploy.ps1
#>
[CmdletBinding()]
param(
    [string] $Ncs,
    [switch] $NoUi,
    [switch] $Ftg
)

$ErrorActionPreference = 'Stop'

$root    = Split-Path -Parent $PSScriptRoot
$UID     = 'respec_proto'
$Script  = 'respec1'

$daDocs    = Join-Path $env:USERPROFILE 'Documents\BioWare\Dragon Age'
$addinDir  = Join-Path $daDocs "AddIns\$UID"
$addInsXml = Join-Path $daDocs 'Settings\AddIns.xml'
$manifest  = Join-Path $root 'dazip\Manifest.xml'

# ---------------------------------------------------------------- preflight
if (Get-Process DAOrigins -ErrorAction SilentlyContinue) {
    throw "Dragon Age is running. Close the game before deploying."
}
# The Toolset can hold an addin's erfs open while a project is loaded, which
# makes the write below fail with a sharing violation. Test the files rather
# than the process: having the Toolset open is fine as long as it is not
# holding anything we need to replace.
foreach ($p in @(
    (Join-Path $daDocs "AddIns\$UID\module\data\$($UID)_module.erf"),
    (Join-Path $daDocs "AddIns\$UID\core\data\$($UID)_modcore.erf")
)) {
    if (-not (Test-Path -LiteralPath $p)) { continue }
    try {
        $fs = [System.IO.File]::Open($p, 'Open', 'ReadWrite', 'None')
        $fs.Close()
    } catch {
        throw "The Dragon Age Toolset is holding '$p' open. Close the Toolset (or its project) and deploy again."
    }
}
if (-not (Test-Path -LiteralPath $addInsXml)) { throw "AddIns.xml not found at '$addInsXml'." }
if (-not (Test-Path -LiteralPath $manifest))  { throw "Manifest not found at '$manifest'." }

# ------------------------------------------------- locate the compiled script
if (-not $Ncs) {
    # Prefer the Toolset's export where it sits inside our own addin, but NOT
    # under a folder the game mounts: module\override and core\override are live
    # mount points, so a loose respec1.ncs there is delivered a second time on
    # top of the copy in the module erf. _toolsetexport keeps it as a build
    # input the engine never reads.
    $candidates = @(
        (Join-Path $daDocs "AddIns\$UID\_toolsetexport\$Script.ncs"),
        (Join-Path $daDocs "AddIns\$UID\module\override\toolsetexport\$Script.ncs")
    )
    $exports = $candidates | Where-Object { Test-Path -LiteralPath $_ } | ForEach-Object { Get-Item -LiteralPath $_ }
    if (-not $exports) {
        $exports = Get-ChildItem -Path (Join-Path $daDocs 'AddIns') -Recurse -Filter "$Script.ncs" -ErrorAction SilentlyContinue |
                   Where-Object { $_.FullName -like '*toolsetexport*' } |
                   Sort-Object LastWriteTime -Descending
    }
    if (-not $exports) {
        throw "No Toolset export of '$Script.ncs' found under '$daDocs\AddIns'. Compile it in the Toolset first, or pass -Ncs."
    }
    $Ncs = ($exports | Sort-Object LastWriteTime -Descending | Select-Object -First 1).FullName
}
if (-not (Test-Path -LiteralPath $Ncs)) { throw "Compiled script not found: '$Ncs'." }

$ncsBytes = [System.IO.File]::ReadAllBytes($Ncs)
# 13-byte Aurora header: "NCS V1.0" + 0x42 (size pseudo-opcode) + BE uint32 size.
$magic = [System.Text.Encoding]::ASCII.GetString($ncsBytes, 0, [Math]::Min(8, $ncsBytes.Length))
if ($magic -ne 'NCS V1.0')  { throw "'$Ncs' is not an Aurora .ncs (magic '$magic')." }
if ($ncsBytes[8] -ne 0x42)  { throw "'$Ncs' has a bad size opcode at offset 8." }
$declared = ([uint32] $ncsBytes[9] * 16777216) + ([uint32] $ncsBytes[10] * 65536) + ([uint32] $ncsBytes[11] * 256) + [uint32] $ncsBytes[12]
if ($declared -ne $ncsBytes.Length) { Write-Warning "Declared size $declared != actual $($ncsBytes.Length)." }

Write-Host "Script   : $Ncs"
Write-Host "           $($ncsBytes.Length) bytes, compiled $((Get-Item -LiteralPath $Ncs).LastWriteTime.ToString('HH:mm:ss'))"

# ------------------------------------------------------------- ERF writer
function New-DaoErf {
    param([System.Collections.IDictionary] $Entries)
    $ms = New-Object System.IO.MemoryStream
    $ms.Write([System.Text.Encoding]::Unicode.GetBytes('ERF V2.0'), 0, 16)
    $ms.Write([BitConverter]::GetBytes([uint32] $Entries.Count), 0, 4)
    $ms.Write([BitConverter]::GetBytes([uint32] 110), 0, 4)
    $ms.Write([BitConverter]::GetBytes([uint32] 40), 0, 4)
    $ms.Write([BitConverter]::GetBytes([uint32]::MaxValue), 0, 4)

    $dataOffset = 32 + 72 * $Entries.Count
    foreach ($name in $Entries.Keys) {
        $nameBuf = New-Object byte[] 64
        $enc = [System.Text.Encoding]::Unicode.GetBytes([string] $name)
        [Array]::Copy($enc, $nameBuf, [Math]::Min($enc.Length, 64))
        $ms.Write($nameBuf, 0, 64)
        $ms.Write([BitConverter]::GetBytes([uint32] $dataOffset), 0, 4)
        $ms.Write([BitConverter]::GetBytes([uint32] $Entries[$name].Length), 0, 4)
        $dataOffset += $Entries[$name].Length
    }
    foreach ($name in $Entries.Keys) { $ms.Write($Entries[$name], 0, $Entries[$name].Length) }
    return $ms.ToArray()
}

# ------------------------------------------------------------ 1. one addin
# Both halves live in one addin, the way no_helmet_hack and chef_bodini_itupg
# do it: the addin's own core\ and module\ trees are mounted by their folder
# names, while ExtendedModuleUID only says which module the addin belongs to.
# That matters because the game lists one entry per AddInItem, and a split
# layout showed up as a second "Interactive Respec (UI)" entry.
$UID = 'respec_proto'

$moduleDir = Join-Path $daDocs "AddIns\$UID\module\data"
New-Item -ItemType Directory -Force -Path $moduleDir | Out-Null

$moduleEntries = [ordered] @{}
$moduleEntries["$Script.ncs"] = $ncsBytes

$spErf = Join-Path $moduleDir "$($UID)_module.erf"
[System.IO.File]::WriteAllBytes($spErf, (New-DaoErf -Entries $moduleEntries))
Write-Host "Script   -> $spErf  (target: Single Player)"

# module\override is a live mount point, so anything the Toolset drops into
# module\override\toolsetexport is delivered a second time on top of the erf.
# Fold it into _toolsetexport (never mounted) and remove the mounted copy.
$mountedExport = Join-Path $daDocs "AddIns\$UID\module\override\toolsetexport"
if (Test-Path -LiteralPath $mountedExport) {
    $safeExport = Join-Path $daDocs "AddIns\$UID\_toolsetexport"
    New-Item -ItemType Directory -Force -Path $safeExport | Out-Null
    Get-ChildItem -LiteralPath $mountedExport -File | ForEach-Object {
        Copy-Item -LiteralPath $_.FullName -Destination (Join-Path $safeExport $_.Name) -Force
    }
    Remove-Item -LiteralPath $mountedExport -Recurse -Force
    Write-Host "Cleanup  : module\override\toolsetexport is a mount point (duplicate script) - moved to _toolsetexport"
}

# The Toolset writes module\<uid>.cif into the addin. That file carries the
# project's module metadata, including "Script = module_core", which registers
# the addin as a module with its own event dispatch. With that in place the
# engine keeps two copies of the chargen creature state, so a chargen message is
# applied twice -- visible as an attribute moving 2 while our own counter moves
# 1. The game does not need the cif (the module script is merged from the erf),
# so keep it as a build artefact outside the mount tree instead of deleting it.
$mountedCif = Join-Path $daDocs "AddIns\$UID\module\$($UID).cif"
if (Test-Path -LiteralPath $mountedCif) {
    $safeExport = Join-Path $daDocs "AddIns\$UID\_toolsetexport"
    New-Item -ItemType Directory -Force -Path $safeExport | Out-Null
    Move-Item -LiteralPath $mountedCif -Destination (Join-Path $safeExport "$($UID).cif") -Force
    Write-Host "Cleanup  : moved module\$($UID).cif out of the mount tree (it registers a module event script)"
}

# The second addin of the old two-addin layout is gone; drop it so the game does
# not keep listing it. Its content is rebuilt into the addin above and below.
$staleUi = Join-Path $daDocs 'AddIns\respec_proto_ui'
if (Test-Path -LiteralPath $staleUi) {
    Remove-Item -Recurse -Force $staleUi
    Write-Host "Cleanup  : removed the old second addin $staleUi"
}

# --------------------------------------------------------- 2. UI addin
# One movie is patched: the level-up screen itself, which is what makes an
# existing build editable once the screen is open. Which base movie it is layered
# on is decided by build\ui-base.ps1, which dazip.ps1 shares -- FtG UI Mod ships
# its own levelup.swf in the same "core" mount point, so the choice has to be
# made at install time and both paths must agree. -Ftg forces the FtG base.
. (Join-Path $PSScriptRoot 'ui-base.ps1')
$uiBase = Get-DaoLevelupMovie -AddInsXml $addInsXml -Root $root -ForceFtg:$Ftg
$uiFile = $uiBase.File
if ($uiBase.Note) { Write-Warning $uiBase.Note }
elseif ($uiBase.Base -eq 'ftg') { Write-Host "UI       : FtG UI Mod is enabled -> building on its level-up movie" }
else { Write-Host "UI       : FtG UI Mod is not enabled -> using the vanilla-based movie" }

$uiMovies = @(
    @{ Name = 'levelup';   File = $uiFile }
)
if ($NoUi) {
    Write-Host "UI       : skipped (-NoUi)"
} else {
    $coreEntries = [ordered] @{}
    foreach ($m in $uiMovies) {
        $path = Join-Path $root $m.File
        if (-not (Test-Path -LiteralPath $path)) {
            throw "$($m.File) not found. Build it with ui\build-movie.ps1 -Movie $($m.Name), or pass -NoUi."
        }
        $bytes = [System.IO.File]::ReadAllBytes($path)
        $coreEntries["$($m.Name).swf"] = $bytes
        Write-Host "UI       : $($m.File) -> $($m.Name).swf  ($($bytes.Length) bytes)"
    }

    $uiDir = Join-Path $daDocs "AddIns\$UID\core\data"
    New-Item -ItemType Directory -Force -Path $uiDir | Out-Null
    $uiErf = Join-Path $uiDir "$($UID)_modcore.erf"
    [System.IO.File]::WriteAllBytes($uiErf, (New-DaoErf -Entries $coreEntries))
    Write-Host "UI       -> $uiErf  (same addin, core tree)"

    # The same movie also goes to the core override folder, because the erfs are
    # not enough: with FtG UI Mod enabled its levelup.swf is the one the game
    # uses, no matter what AddIns.xml says about priority or order. Resources
    # under packages\core\override are merged after the addins, so this copy
    # cannot be outranked, and it is always the same build as the erfs above.
    Write-Host "Override : $(Install-DaoLevelupOverride -Docs $daDocs -Movie (Join-Path $root $uiFile))"
}

# --------------------------------------------------------- 4. register
$items = [regex]::Matches((Get-Content -LiteralPath $manifest -Raw), '(?s)<AddInItem\b.*?</AddInItem>')
if ($items.Count -eq 0) { throw "No <AddInItem> found in '$manifest'." }

$backup = "$addInsXml.bak"
if (-not (Test-Path -LiteralPath $backup)) { Copy-Item -LiteralPath $addInsXml -Destination $backup }

$text = [System.IO.File]::ReadAllText($addInsXml)

# UIDs this mod used to register but no longer ships. Without this the orphaned
# entry would stay in AddIns.xml and the game would keep listing a second addin
# whose folder no longer exists.
foreach ($orphan in @('respec_proto_ui')) {
    $pattern = '(?s)\s*<AddInItem[^>]*UID="' + [regex]::Escape($orphan) + '".*?</AddInItem>'
    if ([regex]::IsMatch($text, $pattern)) {
        $text = [regex]::Replace($text, $pattern, '')
        Write-Host "Register : removed obsolete entry $orphan"
    }
}

foreach ($m in $items) {
    $item   = $m.Value
    $uid    = [regex]::Match($item, 'UID="([^"]*)"').Groups[1].Value
    $target = [regex]::Match($item, 'ExtendedModuleUID="([^"]*)"').Groups[1].Value

    $pattern = '(?s)\s*<AddInItem[^>]*UID="' + [regex]::Escape($uid) + '".*?</AddInItem>'
    $was     = [regex]::IsMatch($text, $pattern)
    $text    = [regex]::Replace($text, $pattern, '')
    if ($text -notmatch '</AddInsList>') { throw "AddIns.xml has no </AddInsList> root element." }
    $text    = $text -replace '</AddInsList>', ("`t" + $item + "`r`n</AddInsList>")

    if ($was) { $verb = 'updated' } else { $verb = 'added' }
    Write-Host "Register : $uid  ExtendedModuleUID='$target'  ($verb)"
}
[System.IO.File]::WriteAllText($addInsXml, $text)

# Verify it still parses before declaring success.
$xml = New-Object System.Xml.XmlDocument
$xml.Load($addInsXml)
$count = $xml.DocumentElement.ChildNodes.Count
Write-Host ""
Write-Host "Deployed. Load a save and run:  runscript $Script"
