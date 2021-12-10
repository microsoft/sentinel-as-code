[CmdletBinding()]
param (
    [Parameter(Mandatory = $true)]
    [string]
    $ResourceGroupName,
    [Parameter(Mandatory = $true)]
    [string]
    $Path
)

if(Test-Path -Path $Path) {
    $ConnectionsPath = Join-Path -Path $Path -ChildPath "Connections"
    if(Test-Path -Path $ConnectionsPath) {
        $ConnectionItems = Get-ChildItem -Path $ConnectionsPath  -Include "*.json" -Exclude "*.parameters.json" -File -Recurse
        if($null -ne $ConnectionItems -and $ConnectionItems.Length -gt 0) {
            $ConnectionItems | ForEach-Object {
                $ParametersFileItemPath = Join-Path -Path $_.Directory.FullName -ChildPath $_.Name.Replace(".json", ".parameters.json")
                if(Test-Path -Path $ParametersFileItemPath) {
                    New-AzResourceGroupDeployment -Name $_.Name.ToLowerInvariant().Replace(".json", [string]::Empty) -ResourceGroupName $ResourceGroupName -Mode Incremental -TemplateFile $_.FullName -TemplateParameterFile $ParametersFileItemPath
                }
                else {
                    New-AzResourceGroupDeployment -Name $_.Name -ResourceGroupName $ResourceGroupName -Mode Incremental -TemplateFile $_.FullName 
                }
            }
        }
        else {
            Write-Warning "Connections not available on the specified Path"
        }
    }
    else {
        throw "Connection Path $($ConnectionsPath) cannot be resolved"
    }
}
else {
    throw "Path $($Path) cannot be resolved"
}