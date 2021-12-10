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

Import-AzSentinelWorkbook -ResourceGroup $ResourceGroupName -Workspace $WorkspaceName -Path $Path