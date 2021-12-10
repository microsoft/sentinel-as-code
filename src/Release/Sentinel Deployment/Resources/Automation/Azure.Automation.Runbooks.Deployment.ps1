[CmdletBinding()]
param (
    [Parameter(Mandatory = $true)]
    [string]
    $Path,
    [Parameter(Mandatory = $true)]
    [string]
    $SettingsFile
)

Deploy-AzAutomationRunbook -Path $Path -SettingsFile $SettingsFile