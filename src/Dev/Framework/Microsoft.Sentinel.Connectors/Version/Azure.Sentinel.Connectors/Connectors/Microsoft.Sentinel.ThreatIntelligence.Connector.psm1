$Module = Get-Module -Name Az.SecurityInsights -ListAvailable
if($null -eq $Module) {
    Install-Module -Name Az.SecurityInsights -Force
}

class ThreatIntelligenceDataConnector : DataConnector {

    ThreatIntelligenceDataConnector () {

    }

    [void] Invoke ([string]$ResourceGroup, [string]$Workspace, [ConnectorAction] $Action, [Hashtable] $Parameters) {
        switch ($Action) {
            "Enable" {  
                New-AzSentinelDataConnector -ResourceGroupName $ResourceGroup -WorkspaceName $Workspace -ThreatIntelligence -Indicators $Parameters.Indicators
            }
            "Update" {  
                $Connector = Get-AzSentinelDataConnector -ResourceGroupName $ResourceGroup -WorkspaceName $Workspace | Where-Object { $_.Kind -eq "ThreatIntelligence" }
                Write-Output $Connector
                if($null -ne $Connector) {
                    Update-AzSentinelDataConnector -DataConnectorId $Connector.Name -ResourceGroupName $ResourceGroup -WorkspaceName $Workspace -ThreatIntelligence -Indicators $Parameters.Indicators | Out-Null
                }
                else {
                    Write-Error "Connector cannot be found"
                }        
            }
            "Disable" {
                $Connector = Get-AzSentinelDataConnector -ResourceGroupName $ResourceGroup -WorkspaceName $Workspace | Where-Object { $_.Kind -eq "ThreatIntelligence" }
                if($null -ne $Connector) {
                    Remove-AzSentinelDataConnector -DataConnectorId $Connector.Name -ResourceGroupName $ResourceGroup -WorkspaceName $Workspace
                }
                else {
                    Write-Error "Connector cannot be found"
                }
            }
            "Check" {
                $Connector = Get-AzSentinelDataConnector -ResourceGroupName $ResourceGroup -WorkspaceName $Workspace | Where-Object { $_.Kind -eq "ThreatIntelligence" }
                Write-Output $Connector
            }
            Default {
                throw "Unexepected Action Requested"
            }
        }
    }
}