[CmdletBinding()]
param (
    [Parameter(Mandatory = $true)]
    [string]
    $EnvironmentName,
    [Parameter(Mandatory = $true)]
    [string]
    $Path
)

$EnvironmentDefinition = Get-EnvironmentDefinition -Path $Path -EnvironmentName $EnvironmentName
if($null -ne $EnvironmentDefinition) {
    Write-Verbose $EnvironmentDefinition
    return $EnvironmentDefinition.Connection
}
else {
    throw "Environment $($EnvironmentName) in Path $($Path) cannot be resolved"
}