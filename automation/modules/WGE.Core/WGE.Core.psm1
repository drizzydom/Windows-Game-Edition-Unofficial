$script:ManifestSchemaVersion = '0.1.0'

function Get-WGEManifest {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory, Position = 0)]
        [string]$Path
    )

    if (-not (Test-Path -Path $Path -PathType Leaf)) {
        throw "Manifest not found: $Path"
    }

    $json = Get-Content -Path $Path -Raw -ErrorAction Stop
    $manifest = $null
    try {
        $manifest = $json | ConvertFrom-Json -ErrorAction Stop
    }
    catch {
        throw "Manifest is not valid JSON. $_"
    }

    if (-not $manifest.schemaVersion) {
        throw "Manifest is missing schemaVersion."
    }

    if ($manifest.schemaVersion -ne $script:ManifestSchemaVersion) {
        throw "Manifest schemaVersion '$($manifest.schemaVersion)' does not match expected '$script:ManifestSchemaVersion'."
    }

    $manifest | Add-Member -MemberType NoteProperty -Name SourcePath -Value (Resolve-Path -Path $Path).ProviderPath -Force
    return $manifest
}

function Get-WGESystemProfile {
    [CmdletBinding()]
    param()

    $osKey = 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion'
    $osInfo = Get-ItemProperty -Path $osKey -ErrorAction Stop
    $buildNumber = $osInfo.CurrentBuild
    $displayVersion = $osInfo.DisplayVersion
    $releaseId = $osInfo.ReleaseId
    $editionId = $osInfo.EditionID
    $productName = $osInfo.ProductName

    $isServer = ($productName -like '*Server*')
    $is64Bit = [Environment]::Is64BitOperatingSystem

    return [pscustomobject]@{
        ProductName    = $productName
        EditionId      = $editionId
        ReleaseId      = $releaseId
        DisplayVersion = $displayVersion
        BuildNumber    = $buildNumber
        IsServer       = $isServer
        Is64Bit        = $is64Bit
    }
}

function Invoke-WGETweak {
    [CmdletBinding(SupportsShouldProcess = $true, ConfirmImpact = 'Medium')]
    param(
        [Parameter(Mandatory)]
        [pscustomobject]$Manifest,

        [Parameter(Mandatory)]
        [string]$TweakId,

        [ValidateSet('Disable', 'Enable')]
        [string]$Action = 'Disable',

        [pscustomobject]$SystemProfile
    )

    if (-not $SystemProfile) {
        $SystemProfile = Get-WGESystemProfile
    }

    $tweak = $Manifest.tweaks | Where-Object { $_.id -eq $TweakId }
    if (-not $tweak) {
        throw "Tweak '$TweakId' not found in manifest '$($Manifest.metadata.id)'."
    }

    $requiresElevation = $false
    if ($null -ne $tweak.requiresElevation) {
        $requiresElevation = [bool]$tweak.requiresElevation
    }

    if ($requiresElevation -and -not (Test-WGEAdminSession)) {
        throw "Tweak '$TweakId' requires administrative privileges. Relaunch the host as Administrator."
    }

    $commands = if ($Action -eq 'Disable') { $tweak.commands.disable } else { $tweak.commands.enable }
    if (-not $commands) {
        Write-Verbose "Tweak '$TweakId' has no commands for action '$Action'."
        return @()
    }

    $results = @()

    foreach ($command in $commands) {
        $result = Invoke-WGECommand -Command $command -Action $Action -Tweak $tweak -Manifest $Manifest
        if ($result) {
            $results += $result
        }
    }

    return $results
}

function Set-WGEPreset {
    [CmdletBinding(SupportsShouldProcess = $true)]
    param(
        [Parameter(Mandatory)]
        [pscustomobject]$Manifest,

        [ValidateSet('Disable', 'Enable')]
        [string]$Action = 'Disable',

        [switch]$SkipUnsupported
    )

    $profile = Get-WGESystemProfile
    $executed = @()

    foreach ($tweak in $Manifest.tweaks) {
        if ($SkipUnsupported -and -not (Test-WGETweakSupport -Tweak $tweak -Profile $profile)) {
            continue
        }
        $executed += Invoke-WGETweak -Manifest $Manifest -TweakId $tweak.id -Action $Action -SystemProfile $profile
    }

    return $executed
}

