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
    [switch] $NoUi
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
if (-not (Test-Path -LiteralPath $addInsXml)) { throw "AddIns.xml not found at '$addInsXml'." }
if (-not (Test-Path -LiteralPath $manifest))  { throw "Manifest not found at '$manifest'." }

# ------------------------------------------------- locate the compiled script
if (-not $Ncs) {
    $exports = Get-ChildItem -Path (Join-Path $daDocs 'AddIns') -Recurse -Filter "$Script.ncs" -ErrorAction SilentlyContinue |
               Where-Object { $_.FullName -like '*toolsetexport*' } |
               Sort-Object LastWriteTime -Descending
    if (-not $exports) {
        throw "No Toolset export of '$Script.ncs' found under '$daDocs\AddIns'. Compile it in the Toolset first, or pass -Ncs."
    }
    $Ncs = $exports[0].FullName
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

# --------------------------------------------------------- 1. script addin
# Must extend "Single Player" or the campaign never merges the module script.
$UID_SP = 'respec_proto'
$UID_UI = 'respec_proto_ui'

$spDir = Join-Path $daDocs "AddIns\$UID_SP\module\data"
New-Item -ItemType Directory -Force -Path $spDir | Out-Null

$moduleEntries = [ordered] @{}
$moduleEntries["$Script.ncs"] = $ncsBytes

$spErf = Join-Path $spDir "${UID_SP}_module.erf"
[System.IO.File]::WriteAllBytes($spErf, (New-DaoErf -Entries $moduleEntries))
Write-Host "Script   -> $spErf  (target: Single Player)"

# The script addin no longer ships UI resources. Drop any stale copy left from
# the earlier one-addin layout so nothing is mounted from the wrong target.
$staleCore = Join-Path $daDocs "AddIns\$UID_SP\core"
if (Test-Path -LiteralPath $staleCore) {
    Remove-Item -Recurse -Force $staleCore
    Write-Host "Cleanup  : removed stale $staleCore"
}

# --------------------------------------------------------- 2. UI addin
# One movie is patched: the level-up screen itself, which is what makes an
# existing build editable once the screen is open.
$uiMovies = @(
    @{ Name = 'levelup';   File = 'ui\levelup.swf' }
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

    $uiDir = Join-Path $daDocs "AddIns\$UID_UI\core\data"
    New-Item -ItemType Directory -Force -Path $uiDir | Out-Null
    $uiErf = Join-Path $uiDir "${UID_UI}_modcore.erf"
    [System.IO.File]::WriteAllBytes($uiErf, (New-DaoErf -Entries $coreEntries))
    Write-Host "UI       -> $uiErf  (target: core)"
}

# --------------------------------------------------------- 4. register
$items = [regex]::Matches((Get-Content -LiteralPath $manifest -Raw), '(?s)<AddInItem\b.*?</AddInItem>')
if ($items.Count -eq 0) { throw "No <AddInItem> found in '$manifest'." }

$backup = "$addInsXml.bak"
if (-not (Test-Path -LiteralPath $backup)) { Copy-Item -LiteralPath $addInsXml -Destination $backup }

$text = [System.IO.File]::ReadAllText($addInsXml)
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
