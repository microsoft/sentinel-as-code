[CmdletBinding()]
param (
    [Parameter(Mandatory = $true)]
    [string]
    $Path,
    [Parameter(Mandatory = $false)]
    [string]
    $EnvironmentName
)

return Resolve-EnvironmentDefinition -Path $Path -EnvironmentName $EnvironmentName