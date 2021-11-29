$Module = Get-Module -Name Az.SecurityInsights -ListAvailable
if($null -eq $Module) {
    Install-Module -Name Az.SecurityInsights -Force
}

$ModulesLocation = Split-Path -Path $MyInvocation.MyCommand.Definition -Parent
Import-Module -Name "$($ModulesLocation)\Azure.Connectors.Common.psm1"

class AzureActiveDirectoryIdentityProtectionDataConnector : DataConnector {

    AzureActiveDirectoryIdentityProtectionDataConnector () {

    }

    [void] Invoke ([string]$ResourceGroup, [string]$Workspace, [ConnectorAction] $Action, [Hashtable] $Parameters) {
        RunAs {
            if($null -ne $Parameters.Alerts) {
                $Alerts = $Parameters.Alerts
            }
            switch ($Action) {
                "Enable" {  
                    New-AzSentinelDataConnector -ResourceGroupName $ResourceGroup -WorkspaceName $Workspace -AzureActiveDirectory -Alerts $Alerts
                }
                "Update" {  
                    $Connector = Get-AzSentinelDataConnector -ResourceGroupName $ResourceGroup -WorkspaceName $Workspace | Where-Object { $_.Kind -eq "AzureActiveDirectory" }
                    Write-Output $Connector
                    if($null -ne $Connector) {
                        Update-AzSentinelDataConnector -DataConnectorId $Connector.Name -ResourceGroupName $ResourceGroup -WorkspaceName $Workspace -Alerts $Alerts | Out-Null
                    }
                    else {
                        Write-Error "Connector cannot be found"
                    }        
                }
                "Disable" {
                    $Connector = Get-AzSentinelDataConnector -ResourceGroupName $ResourceGroup -WorkspaceName $Workspace | Where-Object { $_.Kind -eq "AzureActiveDirectory" }
                    if($null -ne $Connector) {
                        Remove-AzSentinelDataConnector -DataConnectorId $Connector.Name -ResourceGroupName $ResourceGroup -WorkspaceName $Workspace
                    }
                    else {
                        Write-Error "Connector cannot be found"
                    }
                }
                "Check" {
                    $Connector = Get-AzSentinelDataConnector -ResourceGroupName $ResourceGroup -WorkspaceName $Workspace | Where-Object { $_.Kind -eq "AzureActiveDirectory" }
                    Write-Output $Connector
                }
                Default {
                    throw "Unexepected Action Requested"
                }
            }
        } -KeyVault $Parameters.KeyVault -SecretName $Parameters.SecretName -Impersonate:$Parameters.ImpersonationEnabled
    }
}
