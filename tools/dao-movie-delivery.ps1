# Toggle whether the level-up movie is delivered twice or once.
#
# The mod ships the movie in two places:
#   AddIns\respec_proto\core\data\respec_proto_modcore.erf   (the addin)
#   packages\core\override\levelup.swf                       (beats FtG UI Mod)
#
# Two copies of the same resource name is suspicious for "every message fires
# twice" bugs, so this switches between the two deliveries without having to
# edit or re-run the deploy.
#
#   powershell -File tools\dao-movie-delivery.ps1            # show state
#   powershell -File tools\dao-movie-delivery.ps1 -Single    # ERF only
#   powershell -File tools\dao-movie-delivery.ps1 -Double    # ERF + override
#
# NOTE: running build\deploy.ps1 re-creates the override copy, so use -Single
# again after any deploy if you want to keep testing single delivery.

[CmdletBinding(DefaultParameterSetName = 'Show')]
param(
    [Parameter(ParameterSetName = 'Show')]   [switch] $Show,
    [Parameter(ParameterSetName = 'Single')] [switch] $Single,
    [Parameter(ParameterSetName = 'Double')] [switch] $Double
)

$ErrorActionPreference = 'Stop'

$docs = Join-Path $env:USERPROFILE 'Documents\BioWare\Dragon Age'
$ovr  = Join-Path $docs 'packages\core\override\levelup.swf'
$erf  = Join-Path $docs 'AddIns\respec_proto\core\data\respec_proto_modcore.erf'

if (Get-Process DAOrigins -ErrorAction SilentlyContinue) {
    throw "Dragon Age is running. Close it first."
}
if (-not (Test-Path -LiteralPath $erf)) {
    throw "The addin ERF is missing - run build\deploy.ps1 first."
}

if ($Single) {
    if (Test-Path -LiteralPath $ovr) {
        Move-Item -LiteralPath $ovr -Destination "$ovr.single-mode" -Force
        Write-Host "  override copy parked -> levelup.swf.single-mode"
    }
}
if ($Double) {
    $parked = "$ovr.single-mode"
    if (Test-Path -LiteralPath $parked) {
        Move-Item -LiteralPath $parked -Destination $ovr -Force
    } elseif (-not (Test-Path -LiteralPath $ovr)) {
        throw "No parked copy to restore. Run build\deploy.ps1 to regenerate it."
    }
}

$erfSize = (Get-Item -LiteralPath $erf).Length
$hasOvr  = Test-Path -LiteralPath $ovr
$deliveries = 1 + $(if ($hasOvr) { 1 } else { 0 })

"delivery   : {0} copy/copies" -f $deliveries
"  addin ERF   {0,9} bytes  {1}" -f $erfSize, $(if (Test-Path -LiteralPath $erf) { 'present' } else { 'MISSING' })
"  override    {0,9} bytes  {1}" -f $(if ($hasOvr) { (Get-Item -LiteralPath $ovr).Length } else { 0 }), $(if ($hasOvr) { 'present' } else { 'absent' })
if ($hasOvr) { "  NOTE: with FtG UI Mod enabled the override is what makes OUR movie win." }
