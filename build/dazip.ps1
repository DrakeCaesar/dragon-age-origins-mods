<#
.SYNOPSIS
    Builds, installs and uninstalls the Interactive Respec .dazip.

.DESCRIPTION
    One script for the whole packaging story.

    Build (default) produces a .dazip containing both addins the mod needs:

        Manifest.xml
        Contents/addins/respec_proto/module/data/respec_proto_module.erf
            the compiled respec1.ncs, extending "Single Player" so that
            `runscript respec1` resolves
        Contents/addins/respec_proto_ui/core/data/respec_proto_ui_modcore.erf
            the patched level-up screen, extending "core", which is where the
            level-up resource actually lives
        Contents/packages/*/data/*_package.erf
            empty package stubs, for mod-manager compatibility

    Two addins are required because a script addin and a UI addin need
    different ExtendedModuleUID values, and one AddInItem can only carry one.

    Install extracts every addin under Contents/addins/ and registers every
    <AddInItem> from the dazip's own Manifest.xml, so the registration can
    never drift from the manifest. AddIns.xml is backed up before each change.

    The .ncs must be compiled first with the Dragon Age Toolset; this script
    only packages. By default it uses the newest Toolset export, so the usual
    loop is just: compile -> .\dazip.ps1 -Install

.PARAMETER Ncs
    Compiled script to package. Default: newest respec1.ncs exported by the
    Toolset. Pass -Ncs to override.

.PARAMETER Out
    Output .dazip path. Default: build\respec_proto.dazip

.PARAMETER Install
    After building, install the dazip into the game.

.PARAMETER Uninstall
    Remove the addin folders and their AddIns.xml registrations. Does not build.

.PARAMETER NoUi
    Build a script-only dazip, omitting the level-up UI addin.

.EXAMPLE
    .\dazip.ps1                     # build only
    .\dazip.ps1 -Install            # build and install
    .\dazip.ps1 -Uninstall          # remove the addin
#>
[CmdletBinding()]
param(
    [string] $Ncs,
    [string] $Out,
    [switch] $Install,
    [switch] $Uninstall,
    [switch] $NoUi
)

$ErrorActionPreference = 'Stop'

$root       = Split-Path -Parent $PSScriptRoot            # project root
$ScriptName = 'respec1'
$UID_SP     = 'respec_proto'                              # script half
$UID_UI     = 'respec_proto_ui'                           # UI half

$manifest = Join-Path $root 'dazip\Manifest.xml'
if (-not $Out) { $Out = Join-Path $root 'build\respec_proto.dazip' }

$daDocs    = Join-Path $env:USERPROFILE 'Documents\BioWare\Dragon Age'
$addInsXml = Join-Path $daDocs 'Settings\AddIns.xml'

if (-not (Test-Path -LiteralPath $manifest)) { throw "Manifest not found: '$manifest'." }

Add-Type -AssemblyName System.IO.Compression
Add-Type -AssemblyName System.IO.Compression.FileSystem

# ---------------------------------------------------------------- helpers
function New-DaoErf {
    # ERF V2.0 with UTF-16 names: 16-byte signature (UTF-16), FileCount, 110,
    # 40, 0xFFFFFFFF, then 72-byte entries (64-byte NUL-padded UTF-16 name,
    # u32 dataOffset, u32 dataSize), then the concatenated data.
    param([System.Collections.IDictionary] $Entries)

    $u32 = { param($v) [BitConverter]::GetBytes([uint32] $v) }
    $ms  = New-Object System.IO.MemoryStream

    $ms.Write([System.Text.Encoding]::Unicode.GetBytes('ERF V2.0'), 0, 16)
    $ms.Write((& $u32 $Entries.Count), 0, 4)
    $ms.Write((& $u32 110), 0, 4)
    $ms.Write((& $u32 40), 0, 4)
    $ms.Write([BitConverter]::GetBytes([uint32]::MaxValue), 0, 4)

    $dataOffset = 32 + 72 * $Entries.Count
    foreach ($name in $Entries.Keys) {
        $nameBuf = New-Object byte[] 64
        $encoded = [System.Text.Encoding]::Unicode.GetBytes([string] $name)
        [Array]::Copy($encoded, $nameBuf, [Math]::Min($encoded.Length, 64))
        $ms.Write($nameBuf, 0, 64)
        $ms.Write((& $u32 $dataOffset), 0, 4)
        $ms.Write((& $u32 $Entries[$name].Length), 0, 4)
        $dataOffset += $Entries[$name].Length
    }
    foreach ($name in $Entries.Keys) { $ms.Write($Entries[$name], 0, $Entries[$name].Length) }

    return $ms.ToArray()
}

function Assert-GameNotRunning {
    # The game rewrites AddIns.xml on exit, so never touch it while it runs.
    if (Get-Process DAOrigins -ErrorAction SilentlyContinue) {
        throw "Dragon Age is running. Close the game first."
    }
}

function Get-ManifestItems {
    param([string] $Xml)
    return [regex]::Matches($Xml, '(?s)<AddInItem\b.*?</AddInItem>')
}

function Remove-AddInEntry {
    param([string] $Path, [string] $Uid)
    $text    = [System.IO.File]::ReadAllText($Path)
    $pattern = '(?s)\s*<AddInItem[^>]*UID="' + [regex]::Escape($Uid) + '".*?</AddInItem>'
    $new     = [regex]::Replace($text, $pattern, '')
    if ($new -ne $text) { [System.IO.File]::WriteAllText($Path, $new); return $true }
    return $false
}

function Assert-NcsHeader {
    # Aurora NCS header is 13 bytes: "NCS V1.0" + 0x42 (size pseudo-opcode) +
    # big-endian uint32 size. The 0x42 is why a .ncs reads as "NCS V1.0B" in a
    # text editor -- it is NOT a version marker; NWN/KotOR/NWN2/DAO/DA2 share it.
    param([byte[]] $Bytes, [string] $Path)

    $magic = [System.Text.Encoding]::ASCII.GetString($Bytes, 0, [Math]::Min(8, $Bytes.Length))
    if ($magic -ne 'NCS V1.0') {
        throw "'$Path' is not an Aurora .ncs (expected 'NCS V1.0', got '$magic')."
    }
    if ($Bytes[8] -ne 0x42) {
        throw "'$Path' has a bad size pseudo-opcode at offset 8 (got 0x$($Bytes[8].ToString('X2')))."
    }
    $declared = ([uint32] $Bytes[9] * 16777216) + ([uint32] $Bytes[10] * 65536) + ([uint32] $Bytes[11] * 256) + [uint32] $Bytes[12]
    if ($declared -ne $Bytes.Length) {
        Write-Warning "Declared size $declared differs from actual $($Bytes.Length) bytes."
    }
    return $declared
}

# ===========================================================================
#  UNINSTALL
# ===========================================================================
if ($Uninstall) {
    Assert-GameNotRunning
    if (-not (Test-Path -LiteralPath $addInsXml)) { throw "AddIns.xml not found at '$addInsXml'." }

    $backup = "$addInsXml.bak"
    if (-not (Test-Path -LiteralPath $backup)) { Copy-Item -LiteralPath $addInsXml -Destination $backup }
    Copy-Item -LiteralPath $addInsXml -Destination "$addInsXml.bak2" -Force

    foreach ($uid in @($UID_SP, $UID_UI)) {
        $removed = Remove-AddInEntry -Path $addInsXml -Uid $uid
        $dir     = Join-Path $daDocs "AddIns\$uid"
        if (Test-Path -LiteralPath $dir) { Remove-Item -Recurse -Force $dir }
        Write-Host "Uninstalled '$uid'  (entry removed: $removed)"
    }
    Write-Host ""
    Write-Host "Backups: AddIns.xml.bak, AddIns.xml.bak2"
    return
}

# ===========================================================================
#  BUILD
# ===========================================================================

# ------------------------------------------------- locate the compiled script
if (-not $Ncs) {
    $exports = Get-ChildItem -Path (Join-Path $daDocs 'AddIns') -Recurse -Filter "$ScriptName.ncs" -ErrorAction SilentlyContinue |
               Where-Object { $_.FullName -like '*toolsetexport*' } |
               Sort-Object LastWriteTime -Descending
    if (-not $exports) {
        throw "No Toolset export of '$ScriptName.ncs' found under '$daDocs\AddIns'. Compile it in the Toolset first, or pass -Ncs."
    }
    $Ncs = $exports[0].FullName
}
if (-not (Test-Path -LiteralPath $Ncs)) { throw "Compiled script not found: '$Ncs'." }

$ncsBytes = [System.IO.File]::ReadAllBytes($Ncs)
$declared = Assert-NcsHeader -Bytes $ncsBytes -Path $Ncs
Write-Host "Script   : $Ncs"
Write-Host "           $($ncsBytes.Length) bytes, compiled $((Get-Item -LiteralPath $Ncs).LastWriteTime.ToString('HH:mm:ss'))"

# ------------------------------------------------------------ build the erfs
$moduleErf = New-DaoErf -Entries ([ordered] @{ "$ScriptName.ncs" = $ncsBytes })
$stubErf   = New-DaoErf -Entries ([ordered] @{})          # 32 bytes, header only

$uiErf  = $null
$uiList = @(
    @{ Name = 'levelup';   File = 'ui\levelup.swf' },
    @{ Name = 'portraits'; File = 'ui\portraits.swf' }
)
if ($NoUi) {
    Write-Host "UI       : skipped (-NoUi)"
} else {
    $coreEntries = [ordered] @{}
    foreach ($m in $uiList) {
        $path = Join-Path $root $m.File
        if (-not (Test-Path -LiteralPath $path)) {
            throw "$($m.File) not found. Build it with ui\build-movie.ps1 -Movie $($m.Name), or pass -NoUi."
        }
        $bytes = [System.IO.File]::ReadAllBytes($path)
        $coreEntries["$($m.Name).swf"] = $bytes
        Write-Host "UI       : $($m.File) -> $($m.Name).swf  ($($bytes.Length) bytes)"
    }
    $uiErf = New-DaoErf -Entries $coreEntries
}

# ------------------------------------------------------------- stage + zip
$stage = Join-Path $root 'build\stage'
if (Test-Path -LiteralPath $stage) { Remove-Item -Recurse -Force $stage }

$files = [ordered] @{}
$files['Manifest.xml'] = Join-Path $stage 'Manifest.xml'
$files["Contents/addins/$UID_SP/module/data/${UID_SP}_module.erf"]      = Join-Path $stage "Contents\addins\$UID_SP\module\data\${UID_SP}_module.erf"
$files["Contents/packages/$UID_SP/data/${UID_SP}_package.erf"]          = Join-Path $stage "Contents\packages\$UID_SP\data\${UID_SP}_package.erf"
if ($uiErf) {
    $files["Contents/addins/$UID_UI/core/data/${UID_UI}_modcore.erf"]   = Join-Path $stage "Contents\addins\$UID_UI\core\data\${UID_UI}_modcore.erf"
    $files["Contents/packages/$UID_UI/data/${UID_UI}_package.erf"]       = Join-Path $stage "Contents\packages\$UID_UI\data\${UID_UI}_package.erf"
}

foreach ($dest in $files.Values) {
    New-Item -ItemType Directory -Force -Path (Split-Path -Parent $dest) | Out-Null
}

Copy-Item -LiteralPath $manifest -Destination $files['Manifest.xml']
[System.IO.File]::WriteAllBytes($files["Contents/addins/$UID_SP/module/data/${UID_SP}_module.erf"], $moduleErf)
[System.IO.File]::WriteAllBytes($files["Contents/packages/$UID_SP/data/${UID_SP}_package.erf"], $stubErf)
if ($uiErf) {
    [System.IO.File]::WriteAllBytes($files["Contents/addins/$UID_UI/core/data/${UID_UI}_modcore.erf"], $uiErf)
    [System.IO.File]::WriteAllBytes($files["Contents/packages/$UID_UI/data/${UID_UI}_package.erf"], $stubErf)
}

New-Item -ItemType Directory -Force -Path (Split-Path -Parent $Out) | Out-Null
if (Test-Path -LiteralPath $Out) { Remove-Item -Force $Out }

$zip = [System.IO.Compression.ZipFile]::Open($Out, [System.IO.Compression.ZipArchiveMode]::Create)
try {
    foreach ($entryName in $files.Keys) {
        [System.IO.Compression.ZipFileExtensions]::CreateEntryFromFile($zip, $files[$entryName], $entryName) | Out-Null
        Write-Host "  + $entryName"
    }
} finally {
    $zip.Dispose()
}
Write-Host "Dazip    : $Out ($((Get-Item -LiteralPath $Out).Length) bytes)"

# ---------------------------------------------------------------- install
if (-not $Install) {
    Write-Host ""
    Write-Host "Install with:  .\dazip.ps1 -Install"
    return
}

Assert-GameNotRunning
if (-not (Test-Path -LiteralPath $addInsXml)) { throw "AddIns.xml not found at '$addInsXml'." }

$backup = "$addInsXml.bak"
if (-not (Test-Path -LiteralPath $backup)) { Copy-Item -LiteralPath $addInsXml -Destination $backup }
Copy-Item -LiteralPath $addInsXml -Destination "$addInsXml.bak2" -Force

$zip = [System.IO.Compression.ZipFile]::OpenRead($Out)
try {
    $manifestEntry = $zip.GetEntry('Manifest.xml')
    if (-not $manifestEntry) { throw "Manifest.xml missing from '$Out'." }
    $reader = New-Object System.IO.StreamReader($manifestEntry.Open())
    $manifestXml = $reader.ReadToEnd()
    $reader.Dispose()

    $items = Get-ManifestItems -Xml $manifestXml
    if ($items.Count -eq 0) { throw "No <AddInItem> found in the dazip manifest." }

    foreach ($item in $items) {
        $uid = [regex]::Match($item.Value, 'UID="([^"]*)"').Groups[1].Value
        if (-not $uid) { throw "An <AddInItem> has no UID." }

        # --- extract this addin's tree
        $prefix   = "Contents/addins/$uid/"
        $addinDir = Join-Path $daDocs "AddIns\$uid"
        if (Test-Path -LiteralPath $addinDir) { Remove-Item -Recurse -Force $addinDir }

        $extracted = 0
        foreach ($entry in $zip.Entries) {
            if ($entry.FullName -notlike "$prefix*") { continue }
            $rel = $entry.FullName.Substring($prefix.Length)
            if ([string]::IsNullOrEmpty($rel)) { continue }
            $dest = Join-Path $addinDir ($rel -replace '/', '\')
            New-Item -ItemType Directory -Force -Path (Split-Path -Parent $dest) | Out-Null
            [System.IO.Compression.ZipFileExtensions]::ExtractToFile($entry, $dest, $true)
            Write-Host "  extracted: $uid/$rel ($($entry.Length) bytes)"
            $extracted++
        }
        if ($extracted -eq 0) { throw "No files found under '$prefix' in '$Out'." }

        # --- register, replacing any previous entry
        Remove-AddInEntry -Path $addInsXml -Uid $uid | Out-Null
        $text = [System.IO.File]::ReadAllText($addInsXml)
        if ($text -notmatch '</AddInsList>') { throw "AddIns.xml has no </AddInsList> root element." }
        $text = $text -replace '</AddInsList>', ("`t" + $item.Value + "`r`n</AddInsList>")
        [System.IO.File]::WriteAllText($addInsXml, $text)
        Write-Host "  registered: $uid"
    }
} finally {
    $zip.Dispose()
}

# Verify AddIns.xml still parses before declaring success.
$xml = New-Object System.Xml.XmlDocument
$xml.Load($addInsXml)

Write-Host ""
Write-Host "Installed. Load a save, open the console, and run:"
Write-Host "    runscript $ScriptName"
Write-Host ""
Write-Host "Backups: AddIns.xml.bak, AddIns.xml.bak2"
