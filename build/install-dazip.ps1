<#
.SYNOPSIS
    Installs (or removes) the "Interactive Respec" prototype dazip into Dragon Age: Origins.

.DESCRIPTION
    A .dazip is just a zip. Installing means:
      1. extracting Contents/addins/<UID>/... into  <Documents>\BioWare\Dragon Age\AddIns\<UID>\
      2. adding the addin's <AddInItem> to                 ...\Settings\AddIns.xml

    The <AddInItem> written to AddIns.xml is taken verbatim from the dazip's own
    Manifest.xml, so the two can never drift apart.

    AddIns.xml is backed up before every change.

.PARAMETER Uninstall
    Remove the addin instead of installing it.

.PARAMETER Dazip
    Dazip to install (default: ..\build\respec_proto.dazip).

.EXAMPLE
    .\install-dazip.ps1
    .\install-dazip.ps1 -Uninstall
#>
[CmdletBinding()]
param(
    [switch] $Uninstall,
    [string] $Dazip
)

$ErrorActionPreference = 'Stop'

$root   = Split-Path -Parent $PSScriptRoot
$UID    = 'respec_proto'
if (-not $Dazip) { $Dazip = Join-Path $root 'build\respec_proto.dazip' }

$daDocs    = Join-Path $env:USERPROFILE 'Documents\BioWare\Dragon Age'
$addinDir  = Join-Path $daDocs "AddIns\$UID"
$addInsXml = Join-Path $daDocs 'Settings\AddIns.xml'

# The game rewrites AddIns.xml on exit, so never touch it while it runs.
if (Get-Process DAOrigins -ErrorAction SilentlyContinue) {
    throw "Dragon Age is running. Close the game before installing or uninstalling."
}
if (-not (Test-Path -LiteralPath $addInsXml)) {
    throw "AddIns.xml not found at '$addInsXml'."
}

function Remove-AddInEntry {
    param([string] $Path, [string] $Uid)
    $text = [System.IO.File]::ReadAllText($Path)
    $pattern = '(?s)\s*<AddInItem[^>]*UID="' + [regex]::Escape($Uid) + '".*?</AddInItem>'
    $new = [regex]::Replace($text, $pattern, '')
    if ($new -ne $text) { [System.IO.File]::WriteAllText($Path, $new); return $true }
    return $false
}

# Always back up first.
$backup = "$addInsXml.bak"
if (-not (Test-Path -LiteralPath $backup)) { Copy-Item -LiteralPath $addInsXml -Destination $backup }
Copy-Item -LiteralPath $addInsXml -Destination "$addInsXml.bak2" -Force

if ($Uninstall) {
    $removedEntry = Remove-AddInEntry -Path $addInsXml -Uid $UID
    if (Test-Path -LiteralPath $addinDir) { Remove-Item -Recurse -Force $addinDir }
    Write-Host "Uninstalled '$UID'."
    Write-Host "  AddIns.xml entry removed : $removedEntry"
    Write-Host "  AddIn folder removed     : $addinDir"
    exit 0
}

if (-not (Test-Path -LiteralPath $Dazip)) {
    throw "Dazip not found: '$Dazip'. Run build\build-dazip.ps1 first."
}

Add-Type -AssemblyName System.IO.Compression
Add-Type -AssemblyName System.IO.Compression.FileSystem

$zip = [System.IO.Compression.ZipFile]::OpenRead($Dazip)
try {
    # --- 1. extract the addin tree -----------------------------------------
    $prefix = "Contents/addins/$UID/"
    if (Test-Path -LiteralPath $addinDir) { Remove-Item -Recurse -Force $addinDir }

    $extracted = 0
    foreach ($entry in $zip.Entries) {
        if ($entry.FullName -notlike "$prefix*") { continue }
        $rel = $entry.FullName.Substring($prefix.Length)
        if ([string]::IsNullOrEmpty($rel)) { continue }
        $dest = Join-Path $addinDir ($rel -replace '/', '\')
        New-Item -ItemType Directory -Force -Path (Split-Path -Parent $dest) | Out-Null
        [System.IO.Compression.ZipFileExtensions]::ExtractToFile($entry, $dest, $true)
        Write-Host "  extracted: $rel ($($entry.Length) bytes)"
        $extracted++
    }
    if ($extracted -eq 0) { throw "No files found under '$prefix' in '$Dazip'." }

    # --- 2. register the addin in AddIns.xml --------------------------------
    $manifestEntry = $zip.GetEntry('Manifest.xml')
    if (-not $manifestEntry) { throw "Manifest.xml missing from '$Dazip'." }
    $reader = New-Object System.IO.StreamReader($manifestEntry.Open())
    $manifestXml = $reader.ReadToEnd()
    $reader.Dispose()

    $item = [regex]::Match($manifestXml, '(?s)<AddInItem\b.*?</AddInItem>').Value
    if (-not $item) { throw "No <AddInItem> found in the dazip manifest." }
} finally {
    $zip.Dispose()
}

# Replace any previous registration, then append before </AddInsList>.
Remove-AddInEntry -Path $addInsXml -Uid $UID | Out-Null
$text = [System.IO.File]::ReadAllText($addInsXml)
if ($text -notmatch '</AddInsList>') { throw "AddIns.xml has no </AddInsList> root element." }
$text = $text -replace '</AddInsList>', ("`t" + $item + "`r`n</AddInsList>")
[System.IO.File]::WriteAllText($addInsXml, $text)

Write-Host ""
Write-Host "Installed '$UID'."
Write-Host "  AddIn folder : $addinDir"
Write-Host "  Register     : $addInsXml  (backup: AddIns.xml.bak)"
Write-Host ""
Write-Host "Test in game:  load a save, enable the developer console, then"
Write-Host "    runscript respec1"
