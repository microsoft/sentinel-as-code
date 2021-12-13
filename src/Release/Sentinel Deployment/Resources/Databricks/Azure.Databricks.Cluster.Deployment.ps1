[CmdletBinding()]
param (
    [Parameter(Mandatory = $true)]
    [string]
    $Name,
    [Parameter(Mandatory = $true)]
    [string]
    $ClusterName,
    [Parameter(Mandatory = $true)]
    [string]
    $Location,
    [Parameter(Mandatory = $true)]
    [string]
    $ResourceGroupName,
    [Parameter(Mandatory = $true)]
    [int]
    $MinNodes,
    [Parameter(Mandatory = $true)]
    [int]
    $MaxNodes
)

Import-Module -Name "$($PSScriptRoot)\Azure.Databricks.Cluster.Deployment.psm1" -Force
$AzContext = Get-AzContext 
if($null -ne $AzContext)
{
    $TenantId = $AzContext.Tenant.Id
    $SubscriptionId = $AzContext.Subscription.Id
    $Account = $AzContext.Account
    if($null -ne $Account)
    {
        $ClientId = $Account.Id
        $Secret = $Account.ExtendedProperties.ServicePrincipalSecret
        New-AzureDatabricksCluster -ApplicationId $ClientId -Secret $Secret -TenantId $TenantId -SubscriptionId $SubscriptionId -ResourceGroupName $ResourceGroupName -DatabricksName $Name -DatabricksClusterName "Default" -DatabrickscontosoVersion "8.1.x-scala2.12" -DatabricksPythonVersion 3 -DatabricksNodeType "Standard_D3_v2" -DatabricksMasterNodeType "Standard_D3_v2" -MinNodes $MinNodes -MaxNodes $MaxNodes -Location $Location        
    }
}