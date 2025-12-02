[CmdletBinding(DefaultParameterSetName = 'Apply')]
param(
    [Parameter(ParameterSetName = 'Apply')]
    [Parameter(ParameterSetName = 'Status')]
    [string]$Preset = 'performance',

    [Parameter(ParameterSetName = 'Apply')]
    [switch]$DryRun,

    [Parameter(ParameterSetName = 'Apply')]
    [Parameter(ParameterSetName = 'Status')]
    [switch]$SkipUnsupported,

    [Parameter(ParameterSetName = 'Apply')]
    [Parameter(ParameterSetName = 'Status')]
    [switch]$AsJson,

    [Parameter(ParameterSetName = 'Status', Mandatory)]
    [switch]$Status,

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

if ($Status) {
    $statusReport = Get-WGEPresetStatus -Manifest $loadedManifest -SystemProfile $profile
    if ($SkipUnsupported) {
        $statusReport.Entries = @($statusReport.Entries | Where-Object { $_.Supported })
        $statusReport.Counts = [pscustomobject]@{
            Applied     = ($statusReport.Entries | Where-Object { $_.State -eq 'Applied' }).Count
            Partial     = ($statusReport.Entries | Where-Object { $_.State -eq 'Partial' }).Count
            NotApplied  = ($statusReport.Entries | Where-Object { $_.State -eq 'NotApplied' }).Count
            Unsupported = 0
            Unknown     = ($statusReport.Entries | Where-Object { $_.State -eq 'Unknown' }).Count
            Total       = $statusReport.Entries.Count
        }
    }

    if ($AsJson) {
        $statusReport | ConvertTo-Json -Depth 6
        return
    }

    Write-Output "Preset '$($statusReport.ManifestName)' status (Applied: $($statusReport.Counts.Applied)/$($statusReport.Counts.Total))"
    foreach ($entry in $statusReport.Entries) {
        $marker = switch ($entry.State) {
            'Applied'     { '[applied]' }
            'Partial'     { '[partial]' }
            'NotApplied'  { '[stock]' }
            'Unsupported' { '[skip]' }
            default       { '[unknown]' }
        }
        $line = " $marker $($entry.TweakName) :: $($entry.Message)"
        Write-Output $line
        foreach ($check in $entry.Checks) {
            if (-not $check) { continue }
            $statusLabel = if ($check.Compliant) { '✓' } else { '✗' }
            Write-Output ("    {0} {1} => desired {2}, actual {3}" -f $statusLabel, $check.Target, $check.Desired, $check.Actual)
        }
    }
    return
}

$whatIf = $DryRun.IsPresent
$initialPreference = $WhatIfPreference
try {
    if ($whatIf) {
        $WhatIfPreference = $true
    }

    $results = Set-WGEPreset -Manifest $loadedManifest -Action 'Disable' -SkipUnsupported:$SkipUnsupported.IsPresent

    if (-not $results -or $results.Count -eq 0) {
        $summary = [pscustomobject]@{
            PresetId       = $loadedManifest.metadata.id
            PresetName     = $loadedManifest.metadata.name
            ManifestPath   = $loadedManifest.SourcePath
            DryRun         = $whatIf
            ActionLogPath  = $null
            Counts         = [pscustomobject]@{
                Total     = 0
                Succeeded = 0
                Failed    = 0
                Skipped   = 0
                WhatIf    = 0
            }
            Entries        = @()
            Message        = 'No commands executed.'
        }

        if ($AsJson) {
            $summary | ConvertTo-Json -Depth 6
            return
        }

        Write-Output $summary.Message
        return
    }

    $operation = if ($whatIf) { 'Previewed' } else { 'Applied' }
    $statusEntries = foreach ($entry in $results) {
        $status = if ($entry.Skipped) {
            'skip'
        }
        elseif (-not $entry.Succeeded) {
            'fail'
        }
        elseif ($entry.DryRun) {
            'whatif'
        }
        else {
            'ok'
        }

        $target = if ($entry.CommandType -eq 'meta') { $entry.TweakName } else { $entry.Target }

        [pscustomobject]@{
            Status          = $status
            TweakId         = $entry.TweakId
            TweakName       = $entry.TweakName
            CommandType     = $entry.CommandType
            Target          = $target
            Message         = $entry.Message
            RequiresReboot  = $entry.RequiresReboot
            RequiresElevation = $entry.RequiresElevation
            Skipped         = $entry.Skipped
            SkipReason      = $entry.SkipReason
            ErrorMessage    = $entry.ErrorMessage
        }
    }

    $counts = [pscustomobject]@{
        Total     = $statusEntries.Count
        Succeeded = ($statusEntries | Where-Object { $_.Status -eq 'ok' }).Count
        Failed    = ($statusEntries | Where-Object { $_.Status -eq 'fail' }).Count
        Skipped   = ($statusEntries | Where-Object { $_.Status -eq 'skip' }).Count
        WhatIf    = ($statusEntries | Where-Object { $_.Status -eq 'whatif' }).Count
    }

    $logPath = $null
    if (-not $whatIf) {
        $logPath = Export-WGEActionLog -Manifest $loadedManifest -Results $results -SystemProfile $profile
    }

    $summary = [pscustomobject]@{
        PresetId       = $loadedManifest.metadata.id
        PresetName     = $loadedManifest.metadata.name
        ManifestPath   = $loadedManifest.SourcePath
        DryRun         = $whatIf
        ActionLogPath  = $logPath
        Counts         = $counts
        Entries        = $statusEntries
        Message        = "$operation preset '$($loadedManifest.metadata.name)' using manifest '$($loadedManifest.SourcePath)'."
    }

    if ($AsJson) {
        $summary | ConvertTo-Json -Depth 6
        return
    }

    Write-Output $summary.Message

    foreach ($entry in $statusEntries) {
        $statusMarker = switch ($entry.Status) {
            'skip'   { '[skip]' }
            'fail'   { '[fail]' }
            'whatif' { '[whatif]' }
            default  { '[ok]' }
        }

        Write-Output (" {0} {1} [{2}] :: {3}" -f $statusMarker, $entry.TweakName, $entry.Target, $entry.Message)
        if ($entry.ErrorMessage) {
            Write-Output ("    error: {0}" -f $entry.ErrorMessage)
        }
        if ($entry.SkipReason) {
            Write-Output ("    reason: {0}" -f $entry.SkipReason)
        }
    }

    if ($whatIf) {
        Write-Output 'Dry run only; no log file was written.'
    }
    elseif ($logPath) {
        Write-Output "Action log saved to $logPath"
    }
}
finally {
    $WhatIfPreference = $initialPreference
}
