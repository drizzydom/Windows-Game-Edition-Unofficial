$script:ModuleRoot = $PSScriptRoot

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

    return [pscustomobject]@{
        ProductName    = $osInfo.ProductName
        EditionId      = $osInfo.EditionID
        ReleaseId      = $osInfo.ReleaseId
        DisplayVersion = $osInfo.DisplayVersion
        BuildNumber    = $osInfo.CurrentBuild
        IsServer       = ($osInfo.ProductName -like '*Server*')
        Is64Bit        = [Environment]::Is64BitOperatingSystem
    }
}

function Get-WGEStateRoot {
    [CmdletBinding()]
    param()

    $candidates = @()

    if ($env:ProgramData) {
        $candidates += (Join-Path -Path $env:ProgramData -ChildPath 'WGE')
    }

    if ($env:LOCALAPPDATA) {
        $candidates += (Join-Path -Path $env:LOCALAPPDATA -ChildPath 'WGE')
    }

    if ($script:ModuleRoot) {
        $candidates += (Join-Path -Path (Split-Path -Path $script:ModuleRoot -Parent) -ChildPath 'logs')
    }

    foreach ($candidate in $candidates | Where-Object { $_ -and $_.Trim() -ne '' }) {
        try {
            if (-not (Test-Path -Path $candidate -PathType Container)) {
                New-Item -ItemType Directory -Path $candidate -ErrorAction Stop | Out-Null
            }
            return $candidate
        }
        catch {
            continue
        }
    }

    throw 'Unable to establish a writable state directory for Windows Game Edition logs.'
}

function Invoke-WGEDeliveryOptimizationPreStop {
    [CmdletBinding()]
    param()

    $messages = @()

    try {
        $transfers = @(
            Get-BitsTransfer -AllUsers -ErrorAction Stop |
                Where-Object { $_.DisplayName -like 'Delivery Optimization*' }
        )
        if ($transfers.Count -gt 0) {
            foreach ($transfer in $transfers) {
                Remove-BitsTransfer -BitsJob $transfer -Confirm:$false -ErrorAction Stop
            }
            $messages += "Cancelled $($transfers.Count) Delivery Optimization BITS transfer(s)."
        }
    }
    catch {
        Write-Verbose "BITS cleanup skipped: $($_.Exception.Message)"
    }

    try {
        $removeCache = Get-Command -Name Remove-DeliveryOptimizationCache -ErrorAction Stop
        if ($removeCache) {
            Remove-DeliveryOptimizationCache -Quiet -ErrorAction Stop | Out-Null
            $messages += 'Cleared Delivery Optimization cache.'
        }
    }
    catch {
        Write-Verbose "Delivery Optimization cache cleanup skipped: $($_.Exception.Message)"
    }

    try {
        $scOutput = & sc.exe stop dosvc 2>&1
        $exitCode = $LASTEXITCODE
        if ($scOutput) {
            Write-Verbose ($scOutput | Out-String)
        }
        if ($exitCode -eq 0) {
            $messages += 'Issued SCM stop request to DoSvc.'
        }
        else {
            Write-Verbose "SC stop for DoSvc returned exit code $exitCode."
        }
    }
    catch {
        Write-Verbose "SC stop for DoSvc failed: $($_.Exception.Message)"
    }

    if ($messages.Count -eq 0) {
        return $null
    }

    return [string]::Join(' ', $messages)
}

function Wait-WGEServiceStop {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Name,

        [int]$TimeoutSeconds = 5
    )

    $deadline = [DateTime]::UtcNow.AddSeconds($TimeoutSeconds)
    while ([DateTime]::UtcNow -lt $deadline) {
        try {
            $service = Get-Service -Name $Name -ErrorAction Stop
            if ($service.Status -eq 'Stopped') {
                return $true
            }
        }
        catch {
            return $true
        }

        Start-Sleep -Milliseconds 250
    }

    return $false
}

