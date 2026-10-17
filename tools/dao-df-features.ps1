# Enable/disable the Dain's Fixes features that interfere with Lock Bash.
#
# Override files are mounted recursively BY FILE NAME, so renaming a folder
# inside override disables nothing: the .gda is still mounted from the new path.
# Disabling therefore means moving the feature folder OUT of the override tree.
#
# Parked features keep their full path relative to the override root, so the
# disabled tree mirrors the original layout and a folder can be put back by
# hand without guessing where it came from:
#
#   packages\core\override\Dain's Fixes\3. Quality of Life\Helpful party members - unlock
#   _disabled_overrides\Dain's Fixes\3. Quality of Life\Helpful party members - unlock
#
#   powershell -File tools\dao-df-features.ps1
#   powershell -File tools\dao-df-features.ps1 -None
#   powershell -File tools\dao-df-features.ps1 -Only unlock
#   powershell -File tools\dao-df-features.ps1 -Enable autoloot,containers
#   powershell -File tools\dao-df-features.ps1 -Disable unlock,hpdisarm

[CmdletBinding(DefaultParameterSetName = 'List')]
param(
    [Parameter(ParameterSetName = 'List')]    [switch] $List,
    [Parameter(ParameterSetName = 'All')]     [switch] $All,
    [Parameter(ParameterSetName = 'None')]    [switch] $None,
    [Parameter(ParameterSetName = 'Only')]    [string[]] $Only,
    [Parameter(ParameterSetName = 'Enable')]  [string[]] $Enable,
    [Parameter(ParameterSetName = 'Disable')] [string[]] $Disable
)

$ErrorActionPreference = 'Stop'

# powershell -File passes arguments as plain strings, so "a,b" arrives as one
# element rather than an array; split it so both call styles work.
foreach ($p in @('Only', 'Enable', 'Disable')) {
    $val = Get-Variable -Name $p -ValueOnly -ErrorAction SilentlyContinue
    if ($val) { Set-Variable -Name $p -Value ($val -split ',' | ForEach-Object { $_.Trim() } | Where-Object { $_ }) }
}

$docs   = Join-Path $env:USERPROFILE 'Documents\BioWare\Dragon Age'
$liveRoot = Join-Path $docs 'packages\core\override'
$parkRoot = Join-Path $docs '_disabled_overrides'
if (-not (Test-Path -LiteralPath $parkRoot)) { New-Item -ItemType Directory -Force -Path $parkRoot | Out-Null }

# Path relative to the override root. Both the live and parked copies use it, so
# the disabled tree has the same parents as the original.
$features = [ordered] @{
    autoloot   = @{ Rel = "Dain's Fixes\3. Quality of Life\Autoloot kills";                 Marker = 'dfopts_autoloot.gda' }
    unlock     = @{ Rel = "Dain's Fixes\3. Quality of Life\Helpful party members - unlock"; Marker = 'dfopts_hpunlock.gda' }
    fastdisarm = @{ Rel = "Dain's Fixes\3. Quality of Life\Fast disarm animation";          Marker = 'dfopts_fastdisarm.gda' }
    hpdisarm   = @{ Rel = "Dain's Fixes\3. Quality of Life\Helpful party members - disarm"; Marker = 'dfopts_hpdisarm.gda' }
    containers = @{ Rel = "Dain's Fixes\3. Quality of Life\Autoloot containers";            Marker = 'placeable_core.ncs' }
}

function Get-Feature([string] $key) {
    if (-not $features.Contains($key)) { throw "unknown feature '$key'. Known: $($features.Keys -join ', ')" }
    return $features[$key]
}

# ---------------------------------------------------------------- migration
# Older versions of this helper parked features as flat df_<key> folders. Move
# those to the mirrored layout so the tree is the same as the source tree.
$legacy = @{
    'df_autoloot'   = 'autoloot'
    'df_hpunlock'   = 'unlock'
    'df_fastdisarm' = 'fastdisarm'
    'df_hpdisarm'   = 'hpdisarm'
    'df_containers' = 'containers'
}
foreach ($name in $legacy.Keys) {
    $old = Join-Path $parkRoot $name
    if (-not (Test-Path -LiteralPath $old)) { continue }
    $rel  = $features[$legacy[$name]].Rel
    $dest = Join-Path $parkRoot $rel
    if (Test-Path -LiteralPath $dest) { Write-Host "  migration: discarding stale $name"; Remove-Item -LiteralPath $old -Recurse -Force; continue }
    New-Item -ItemType Directory -Force -Path (Split-Path -Parent $dest) | Out-Null
    Move-Item -LiteralPath $old -Destination $dest -Force
    Write-Host "  migration: $name -> $rel"
}

# ------------------------------------------------------------------ actions
function Set-Feature([string] $key, [bool] $present) {
    $feat = Get-Feature $key
    $live = Join-Path $liveRoot $feat.Rel
    $park = Join-Path $parkRoot $feat.Rel
    if ($present) {
        if (Test-Path -LiteralPath $live) { return }
        if (-not (Test-Path -LiteralPath $park)) { Write-Warning "$key : not found in either place, skipped"; return }
        New-Item -ItemType Directory -Force -Path (Split-Path -Parent $live) | Out-Null
        Move-Item -LiteralPath $park -Destination $live -Force
    } else {
        if (-not (Test-Path -LiteralPath $live)) { return }
        if (Test-Path -LiteralPath $park) { Remove-Item -LiteralPath $park -Recurse -Force }
        New-Item -ItemType Directory -Force -Path (Split-Path -Parent $park) | Out-Null
        Move-Item -LiteralPath $live -Destination $park -Force
    }
}

if ($All)         { foreach ($k in $features.Keys) { Set-Feature $k $true } }
elseif ($None)    { foreach ($k in $features.Keys) { Set-Feature $k $false } }
elseif ($Only)    { foreach ($k in $features.Keys) { Set-Feature $k ($Only -contains $k) } }
elseif ($Enable)  { foreach ($k in $Enable)  { Set-Feature $k $true } }
elseif ($Disable) { foreach ($k in $Disable) { Set-Feature $k $false } }

# ------------------------------------------------------------------- report
"{0,-11} {1,-6} {2}" -f 'KEY', 'STATE', 'REGISTERS-ON'
foreach ($key in $features.Keys) {
    $feat = $features[$key]
    $live = Test-Path -LiteralPath (Join-Path $liveRoot $feat.Rel)
    $hook = ''
    if ($live) {
        $hook = (Get-ChildItem -LiteralPath (Join-Path $liveRoot $feat.Rel) -Filter 'engineevents_*.gda' -ErrorAction SilentlyContinue |
                 ForEach-Object { $_.Name -replace '^engineevents_', '' -replace '\.gda$', '' }) -join ','
    }
    "{0,-11} {1,-6} {2}" -f $key, $(if ($live) { 'ON' } else { 'off' }), $hook
}
