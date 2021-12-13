function New-AzureDatabricksCluster {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [string]
        $ApplicationId,
        [Parameter(Mandatory = $true)]
        [string]
        $Secret,
        [Parameter(Mandatory = $true)]
        [string]
        $TenantId,
        [Parameter(Mandatory = $true)]
        [string]
        $SubscriptionId,
        [Parameter(Mandatory = $true)]
        [string]
        $ResourceGroupName,
        [Parameter(Mandatory = $true)]
        [string]
        $DatabricksName,
        [Parameter(Mandatory = $true)]
        [string]
        $DatabricksClusterName,
        [Parameter(Mandatory = $true)]
        [string]
        $DatabrickscontosoVersion,    
        [Parameter(Mandatory = $false)]
        [string]
        $DatabricksPythonVersion = 3,
        [Parameter(Mandatory = $true)]
        [string]
        $DatabricksNodeType,    
        [Parameter(Mandatory = $true)]
        [string]
        $DatabricksMasterNodeType,
        [Parameter(Mandatory = $true)]
        [string]
        $MinNodes,
        [Parameter(Mandatory = $true)]
        [string]
        $MaxNodes,
        [Parameter(Mandatory = $false)]
        [string]
        $AutoTerminationTimeOut = 30,
        [Parameter(Mandatory = $true)]
        [string]
        $Location
    )

    Install-Module -Name azure.databricks.cicd.tools -Force -AllowClobber
    Connect-Databricks -ApplicationId $ApplicationId -Secret $Secret -TenantId $TenantId -SubscriptionId $SubscriptionId -ResourceGroupName $ResourceGroupName -WorkspaceName $DatabricksName -Region $Location
    $BearerTokenVault = New-DatabricksBearerToken -LifetimeSeconds 3600 -Comment "DevOps Bearer Token"
    $BearerToken = $BearerTokenVault.token_value
    $ClusterId = New-DatabricksCluster -BearerToken $BearerToken -Region $Location -ClusterName $DatabricksClusterName -contosoVersion $DatabrickscontosoVersion -NodeType $DatabricksNodeType -DriverNodeType $DatabricksMasterNodeType -MinNumberOfWorkers $MinNodes -MaxNumberOfWorkers $MaxNodes -AutoTerminationMinutes $AutoTerminationTimeOut -PythonVersion $DatabricksPythonVersion
    do {
        $Cluster = Get-DatabricksClusters -BearerToken $BearerToken -Region $Location -ClusterId $ClusterId
        Write-Output "Status: $($Cluster.state) with message: $($Cluster.state_message)" 
    } 
    while ($Cluster.state -eq "PENDING")

    if($Cluster.state -ne "RUNNING") {
        Start-DatabricksCluster -BearerToken $BearerToken -Region $Location -ClusterName $DatabricksClusterName 
    }
}