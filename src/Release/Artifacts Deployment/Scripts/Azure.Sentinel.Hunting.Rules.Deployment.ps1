[CmdletBinding()]
param (
    [Parameter(Mandatory = $true)]
    [string]
    $WorkspaceName,
    [Parameter(Mandatory = $true)]
    [string]
    $ResourceGroup,
    [Parameter(Mandatory = $true)]
    [string]
    $Path,
    [Parameter(Mandatory = $true)]
    [ValidateSet("Json", "Yaml", "All")]
    [string]
    $Format
)

try{
    Import-AzSentinelHuntingRules -WorkspaceName $WorkspaceName -ResourceGroup $ResourceGroup -Path $Path -Format Yaml
}
catch {
    Write-Host "##vso[task.logissue type=warning;result=SucceededWithIssues]$_"
}