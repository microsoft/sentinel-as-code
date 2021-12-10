[CmdletBinding()]
param (
    [Parameter(Mandatory)]
    [string]
    $ResourceGroup,
    [Parameter(Mandatory)]
    [string]
    $Workspace,
    [Parameter(Mandatory)]
    [string]
    $Path,
    [Parameter(Mandatory = $true)]
    [ValidateSet("Json", "Yaml", "All")]
    [string]
    $Format,
    [Parameter(Mandatory = $true)]
    [string]
    $SettingsFile
    
)

try {
    Import-AzPlaybookAndRuleConnections -ResourceGroup $ResourceGroup -Workspace $Workspace -Path $Path -Format $Format -SettingsFile $SettingsFile
}
catch {
    Write-Host "##vso[task.logissue type=warning;result=SucceededWithIssues]$_"
}