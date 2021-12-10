[CmdletBinding()]
param (
    [Parameter(Mandatory = $true)]
    [string]
    $ResourceGroupName,
    [Parameter(Mandatory = $true)]
    [string]
    $Path
)

Export-ContextSettings -ResourceGroupName $ResourceGroupName -Path $Path