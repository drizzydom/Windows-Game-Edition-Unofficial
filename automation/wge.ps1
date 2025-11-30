[CmdletBinding(DefaultParameterSetName = 'Apply')]
param(
    [Parameter(ParameterSetName = 'Apply')]
    [string]$Preset = 'performance',

    [Parameter(ParameterSetName = 'Apply')]
    [switch]$DryRun,

    [Parameter(ParameterSetName = 'Apply')]
    [switch]$SkipUnsupported,

    [Parameter(ParameterSetName = 'List', Mandatory, ValueFromPipelineByPropertyName)]
    [switch]$List,

    [Parameter(ParameterSetName = 'List')]
    [switch]$VerboseSkus
)

$ErrorActionPreference = 'Stop'

$scriptRoot = Split-Path -Path $MyInvocation.MyCommand.Definition -Parent
$modulePath = Join-Path -Path $scriptRoot -ChildPath 'modules/WGE.Core/WGE.Core.psd1'
$manifestRoot = Join-Path -Path $scriptRoot -ChildPath 'manifests'

if (-not (Test-Path -Path $modulePath -PathType Leaf)) {
    throw "Unable to locate WGE.Core module at $modulePath"
}

Import-Module $modulePath -Force

if ($List) {
    Get-ChildItem -Path $manifestRoot -Filter '*.json' | ForEach-Object {
        $manifest = Get-WGEManifest -Path $_.FullName
        $profile = Get-WGESystemProfile
        $supportedCount = ($manifest.tweaks | Where-Object { Test-WGETweakSupport -Tweak $_ -Profile $profile }).Count
        if ($VerboseSkus) {
            Write-Output ([pscustomobject]@{
                Id          = $manifest.metadata.id
                Name        = $manifest.metadata.name
                Tweaks      = $manifest.tweaks.Count
                Supported   = $supportedCount
                Description = $manifest.metadata.description
                Path        = $manifest.SourcePath
            })
        }
        else {
            Write-Output "$($manifest.metadata.id) - $($manifest.metadata.name) ($supportedCount/$($manifest.tweaks.Count) supported)"
        }
    }
    return
}

$targetManifest = Join-Path -Path $manifestRoot -ChildPath "$Preset.json"
if (-not (Test-Path -Path $targetManifest -PathType Leaf)) {
    throw "Could not find manifest '$Preset' under $manifestRoot"
}

$loadedManifest = Get-WGEManifest -Path $targetManifest

$profile = Get-WGESystemProfile
Write-Verbose "Detected SKU: $($profile.ProductName) ($($profile.EditionId)) build $($profile.BuildNumber)"

$whatIf = $DryRun.IsPresent
$initialPreference = $WhatIfPreference
try {
    if ($whatIf) {
        $WhatIfPreference = $true
    }

    $results = Set-WGEPreset -Manifest $loadedManifest -Action 'Disable' -SkipUnsupported:$SkipUnsupported.IsPresent
    if (-not $results) {
        Write-Output "No commands executed."
    }
    else {
        Write-Output "Applied preset '$($loadedManifest.metadata.name)' using manifest '$($loadedManifest.SourcePath)'."
        $results | ForEach-Object { Write-Output " - $_" }
    }
}
finally {
    $WhatIfPreference = $initialPreference
}
