[CmdletBinding()]
param (
    [Parameter(Mandatory = $true)]
    [string]
    $Path,
    [Parameter(Mandatory = $true)]
    [string]
    $SettingsFile
)

try {
    Import-AzSentinelPlaybooks -SettingsFile $SettingsFile -Path $Path
}
catch {
    Write-Host "##vso[task.logissue type=warning;result=SucceededWithIssues]$_"
}