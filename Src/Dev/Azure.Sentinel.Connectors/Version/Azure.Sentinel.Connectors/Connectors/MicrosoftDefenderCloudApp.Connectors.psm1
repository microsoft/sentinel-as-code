$Module = Get-Module -Name Az.SecurityInsights -ListAvailable
if($null -eq $Module) {
    Install-Module -Name Az.SecurityInsights -Force
}

$ModulesLocation = Split-Path -Path $MyInvocation.MyCommand.Definition -Parent
Import-Module -Name "$($ModulesLocation)\Azure.Connectors.Common.psm1"

class MicrosoftDefenderCloudAppDataConnector : DataConnector {

    MicrosoftDefenderCloudAppDataConnector () {
    }
    [void] Invoke ([string]$ResourceGroup, [string]$Workspace, [ConnectorAction] $Action, [Hashtable] $Parameters) {
        $Alerts = $Parameters.Alerts 
        if([string]::IsNullOrEmpty($Alerts)){
            $Alerts = "Enabled"
        }

        $DiscoveryLogs = $Parameters.DiscoveryLogs 
        if([string]::IsNullOrEmpty($DiscoveryLogs)){
            $DiscoveryLogs = "Enabled"
        }

        RunAs {
            switch ($Action) {
                "Enable" {  
                    New-AzSentinelDataConnector -ResourceGroupName $ResourceGroup `
                                                -WorkspaceName $Workspace `
                                                -MicrosoftCloudAppSecurity `
                                                -Alerts $Alerts `
                                                -DiscoveryLogs $DiscoveryLogs

                }
                "Update" {  
                    $connector = Get-AzSentinelDataConnector -ResourceGroupName $ResourceGroup -WorkspaceName $Workspace |?{$_.Kind -eq "MicrosoftCloudAppSecurity"}
                    if($null -ne $connector){
                    Update-AzSentinelDataConnector -DataConnectorId $connector.Name -ResourceGroupName $ResourceGroup -WorkspaceName $Workspace -Alerts $Parameters.Alerts -DiscoveryLogs $Parameters.DiscoveryLogs
                    }
                    else {
                        throw "Connector cannot be found"
                    }  
                }
                "Disable" {
                    $connector = Get-AzSentinelDataConnector -ResourceGroupName $ResourceGroup -WorkspaceName $Workspace |?{$_.Kind -eq "MicrosoftCloudAppSecurity"}
                    if($null -ne $connector){
                        Remove-AzSentinelDataConnector -DataConnectorId $connector.Name -ResourceGroupName $ResourceGroup -WorkspaceName $Workspace
                    }
                    else {
                        throw "Connector cannot be found"
                    }
                }
                "Check" {
                    $connector = Get-AzSentinelDataConnector -ResourceGroupName $ResourceGroup -WorkspaceName $Workspace |?{$_.Kind -eq "MicrosoftCloudAppSecurity"}
                    Write-Output $Connector
                }
                Default {
                    throw "Unexepected Action Requested"
                }
            } 
        } `
        -KeyVault $Parameters.KeyVault -SecretName $Parameters.SecretName -Impersonate:$Parameters.ImpersonationEnabled
    }
}