function New-WGEActionRecord {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [pscustomobject]$Manifest,

        [Parameter(Mandatory)]
        [pscustomobject]$Tweak,

        [Parameter(Mandatory)]
        [string]$CommandType,

        [Parameter(Mandatory)]
        [string]$Target,

        [Parameter(Mandatory)]
        [string]$Action,

        [Parameter(Mandatory)]
        [string]$Message,

        [bool]$Succeeded = $true,

        [string]$UndoAction,

        $UndoData,

        [bool]$DryRun = $false,

        [bool]$Skipped = $false,

        [string]$SkipReason,

        [string]$ErrorMessage
    )

    return [pscustomobject]@{
        Timestamp         = [DateTime]::UtcNow
        ManifestId        = $Manifest.metadata.id
        ManifestName      = $Manifest.metadata.name
        ManifestPath      = $Manifest.SourcePath
        TweakId           = $Tweak.id
        TweakName         = $Tweak.name
        Category          = $Tweak.category
        RiskLevel         = $Tweak.riskLevel
        CommandType       = $CommandType
        Target            = $Target
        Action            = $Action
        Message           = $Message
        UndoAction        = $UndoAction
        UndoData          = $UndoData
        RequiresReboot    = [bool]$Tweak.requiresReboot
        RequiresElevation = [bool]$Tweak.requiresElevation
        DryRun            = $DryRun
        Skipped           = $Skipped
        SkipReason        = $SkipReason
        Succeeded         = $Succeeded
        ErrorMessage      = $ErrorMessage
    }
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

function Invoke-WGETweak {
    [CmdletBinding(SupportsShouldProcess = $true, ConfirmImpact = 'Medium')]
    param(
        [Parameter(Mandatory)]
        [pscustomobject]$Manifest,

        [Parameter(Mandatory)]
        [string]$TweakId,

        [ValidateSet('Disable', 'Enable')]
        [string]$Action = 'Disable',

        [pscustomobject]$SystemProfile,

        [switch]$SkipIfUnsupported
    )

    if (-not $SystemProfile) {
        $SystemProfile = Get-WGESystemProfile
    }

    $tweak = $Manifest.tweaks | Where-Object { $_.id -eq $TweakId }
    if (-not $tweak) {
        throw "Tweak '$TweakId' not found in manifest '$($Manifest.metadata.id)'."
    }

    $dryRun = [bool]$WhatIfPreference
    $supported = Test-WGETweakSupport -Tweak $tweak -Profile $SystemProfile

    if (-not $supported -and $SkipIfUnsupported.IsPresent) {
        return @(New-WGEActionRecord -Manifest $Manifest -Tweak $tweak -CommandType 'meta' -Target $TweakId -Action 'Skip' -Message "Skipped tweak '$($tweak.name)' for edition $($SystemProfile.EditionId)" -DryRun:$dryRun -Skipped:$true -SkipReason:"Unsupported on $($SystemProfile.ProductName)")
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
        return @(New-WGEActionRecord -Manifest $Manifest -Tweak $tweak -CommandType 'meta' -Target $TweakId -Action 'None' -Message "Tweak '$($tweak.name)' has no commands for action '$Action'." -DryRun:$dryRun)
    }

    $results = @()

    foreach ($command in $commands) {
        $result = Invoke-WGECommand -Command $command -Action $Action -Tweak $tweak -Manifest $Manifest -DryRun:$dryRun
        if ($result) {
            $results += $result
        }
    }

    return $results
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
        [pscustomobject]$Manifest,

        [bool]$DryRun = $false
    )

    $target = Get-WGECommandTarget -Command $Command
    if (-not $PSCmdlet.ShouldProcess($target, "Invoke $($Command.action) for $($Tweak.id)")) {
        return New-WGEActionRecord -Manifest $Manifest -Tweak $Tweak -CommandType $Command.type -Target $target -Action $Command.action -Message "Command skipped by ShouldProcess for $target." -DryRun:$DryRun -Skipped:$true -SkipReason 'ShouldProcess declined'
    }

    switch ($Command.type) {
        'service' {
            return Invoke-WGEServiceCommand -Manifest $Manifest -Tweak $Tweak -Command $Command -DryRun:$DryRun
        }
        'scheduledTask' {
            return Invoke-WGEScheduledTaskCommand -Manifest $Manifest -Tweak $Tweak -Command $Command -DryRun:$DryRun
        }
        'registry' {
            return Invoke-WGERegistryCommand -Manifest $Manifest -Tweak $Tweak -Command $Command -DryRun:$DryRun
        }
        default {
            return New-WGEActionRecord -Manifest $Manifest -Tweak $Tweak -CommandType $Command.type -Target $target -Action $Command.action -Message "Unsupported command type '$($Command.type)'" -Succeeded:$false -ErrorMessage:"Unsupported command type $($Command.type)." -DryRun:$DryRun
        }
    }
}

function Get-WGECommandTarget {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [pscustomobject]$Command
    )

    switch ($Command.type) {
        'service' { return $Command.name }
        'scheduledTask' {
            $path = if ($Command.taskPath) { $Command.taskPath } else { '\\' }
            $name = if ($Command.taskName) { $Command.taskName } else { '<unknown task>' }
            return "task:$path$name"
        }
        'registry' {
            $path = if ($Command.path) { $Command.path } else { '<unknown hive>' }
            $valueName = if ($Command.name) { $Command.name } else { '(Default)' }
            return "reg:$path::$valueName"
        }
        default { return $Command.name }
    }
}

