@{
    RootModule        = 'WGE.Core.psm1'
    ModuleVersion     = '0.1.0'
    GUID              = '8c7cb0a7-a432-4bd8-83f2-2fe4d8f4e8e9'
    Author            = 'Windows Game Edition Team'
    CompanyName       = 'Windows Game Edition (Unofficial)'
    Copyright        = "(c) 2025 Windows Game Edition contributors"
    Description       = 'Core automation helpers that load tweak manifests, detect the current Windows SKU, and execute enable/disable commands with safe undo metadata.'
    PowerShellVersion = '5.1'

    FunctionsToExport = @(
        'Get-WGEManifest',
        'Get-WGESystemProfile',
        'Get-WGEStateRoot',
        'Invoke-WGETweak',
        'Set-WGEPreset',
        'Get-WGEUndoPlan',
        'Test-WGETweakSupport',
        'Test-WGEAdminSession',
        'Export-WGEActionLog'
    )

    AliasesToExport   = @()
    CmdletsToExport   = @()
    VariablesToExport = '*'

    FileList = @(
        'WGE.Core.psm1'
    )

    PrivateData = @{
        PSData = @{
            Tags        = @('windows', 'gaming', 'automation')
            ProjectUri  = 'https://github.com/drizzydom/Windows-Game-Edition-Unofficial'
            ReleaseNotes = 'Adds action logging, undo planning, structured summaries, and scheduled task/registry command support.'
        }
    }
}