function Get-WGEUndoPlan {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [pscustomobject]$Manifest
    )

    $undoEntries = @()

    foreach ($tweak in $Manifest.tweaks) {
        if (-not $tweak.commands) {
            continue
        }

        foreach ($command in $tweak.commands.disable) {
            if ($command.undoAction) {
                $undoEntries += [pscustomobject]@{
                    TweakId    = $tweak.id
                    Target     = $command.name
                    Type       = $command.type
                    UndoAction = $command.undoAction
                    UndoData   = $command | Select-Object undoArguments, undoStartupType
                }
            }
        }
    }

    return $undoEntries
}

function Test-WGEAdminSession {
    [CmdletBinding()]
    param()

    $identity = [Security.Principal.WindowsIdentity]::GetCurrent()
    $principal = New-Object Security.Principal.WindowsPrincipal $identity
    return $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

function Test-WGETweakSupport {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [pscustomobject]$Tweak,

        [Parameter(Mandatory)]
        [pscustomobject]$Profile
    )

    if (-not $Tweak.supportedSkus) {
        return $true
    }

    $include = @()
    if ($Tweak.supportedSkus.include) {
        $include = $Tweak.supportedSkus.include | ForEach-Object { $_.ToString().ToLower() }
    }

    $exclude = @()
    if ($Tweak.supportedSkus.exclude) {
        $exclude = $Tweak.supportedSkus.exclude | ForEach-Object { $_.ToString().ToLower() }
    }

    if ($exclude -and ($exclude -contains 'all')) {
        return $false
    }

    $profileEdition = $Profile.EditionId
    if ($profileEdition) {
        $profileEdition = $profileEdition.ToLower()
    }

    if ($exclude -and $profileEdition -and ($exclude -contains $profileEdition)) {
        return $false
    }

    if ($include -and ($include -contains 'all')) {
        return $true
    }

    if ($include -and $profileEdition -and ($include -contains $profileEdition)) {
        return $true
    }

    return -not $include
}

function Invoke-WGECommand {
    [CmdletBinding(SupportsShouldProcess = $true)]
    param(
        [Parameter(Mandatory)]
        [pscustomobject]$Command,

        [Parameter(Mandatory)]
        [string]$Action,

        [Parameter(Mandatory)]
        [pscustomobject]$Tweak,

        [Parameter(Mandatory)]
        [pscustomobject]$Manifest
    )

    $target = "${($Command.type)}::$($Command.name)"
    if (-not $PSCmdlet.ShouldProcess($target, "Invoke $($Command.action) for $($Tweak.id)")) {
        return $null
    }

    switch ($Command.type) {
        'service' {
            return Invoke-WGEServiceCommand -Command $Command
        }
        default {
            throw "Unsupported command type '$($Command.type)' in tweak '$($Tweak.id)'."
        }
    }
}

function Invoke-WGEServiceCommand {
    [CmdletBinding(SupportsShouldProcess = $true)]
    param(
        [Parameter(Mandatory)]
        [pscustomobject]$Command
    )

    $name = $Command.name
    switch ($Command.action) {
        'Stop' {
            $args = @{
                Name        = $name
                ErrorAction = 'Stop'
            }
            if ($Command.arguments -and ($Command.arguments -contains '-Force')) {
                $args['Force'] = $true
            }
            Stop-Service @args
            return "Stopped service $name"
        }
        'Start' {
            Start-Service -Name $name -ErrorAction Stop
            return "Started service $name"
        }
        'SetStartup' {
            if (-not $Command.startupType) {
                throw "SetStartup command missing startupType for service '$name'."
            }
            Set-Service -Name $name -StartupType $Command.startupType -ErrorAction Stop
            return "Set service $name startup to $($Command.startupType)"
        }
        default {
            throw "Unsupported service action '$($Command.action)' for service '$name'."
        }
    }
}