function Invoke-WGEServiceCommand {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [pscustomobject]$Manifest,

        [Parameter(Mandatory)]
        [pscustomobject]$Tweak,

        [Parameter(Mandatory)]
        [pscustomobject]$Command,

        [bool]$DryRun = $false
    )

    $name = $Command.name
    $undoData = [pscustomobject]@{
        UndoArguments   = $Command.undoArguments
        UndoStartupType = $Command.undoStartupType
    }

    switch ($Command.action) {
        'Stop' {
            $args = @{
                Name        = $name
                ErrorAction = 'Stop'
            }
            if ($Command.arguments -and ($Command.arguments -contains '-Force')) {
                $args['Force'] = $true
            }
            $prepMessage = $null
            if ($name -ieq 'dosvc') {
                $prepMessage = Invoke-WGEDeliveryOptimizationPreStop
            }
            try {
                Stop-Service @args
                $stopped = Wait-WGEServiceStop -Name $name -TimeoutSeconds 6
                if (-not $stopped) {
                    $serviceInfo = Get-Service -Name $name -ErrorAction SilentlyContinue
                    $status = if ($serviceInfo) { $serviceInfo.Status } else { 'Unknown' }
                    $message = "Attempted to stop service $name but it remains $status."
                    if ($prepMessage) {
                        $message = "$message $prepMessage"
                    }
                    return New-WGEActionRecord -Manifest $Manifest -Tweak $Tweak -CommandType 'service' -Target $name -Action 'Stop' -Message $message -UndoAction $Command.undoAction -UndoData $undoData -DryRun:$DryRun -Succeeded:$false -ErrorMessage:"Service $name remained $status after stop attempt."
                }

                $messageParts = @("Stopped service $name")
                if ($prepMessage) {
                    $messageParts += $prepMessage
                }

                return New-WGEActionRecord -Manifest $Manifest -Tweak $Tweak -CommandType 'service' -Target $name -Action 'Stop' -Message ($messageParts -join ' ') -UndoAction $Command.undoAction -UndoData $undoData -DryRun:$DryRun
            }
            catch {
                $message = "Failed stopping service $name"
                if ($prepMessage) {
                    $message = "$message $prepMessage"
                }
                return New-WGEActionRecord -Manifest $Manifest -Tweak $Tweak -CommandType 'service' -Target $name -Action 'Stop' -Message $message -Succeeded:$false -ErrorMessage:$_.Exception.Message -UndoAction $Command.undoAction -UndoData $undoData -DryRun:$DryRun
            }
        }
        'Start' {
            try {
                Start-Service -Name $name -ErrorAction Stop
                return New-WGEActionRecord -Manifest $Manifest -Tweak $Tweak -CommandType 'service' -Target $name -Action 'Start' -Message "Started service $name" -UndoAction $Command.undoAction -UndoData $undoData -DryRun:$DryRun
            }
            catch {
                return New-WGEActionRecord -Manifest $Manifest -Tweak $Tweak -CommandType 'service' -Target $name -Action 'Start' -Message "Failed starting service $name" -Succeeded:$false -ErrorMessage:$_.Exception.Message -UndoAction $Command.undoAction -UndoData $undoData -DryRun:$DryRun
            }
        }
        'SetStartup' {
            if (-not $Command.startupType) {
                throw "SetStartup command missing startupType for service '$name'."
            }
            try {
                Set-Service -Name $name -StartupType $Command.startupType -ErrorAction Stop
                return New-WGEActionRecord -Manifest $Manifest -Tweak $Tweak -CommandType 'service' -Target $name -Action 'SetStartup' -Message "Set service $name startup to $($Command.startupType)" -UndoAction $Command.undoAction -UndoData $undoData -DryRun:$DryRun
            }
            catch {
                return New-WGEActionRecord -Manifest $Manifest -Tweak $Tweak -CommandType 'service' -Target $name -Action 'SetStartup' -Message "Failed to set service $name startup to $($Command.startupType)" -Succeeded:$false -ErrorMessage:$_.Exception.Message -UndoAction $Command.undoAction -UndoData $undoData -DryRun:$DryRun
            }
        }
        default {
            return New-WGEActionRecord -Manifest $Manifest -Tweak $Tweak -CommandType 'service' -Target $name -Action $Command.action -Message "Unsupported service action '$($Command.action)'" -Succeeded:$false -ErrorMessage:"Unsupported service action $($Command.action)." -UndoAction $Command.undoAction -UndoData $undoData -DryRun:$DryRun
        }
    }
}

