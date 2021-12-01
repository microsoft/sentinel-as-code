$Module = Get-Module -Name Az.SecurityInsights -ListAvailable
if($null -eq $Module) {
    Install-Module -Name Az.SecurityInsights -Force
}

class MicrosoftDefenderCloud : DataConnector {

    MicrosoftDefenderCloud () {

    }

    [void] Invoke ([string]$ResourceGroup, [string]$Workspace, [ConnectorAction] $Action, [Hashtable] $Parameters) {
        RunAs {
            $Subscriptions = $Parameters.Subscriptions
            if($null -eq $Subscriptions) {
                $SubscriptionId = (Get-Context).Subscription.Id
                $Subscriptions = @($SubscriptionId)
            }
            $Subscriptions | ForEach-Object {
                $SubscriptionId = $_
                switch ($Action) {
                    "Enable" {  
                        New-AzSentinelDataConnector -ResourceGroupName $ResourceGroup -WorkspaceName $Workspace -AzureSecurityCenter -SubscriptionId $_ -Alerts $Parameters.Alerts
                    }
                    "Update" {  
                        $Connector = Get-AzSentinelDataConnector -ResourceGroupName $ResourceGroup -WorkspaceName $Workspace | Where-Object { $_.Kind -eq "AzureSecurityCenter" }
                        Write-Output $Connector
                        if($null -ne $Connector) {
                            Update-AzSentinelDataConnector -DataConnectorId $Connector.Name -ResourceGroupName $ResourceGroup -WorkspaceName $Workspace -Alerts $Parameters.Alerts | Out-Null
                        }
                        else {
                            Write-Error "Connector cannot be found"
                        }        
                    }
                    "Disable" {
                        $Connector = Get-AzSentinelDataConnector -ResourceGroupName $ResourceGroup -WorkspaceName $Workspace | Where-Object { $_.Kind -eq "AzureSecurityCenter" }
                        if($null -ne $Connector) {
                            Remove-AzSentinelDataConnector -DataConnectorId $Connector.Name -ResourceGroupName $ResourceGroup -WorkspaceName $Workspace
                        }
                        else {
                            Write-Error "Connector cannot be found"
                        }
                    }
                    "Check" {
                        $Connector = Get-AzSentinelDataConnector -ResourceGroupName $ResourceGroup -WorkspaceName $Workspace | Where-Object { $_.Kind -eq "AzureSecurityCenter" }
                        Write-Output $Connector
                    }
                    Default {
                        throw "Unexepected Action Requested"
                    }
                }
            }
        } `
        -KeyVault $Parameters.KeyVault -SecretName $Parameters.SecretName -Impersonate:$Parameters.ImpersonationEnabled
    }
}