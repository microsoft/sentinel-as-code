[CmdletBinding()]
param (
    [Parameter(Mandatory = $true)]
    [string]
    $Name
)

Unregister-PSRepository -Name $Name