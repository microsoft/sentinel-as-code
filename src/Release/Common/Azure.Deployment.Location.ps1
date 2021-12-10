[CmdletBinding()]
param (
    [Parameter(Mandatory = $true)]
    [string]
    $Location,
    [Parameter(Mandatory = $true)]
    [string]
    $VariableName
)

Write-Debug "Resolving the Location requested: $($Location) over destination variable: $($VariableName)"
if($null -ne $Location) {
    Write-Debug "Location resolution complete. Checking the Location"
    $LocationSuffix = Get-AzLocationSuffix -Location $Location
    Write-Debug "Location resolution complete. Location validated"
    Write-Debug "Location Suffix: $($LocationSuffix)"
    Write-Host "##vso[task.setvariable variable=$($VariableName);issecret=false]$($LocationSuffix)"
    Write-Host "Setting $($VariableName) with the value: $($LocationSuffix)"
}
else {
    Write-Debug "Location not found or is Unknown"
    throw "Unknown Location $($Location)"
}
