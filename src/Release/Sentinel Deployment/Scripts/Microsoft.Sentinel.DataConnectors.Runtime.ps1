[CmdletBinding()]
param (
    [Parameter(Mandatory = $true)]
    [string]
    $ResourceGroupName,
    [Parameter(Mandatory = $true)]
    [string]
    $Workspace,
    [Parameter(Mandatory = $true)]
    [ValidateSet("Enable", "Disable", "Update", "Check", "None")]
    $Action,
    [Parameter(Mandatory = $true)]
    [string]
    $ConnectorsPath,
    [Parameter(Mandatory = $true)]
    [string]
    $ConnectorSettingsPath
)

if($Action -ne "None") {
    Invoke-DataConnector -ResourceGroupName $ResourceGroupName -Workspace $Workspace -Action $Action -ConnectorsPath $ConnectorsPath -ConnectorSettingsPath $ConnectorSettingsPath
}