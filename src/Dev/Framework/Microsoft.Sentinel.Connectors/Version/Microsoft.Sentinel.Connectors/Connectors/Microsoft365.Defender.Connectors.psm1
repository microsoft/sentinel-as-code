$Module = Get-Module -Name Az.SecurityInsights -ListAvailable
if($null -eq $Module) {
    Install-Module -Name Az.SecurityInsights -Force
}

$ModulesLocation = Split-Path -Path $MyInvocation.MyCommand.Definition -Parent
Import-Module -Name "$($ModulesLocation)\Azure.Connectors.Common.psm1"

function New-AzSentinelMicrosoft365DefenderConnector {
    param (
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string] $ResourceGroup,   
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string] $Workspace,
        [Parameter(Mandatory = $false)]
        [ValidateSet("Enabled", "Disabled")]
        [string] $Alerts = "Enabled"
        )
     
    $connectorId = (New-Guid).Guid
    $AzContext= Get-AzContext
    $etag = (New-Guid).Guid
    $ApiUrl = "https://management.azure.com/subscriptions/$($azcontext.Subscription.Id)/resourceGroups/$($ResourceGroup)/providers/Microsoft.OperationalInsights/workspaces/$($Workspace)/providers/Microsoft.SecurityInsights/dataConnectors/$($connectorId)?api-version=2020-01-01"
    $RequestBody = @"
    {
        "kind": "OfficeATP",
        "etag": "$($etag)",
        "properties": {
          "tenantId": "$($AzContext.Tenant.Id)",
          "dataTypes": {
            "alerts": {
              "state": "$($Alerts.ToLowerInvariant())"
            }
          }
        }
      }
"@
    try {
        $authHeader = @{
            'Content-Type'='application/json'
            'Authorization'='Bearer ' + (Get-AzAccessToken).Token
        }
        $httpResponse = Invoke-webrequest -Uri $ApiUrl -Method PUT -Headers $authHeader -Body $RequestBody -UseBasicParsing
        Write-Host "Successfully updated data connector: Defender Office 365 logs Data Connector"
    }
    catch {
        $errorReturn = $_
        $errorResult = ($errorReturn | ConvertFrom-Json ).error
        Write-Verbose $_
        Write-Error "Unable to invoke webrequest with error message: $($errorResult.message)" -ErrorAction Stop
    }       
}

class Microsoft365DefenderDataConnector : DataConnector {

    Microsoft365DefenderDataConnector () {

    }

    [void] Invoke ([string]$ResourceGroup, [string]$Workspace, [ConnectorAction] $Action, [Hashtable] $Parameters) {
        
        $Alerts = $Parameters.Alerts 
        if([string]::IsNullOrEmpty($Alerts)){
            $Alerts = "Enabled"
        }

        RunAs {
            switch ($Action) {
                "Enable" {  
                    New-AzSentinelMicrosoft365DefenderConnector -ResourceGroup $ResourceGroup `
                                                    -Workspace $Workspace `
                                                    -Alerts $Alerts
                }
                "Update" {  
                    $Connector = Get-AzSentinelDataConnector -ResourceGroupName $ResourceGroup -WorkspaceName $Workspace | Where-Object {$_.Kind -eq "OfficeATP"}
                    if($null -ne $Connector){
                        Remove-AzSentinelDataConnector -DataConnectorId $Connector.Name -ResourceGroupName $ResourceGroup -WorkspaceName $Workspace
                        New-AzSentinelMicrosoft365DefenderConnector -ResourceGroup $ResourceGroup `
                                                    -Workspace $Workspace `
                                                    -Alerts $Alerts 
                    }
                    else {
                        throw "Connector cannot be found"
                    }
                }
                "Disable" {
                    $Connector = Get-AzSentinelDataConnector -ResourceGroupName $ResourceGroup -WorkspaceName $Workspace |?{$_.Kind -eq "OfficeATP"}
                    if($null -ne $Connector){
                        Remove-AzSentinelDataConnector -DataConnectorId $Connector.Name -ResourceGroupName $ResourceGroup -WorkspaceName $Workspace
                    }
                    else {
                        throw "Connector cannot be found"
                    }
                }
                "Check" {
                    $Connector = Get-AzSentinelDataConnector -ResourceGroupName $ResourceGroup -WorkspaceName $Workspace |?{$_.Kind -eq "OfficeATP"}
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