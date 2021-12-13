[CmdletBinding()]
param (
    [Parameter(Mandatory = $true)]
    [string]
    $Path,
    [Parameter(Mandatory = $true)]
    [string]
    $ResourceGroupName,
    [Parameter(Mandatory = $true)]
    [string]
    $WorkspaceName
)


try {
    Import-AzSentinelWatchlists -ResourceGroupName $ResourceGroupName -WorkspaceName $WorkspaceName -Path $Path
}
catch {
    Write-Host "##vso[task.logissue type=warning;result=SucceededWithIssues]$_"
}