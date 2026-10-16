<#
.SYNOPSIS
    Builds the "Interactive Respec - Skills Prototype" .dazip for Dragon Age: Origins.

.DESCRIPTION
    Packs a compiled script (.ncs) + the addin manifest into a .dazip that the
    game loads, so the script can be run in-game with:

        runscript respec1

    Produces this layout (matches a known-good console-addon mod):

        Manifest.xml
        Contents/addins/respec_proto/core/data/respec_proto_modcore.erf   (empty stub)
        Contents/addins/respec_proto/module/data/respec_proto_module.erf  (holds respec1.ncs)
        Contents/packages/core/data/respec_proto_package.erf              (empty stub)

    Scripts must be compiled to .ncs with the Dragon Age Toolset first; this
    script only packages them.

.PARAMETER Ncs
    Path to the compiled .ncs (default: ..\src\respec1.ncs).

.PARAMETER Out
    Output .dazip path (default: ..\build\respec_proto.dazip).

.EXAMPLE
    .\build-dazip.ps1
    .\build-dazip.ps1 -Ncs ..\src\respec1.ncs -Out ..\build\respec_proto.dazip
#>
[CmdletBinding()]
param(
    [string] $Ncs,
    [string] $Out
)

$ErrorActionPreference = 'Stop'
$root      = Split-Path -Parent $PSScriptRoot            # ..\ (project root)
$UID       = 'respec_proto'
$ScriptName = 'respec1'

if (-not $Ncs) { $Ncs = Join-Path $root "src\$ScriptName.ncs" }
if (-not $Out) { $Out = Join-Path $root 'build\respec_proto.dazip' }

# --- Validate the compiled script ------------------------------------------
if (-not (Test-Path -LiteralPath $Ncs)) {
    throw "Compiled script not found: '$Ncs'. Compile src\$ScriptName.nss with the Dragon Age Toolset first."
}
$ncsBytes = [System.IO.File]::ReadAllBytes($Ncs)
# Aurora NCS header is 13 bytes: "NCS V1.0" + 0x42 (size pseudo-opcode) + BE uint32 size.
# NOTE: the 0x42 byte is why any .ncs reads as "NCS V1.0B" in a text editor - it is NOT a
# DAO version marker; NWN/KotOR/NWN2/DAO/DA2 all share this header.
$magic = [System.Text.Encoding]::ASCII.GetString($ncsBytes, 0, [Math]::Min(8, $ncsBytes.Length))
if ($magic -ne 'NCS V1.0') {
    throw "'$Ncs' is not an Aurora .ncs (expected 'NCS V1.0', got '$magic')."
}
if ($ncsBytes[8] -ne 0x42) {
    throw "'$Ncs' has a bad size pseudo-opcode at offset 8 (expected 0x42, got 0x$($ncsBytes[8].ToString('X2')))."
}
$declared = ([uint32] $ncsBytes[9] * 16777216) + ([uint32] $ncsBytes[10] * 65536) + ([uint32] $ncsBytes[11] * 256) + [uint32] $ncsBytes[12]
if ($declared -ne $ncsBytes.Length) {
    Write-Warning "Declared size $declared differs from actual $($ncsBytes.Length) bytes."
}
Write-Host "Script   : $Ncs ($($ncsBytes.Length) bytes, 'NCS V1.0'+0x42, declared size $declared)"

# --- ERF writer (Unity-style "ERF V2.0" with UTF-16 names) ------------------
function New-DaoErf {
    param([System.Collections.IDictionary] $Entries)   # ordered: name -> byte[]

    $u32 = { param($v) [BitConverter]::GetBytes([uint32] $v) }
    $ms  = New-Object System.IO.MemoryStream

    # 16-byte signature "ERF V2.0" (UTF-16LE) + FileCount + 110 + 40 + -1
    $ms.Write([System.Text.Encoding]::Unicode.GetBytes('ERF V2.0'), 0, 16)
    $ms.Write((& $u32 $Entries.Count), 0, 4)
    $ms.Write((& $u32 110), 0, 4)
    $ms.Write((& $u32 40), 0, 4)
    $ms.Write([BitConverter]::GetBytes([uint32]::MaxValue), 0, 4)

    # 72-byte per-entry table: name (64, UTF-16, NUL-padded) + offset + size
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

    foreach ($name in $Entries.Keys) {
        $ms.Write($Entries[$name], 0, $Entries[$name].Length)
    }

    return $ms.ToArray()
}

# Order matters, so use an ordered dictionary.
$moduleEntries = [ordered] @{}
$moduleEntries["$ScriptName.ncs"] = $ncsBytes
$moduleErf = New-DaoErf -Entries $moduleEntries

# Core resource: ships the patched level-up screen (levelup.swf), exactly the
# resource name a known-good UI mod uses. Without it the core erf is a stub.
$coreEntries = [ordered] @{}
$swfPath = Join-Path $root 'ui\levelup.swf'
if (Test-Path -LiteralPath $swfPath) {
    $coreEntries['levelup.swf'] = [System.IO.File]::ReadAllBytes($swfPath)
    Write-Host "UI       : $swfPath -> levelup.swf ($($coreEntries['levelup.swf'].Length) bytes)"
} else {
    Write-Host "UI       : (no ui\levelup.swf - script-only build)"
}
$coreErf = New-DaoErf -Entries $coreEntries

# Empty stub erf (32 bytes: header only, FileCount = 0).
$stubErf = New-DaoErf -Entries ([ordered] @{})

# --- Stage the dazip tree --------------------------------------------------
$stage = Join-Path $root 'build\stage'
if (Test-Path -LiteralPath $stage) { Remove-Item -Recurse -Force $stage }

$paths = @{
    manifest = Join-Path $stage 'Manifest.xml'
    modcore  = Join-Path $stage "Contents\addins\$UID\core\data\${UID}_modcore.erf"
    module   = Join-Path $stage "Contents\addins\$UID\module\data\${UID}_module.erf"
    package  = Join-Path $stage "Contents\packages\core\data\${UID}_package.erf"
}
foreach ($p in $paths.Values) {
    New-Item -ItemType Directory -Force -Path (Split-Path -Parent $p) | Out-Null
}

Copy-Item -LiteralPath (Join-Path $root 'dazip\Manifest.xml') -Destination $paths.manifest
[System.IO.File]::WriteAllBytes($paths.modcore, $coreErf)
[System.IO.File]::WriteAllBytes($paths.module,  $moduleErf)
[System.IO.File]::WriteAllBytes($paths.package, $stubErf)

# --- Zip it up as the .dazip ----------------------------------------------
New-Item -ItemType Directory -Force -Path (Split-Path -Parent $Out) | Out-Null
if (Test-Path -LiteralPath $Out) { Remove-Item -Force $Out }

Add-Type -AssemblyName System.IO.Compression
Add-Type -AssemblyName System.IO.Compression.FileSystem
$zip = [System.IO.Compression.ZipFile]::Open($Out, [System.IO.Compression.ZipArchiveMode]::Create)
try {
    foreach ($p in $paths.Values) {
        $rel = $p.Substring($stage.Length).TrimStart('\').Replace('\', '/')
        [System.IO.Compression.ZipFileExtensions]::CreateEntryFromFile($zip, $p, $rel) | Out-Null
    }
} finally {
    $zip.Dispose()
}

Write-Host "Dazip    : $Out ($((Get-Item -LiteralPath $Out).Length) bytes)"
Write-Host ""
Write-Host "Install with DAO-Modmanager / DAModder, then in game open the console and run:"
Write-Host "    runscript $ScriptName"
