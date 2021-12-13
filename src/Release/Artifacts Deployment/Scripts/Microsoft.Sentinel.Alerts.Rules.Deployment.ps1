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
    $Format
)

try {
    Import-AzSentinelAnalyticRules -ResourceGroup $ResourceGroup -Workspace $Workspace -Path $Path -Format $Format
}
catch {
    Write-Host "##vso[task.logissue type=warning;result=SucceededWithIssues]$_"
}
