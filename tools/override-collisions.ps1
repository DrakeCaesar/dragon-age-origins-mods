<#
.SYNOPSIS
    Finds override file names that appear in more than one place.

.DESCRIPTION
    Dragon Age mounts the override tree as resource sources, and a resource is
    looked up by name, not by path: two files with the same name in different
    subfolders compete for the same lookup. This lists every such name with all
    of its copies, ordered by relative path, and marks the alphabetically last
    one so either ordering can be read off the same output.

    The engine side is only partly pinned down: ECResMan::DirectorySource indexes
    one directory at construction (0x4cfc40 -> 0x4cf690) and mounts nested .erf
    files as further sources, so the winner is decided by the order sources are
    registered plus the manager's lookup rule. Which of those orders the engine
    prefers has not been verified, so treat the marked line as a candidate, not a
    verdict.

    Archival files (.erf/.rim/.zip/.7z/.rar) are mounted as archives, so their
    contents are not visible here; they are reported separately instead.

.PARAMETER Override
    Override folder. Defaults to the DA:O one under Documents.

.PARAMETER SameFolderOnly
    Only report duplicates that share a folder (case-only differences).

.PARAMETER Csv
    Write the result to this path as CSV instead of the console.

.EXAMPLE
    powershell -File tools\override-collisions.ps1

.EXAMPLE
    powershell -File tools\override-collisions.ps1 -Csv "$env:TEMP\collisions.csv"
#>
[CmdletBinding()]
param(
    [string] $Override,
    [switch] $SameFolderOnly,
    [string] $Csv
)

$ErrorActionPreference = 'Stop'

if (-not $Override) {
    $Override = Join-Path $env:USERPROFILE 'Documents\BioWare\Dragon Age\packages\core\override'
}
if (-not (Test-Path -LiteralPath $Override)) {
    throw "Override folder not found: '$Override'."
}

$root  = (Resolve-Path -LiteralPath $Override).Path
$files = Get-ChildItem -LiteralPath $root -Recurse -File -ErrorAction SilentlyContinue

# Resource names are case insensitive on Windows and in the engine, so grouping
# is too; the reported name is the first spelling seen.
$groups = $files |
    Group-Object { $_.Name.ToLowerInvariant() } |
    Where-Object { $_.Count -gt 1 }

$rows = foreach ($g in $groups) {
    $copies = $g.Group |
        Sort-Object { $_.DirectoryName.Substring($root.Length).TrimStart('\') } |
        ForEach-Object {
            [pscustomobject]@{
                Name     = $_.Name
                Folder   = $_.DirectoryName.Substring($root.Length).TrimStart('\')
                Size     = $_.Length
                Modified = $_.LastWriteTime
            }
        }

    if ($SameFolderOnly) {
        $shared = $copies | Group-Object Folder | Where-Object { $_.Count -gt 1 }
        if (-not $shared) { continue }
    }
    $copies
}

$archiveExt = '.erf', '.rim', '.zip', '.7z', '.rar'
$archives = $files | Where-Object { $archiveExt -contains $_.Extension.ToLowerInvariant() }

if ($Csv) {
    $rows | Export-Csv -LiteralPath $Csv -NoTypeInformation -Encoding utf8
    Write-Host "Wrote $($rows.Count) row(s) to $Csv"
    return
}

Write-Host ""
Write-Host "Override : $root"
Write-Host ("Files    : {0}   distinct names: {1}   colliding names: {2}" -f `
    $files.Count, ($files | Group-Object { $_.Name.ToLowerInvariant() }).Count, $groups.Count)
if ($archives) {
    Write-Host ("Archives : {0} (contents not scanned: {1})" -f $archives.Count,
        (($archives | Select-Object -ExpandProperty Name) -join ', '))
}
Write-Host ""

if (-not $rows) {
    Write-Host "No duplicate file names."
    return
}

foreach ($g in ($rows | Group-Object Name)) {
    Write-Host ("{0}   ({1} copies)" -f $g.Name, $g.Count)
    $i = 0
    foreach ($r in $g.Group) {
        $i++
        $where = if ($r.Folder) { $r.Folder } else { '(override root)' }
        $last  = if ($i -eq $g.Count) { '  <- alphabetically last' } else { '' }
        Write-Host ("   {0,2}. {1,-60} {2,10:N0} bytes{3}" -f $i, $where, $r.Size, $last)
    }
    Write-Host ""
}
