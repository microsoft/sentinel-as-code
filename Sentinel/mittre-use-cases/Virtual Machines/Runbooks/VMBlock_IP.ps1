<# 
	This PowerShell script was automatically converted to PowerShell Workflow so it can be run as a runbook.
	Specific changes that have been made are marked with a comment starting with “Converter:”
#>
param
(
    [Parameter(Mandatory = $true)]
    [string]
    $ResourceGroupName,
    [Parameter(Mandatory = $true)]
    [string]
    $VirtualMachineName
)

# Converter: Wrapping initial script in an InlineScript activity, and passing any parameters for use within the InlineScript
# Converter: If you want this InlineScript to execute on another host rather than the Automation worker, simply add some combination of -PSComputerName, -PSCredential, -PSConnectionURI, or other workflow common parameters (http://technet.microsoft.com/en-us/library/jj129719.aspx) as parameters of the InlineScript

$servicePrincipalConnection = Get-AutomationConnection -Name "AzureRunAsConnection"
$servicePrincipalConnection

try {
    Write-Output	"Connecting  using $($servicePrincipalConnection.ApplicationId)"
    Connect-AzAccount `
                -ServicePrincipal `
                -Tenant $servicePrincipalConnection.TenantId `
                -ApplicationId $servicePrincipalConnection.ApplicationId `
                -CertificateThumbprint $servicePrincipalConnection.CertificateThumbprint
    Write-Output	"Connected with $($servicePrincipalConnection.ApplicationId)"
}
catch {
    Write-Error $_.Exception.Message
    exit
}

#create role assignment
$ServicePrincialAccount = Get-AutomationPSCredential -Name 'ServicePrincipal'

Write-Output "loging in wih ServicePrincialAccount  $($ServicePrincialAccount.username)"
#connect to Azure using ServicePrincialAccount
try {
    $VirtualMachine = Get-AzVm -ResourceGroupName $ResourceGroupName -Name $VirtualMachineName
    $NetworkInterface =  $VirtualMachine.NetworkProfile.NetworkInterfaces.id | Get-AzNetworkInterface	
    $NetworkSecurityGroup = Get-AzNetworkSecurityGroup -Name (Split-Path -Path $NetworkInterface.NetworkSecurityGroup.id -Leaf)
    $NetworkSecurityGroup | Add-AzNetworkSecurityRuleConfig -Name "Sentinel-Rule" `
                                            -Description "Automatic blocked IP by Sentinel" `
                                            -Access "Deny" `
                                            -Protocol "*" `
                                            -Direction "Inbound" `
                                            -Priority 100 `
                                            -SourceAddressPrefix $ipAddress `
                                            -SourcePortRange "*" `
                                            -DestinationAddressPrefix "*" `
                                            -DestinationPortRange "*" | Set-AzNetworkSecurityGroup
}
catch {
    Write-Error $_.Exception.Message
    exit
}