function Invoke-WGEScheduledTaskCommand {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [pscustomobject]$Manifest,

        [Parameter(Mandatory)]
        [pscustomobject]$Tweak,

        [Parameter(Mandatory)]
        [pscustomobject]$Command,

        [bool]$DryRun = $false
    )

    $taskName = $Command.taskName
    if (-not $taskName) {
        throw "ScheduledTask command missing taskName for tweak '$($Tweak.id)'."
    }

    $taskPath = if ($Command.taskPath) { $Command.taskPath } else { '\\' }
    $undoData = [pscustomobject]@{
        UndoTaskPath = $taskPath
        UndoTaskName = $taskName
    }

    try {
        switch ($Command.action) {
            'Disable' {
                Disable-ScheduledTask -TaskName $taskName -TaskPath $taskPath -ErrorAction Stop | Out-Null
                return New-WGEActionRecord -Manifest $Manifest -Tweak $Tweak -CommandType 'scheduledTask' -Target "$taskPath$taskName" -Action 'Disable' -Message "Disabled scheduled task $taskPath$taskName" -UndoAction $Command.undoAction -UndoData $undoData -DryRun:$DryRun
            }
            'Enable' {
                Enable-ScheduledTask -TaskName $taskName -TaskPath $taskPath -ErrorAction Stop | Out-Null
                return New-WGEActionRecord -Manifest $Manifest -Tweak $Tweak -CommandType 'scheduledTask' -Target "$taskPath$taskName" -Action 'Enable' -Message "Enabled scheduled task $taskPath$taskName" -UndoAction $Command.undoAction -UndoData $undoData -DryRun:$DryRun
            }
            default {
                return New-WGEActionRecord -Manifest $Manifest -Tweak $Tweak -CommandType 'scheduledTask' -Target "$taskPath$taskName" -Action $Command.action -Message "Unsupported scheduled task action '$($Command.action)'" -Succeeded:$false -ErrorMessage:"Unsupported scheduled task action $($Command.action)." -UndoAction $Command.undoAction -UndoData $undoData -DryRun:$DryRun
            }
        }
    }
    catch {
        return New-WGEActionRecord -Manifest $Manifest -Tweak $Tweak -CommandType 'scheduledTask' -Target "$taskPath$taskName" -Action $Command.action -Message "Scheduled task action failed for $taskPath$taskName" -Succeeded:$false -ErrorMessage:$_.Exception.Message -UndoAction $Command.undoAction -UndoData $undoData -DryRun:$DryRun
    }
}

function Convert-WGERegistryValue {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        $Value,

        [Parameter(Mandatory)]
        [string]$Type
    )

    switch ($Type.ToLower()) {
        'dword' { return [int]$Value }
        'qword' { return [long]$Value }
        'binary' { return $Value }
        'multistring' {
            if ($Value -is [System.Collections.IEnumerable] -and -not ($Value -is [string])) {
                return [string[]]$Value
            }
            elseif ($Value) {
                return @($Value.ToString())
            }
            else {
                return @()
            }
        }
        default { return $Value }
    }
}

