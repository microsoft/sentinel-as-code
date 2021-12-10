[CmdletBinding()]
param (
    [Parameter(Mandatory = $false)]
    [string]
    $ResourceName,
    [Parameter(Mandatory = $false)]
    [string]
    $ResourceGroupName,
    [Parameter(Mandatory = $false)]
    [string]
    $ResourceType,
    [Parameter(Mandatory = $false)]
    [string]
    $VariableNameExists,
    [Parameter(Mandatory = $false)]
    [string]
    $VariableNameNotDefined
)

if(-not [string]::IsNullOrEmpty($ResourceName) -and -not [string]::IsNullOrEmpty($ResourceGroupName) -and -not [string]::IsNullOrEmpty($ResourceType)) {
    $Resource = Get-AzResource -Name $ResourceName -ResourceGroupName $ResourceGroupName -ResourceType $ResourceType -ErrorAction SilentlyContinue
    $ResourceExists = $null -ne $Resource
    $IsDefined = $true
    Write-Host "##vso[task.setvariable variable=$($VariableNameExists);issecret=false]$($ResourceExists)"
    Write-Host "##vso[task.setvariable variable=$($VariableNameNotDefined);issecret=false]$($IsDefined)"
}
else {
    $ResourceExists = $false
    $IsDefined = $false
    Write-Host "##vso[task.setvariable variable=$($VariableNameExists);issecret=false]$($ResourceExists)"
    Write-Host "##vso[task.setvariable variable=$($VariableNameNotDefined);issecret=false]$($IsDefined)"
}