function Invoke-WGERegistryCommand {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [pscustomobject]$Manifest,

        [Parameter(Mandatory)]
        [pscustomobject]$Tweak,

        [Parameter(Mandatory)]
        [pscustomobject]$Command,

        [bool]$DryRun = $false
    )

    $path = $Command.path
    if (-not $path) {
        throw "Registry command missing path for tweak '$($Tweak.id)'."
    }

    $name = $Command.name
    if (-not $name) {
        throw "Registry command missing name for tweak '$($Tweak.id)'."
    }
    $valueType = if ($Command.valueType) { $Command.valueType } else { 'String' }
    $undoData = [pscustomobject]@{
        UndoPath      = $path
        UndoName      = $name
        UndoValue     = $Command.undoValue
        UndoValueType = $Command.undoValueType
    }

    try {
        switch ($Command.action) {
            'SetValue' {
                $value = Convert-WGERegistryValue -Value $Command.value -Type $valueType
                if (-not (Test-Path -Path $path)) {
                    New-Item -Path $path -Force | Out-Null
                }

                $newArgs = @{
                    Path        = $path
                    Name        = $name
                    Value       = $value
                    Force       = $true
                    ErrorAction = 'Stop'
                }

                if ($valueType) {
                    $newArgs['PropertyType'] = $valueType
                }

                New-ItemProperty @newArgs | Out-Null
                return New-WGEActionRecord -Manifest $Manifest -Tweak $Tweak -CommandType 'registry' -Target "$path::$name" -Action 'SetValue' -Message "Set registry value $path::$name to $value" -UndoAction $Command.undoAction -UndoData $undoData -DryRun:$DryRun
            }
            'RemoveValue' {
                Remove-ItemProperty -Path $path -Name $name -ErrorAction Stop
                return New-WGEActionRecord -Manifest $Manifest -Tweak $Tweak -CommandType 'registry' -Target "$path::$name" -Action 'RemoveValue' -Message "Removed registry value $path::$name" -UndoAction $Command.undoAction -UndoData $undoData -DryRun:$DryRun
            }
            default {
                return New-WGEActionRecord -Manifest $Manifest -Tweak $Tweak -CommandType 'registry' -Target "$path::$name" -Action $Command.action -Message "Unsupported registry action '$($Command.action)'" -Succeeded:$false -ErrorMessage:"Unsupported registry action $($Command.action)." -UndoAction $Command.undoAction -UndoData $undoData -DryRun:$DryRun
            }
        }
    }
    catch {
        return New-WGEActionRecord -Manifest $Manifest -Tweak $Tweak -CommandType 'registry' -Target "$path::$name" -Action $Command.action -Message "Registry action failed for $path::$name" -Succeeded:$false -ErrorMessage:$_.Exception.Message -UndoAction $Command.undoAction -UndoData $undoData -DryRun:$DryRun
    }
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
        $executed += Invoke-WGETweak -Manifest $Manifest -TweakId $tweak.id -Action $Action -SystemProfile $profile -SkipIfUnsupported:$SkipUnsupported.IsPresent
    }

    return $executed
}

function Get-WGEUndoPlan {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [pscustomobject]$Manifest
    )

    $plan = @()

    foreach ($tweak in $Manifest.tweaks) {
        if (-not $tweak.commands -or -not $tweak.commands.disable) {
            continue
        }

        foreach ($command in $tweak.commands.disable) {
            if (-not $command.undoAction) {
                continue
            }

            $plan += [pscustomobject]@{
                ManifestId      = $Manifest.metadata.id
                TweakId         = $tweak.id
                TweakName       = $tweak.name
                CommandType     = $command.type
                Target          = Get-WGECommandTarget -Command $command
                UndoAction      = $command.undoAction
                UndoArguments   = $command.undoArguments
                UndoStartupType = $command.undoStartupType
                UndoTaskPath    = $command.taskPath
                UndoTaskName    = $command.taskName
                RegistryPath    = $command.path
                RegistryValue   = $command.name
                UndoValue       = $command.undoValue
                UndoValueType   = $command.undoValueType
                Notes           = $tweak.whenDisabled
            }
        }
    }

    return $plan
}

function Export-WGEActionLog {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [pscustomobject]$Manifest,

        [Parameter(Mandatory)]
        [object[]]$Results,

        [pscustomobject]$SystemProfile,

        [switch]$DryRun,

        [string]$OutputDirectory,

        [string]$FileName
    )

    if (-not $OutputDirectory) {
        $stateRoot = Get-WGEStateRoot
        $OutputDirectory = Join-Path -Path $stateRoot -ChildPath 'logs'
    }

    if (-not (Test-Path -Path $OutputDirectory -PathType Container)) {
        New-Item -ItemType Directory -Path $OutputDirectory -Force | Out-Null
    }

    if (-not $FileName) {
        $manifestId = if ($Manifest.metadata.id) { $Manifest.metadata.id } else { 'manifest' }
        $FileName = "wge-$manifestId-$(Get-Date -Format 'yyyyMMdd-HHmmss').json"
    }

    $payload = [pscustomobject]@{
        Timestamp     = (Get-Date).ToString('o')
        Manifest      = [pscustomobject]@{
            Id          = $Manifest.metadata.id
            Name        = $Manifest.metadata.name
            Description = $Manifest.metadata.description
            Path        = $Manifest.SourcePath
        }
        SystemProfile = $SystemProfile
        DryRun        = $DryRun.IsPresent
        Results       = $Results
    }

    $json = $payload | ConvertTo-Json -Depth 8
    $destination = Join-Path -Path $OutputDirectory -ChildPath $FileName
    $utf8 = New-Object System.Text.UTF8Encoding $false
    [System.IO.File]::WriteAllText($destination, $json, $utf8)

    return $destination
}
$script:ManifestSchemaVersion = '0.1.0'
