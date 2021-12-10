$Module = Get-Module -Name Az.SecurityInsights -ListAvailable
if($null -eq $Module) {
    Install-Module -Name Az.SecurityInsights -Force
}

$ModulesLocation = Split-Path -Path $MyInvocation.MyCommand.Definition -Parent
Import-Module -Name "$($ModulesLocation)\Azure.Connectors.Common.psm1"

function New-AzSentinelMicrosoft365LogConnector {
    param (
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string] $ResourceGroup,   
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string] $Workspace,
        [Parameter(Mandatory = $false)]
        [ValidateSet("Enabled", "Disabled")]
        [string]  $Exchange = "Enabled",
        [Parameter(Mandatory = $false)]
        [ValidateSet("Enabled", "Disabled")]
        [string] $Sharepoint = "Enabled",
        [Parameter(Mandatory = $true)]
        [ValidateSet("Enabled", "Disabled")]
        [string]$Teams = "Enabled"
        )
        
    $connectorId = (New-Guid).Guid
    $AzContext= Get-AzContext
    $etag = (New-Guid).Guid
    $ApiUrl = "https://management.azure.com/subscriptions/$($azcontext.Subscription.Id)/resourceGroups/$($ResourceGroup)/providers/Microsoft.OperationalInsights/workspaces/$($Workspace)/providers/Microsoft.SecurityInsights/dataConnectors/$($connectorId)?api-version=2020-01-01"
    $RequestBody = @"
    {
        "kind": "Office365",
        "etag": "$($etag)",
        "properties": {
          "tenantId": "$($AzContext.Tenant.Id)",
          "dataTypes": {
            "sharePoint": {
              "state": "$($Sharepoint.ToLowerInvariant())"
            },
            "exchange": {
              "state": "$($Exchange.ToLowerInvariant())"
            },
            "teams": {
              "state": "$($Teams.ToLowerInvariant())"
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
        $httpResponse =Invoke-webrequest -Uri $ApiUrl -Method PUT -Headers $authHeader -Body $RequestBody -UseBasicParsing
        Write-Host "Successfully updated data connector: Office 365 logs Data Connector"
    }
    catch {
        $errorReturn = $_
        $errorResult = ($errorReturn | ConvertFrom-Json ).error
        Write-Verbose $_
        Write-Error "Unable to invoke webrequest with error message: $($errorResult.message)" -ErrorAction Stop
    }       
}

class Microsoft365LogsDataConnector : DataConnector {

    Microsoft365LogsDataConnector () {

    }

    [void] Invoke ([string]$ResourceGroup, [string]$Workspace, [ConnectorAction] $Action, [Hashtable] $Parameters) {
        $Sharepoint = $Parameters.SharePoint
        if([string]::IsNullOrEmpty($Sharepoint)) {
            $Sharepoint = "Enabled"
        }

        $Exchange = $Parameters.Exchange
        if([string]::IsNullOrEmpty($Exchange)) {
            $Exchange = "Enabled"
        }

        $Teams = $Parameters.Teams
        if([string]::IsNullOrEmpty($Teams)) {
            $Teams = "Enabled"
        }

        RunAs {
            switch ($Action) {
                "Enable" {  
                    New-AzSentinelMicrosoft365LogConnector -ResourceGroup $ResourceGroup `
                                                    -Workspace $Workspace `
                                                    -SharePoint $SharePoint `
                                                    -Exchange $Exchange `
                                                    -Teams $Teams
                }
                "Update" {  
                    $connector = Get-AzSentinelDataConnector -ResourceGroupName $ResourceGroup -WorkspaceName $Workspace | Where-Object {$_.Kind -eq "Office365"}
                    if($null -ne $connector){
                        Remove-AzSentinelDataConnector -DataConnectorId $connector.Name -ResourceGroupName $ResourceGroup -WorkspaceName $Workspace
                        New-AzSentinelMicrosoft365LogConnector -ResourceGroup $ResourceGroup `
                                                    -Workspace $Workspace `
                                                    -SharePoint $SharePoint `
                                                    -Exchange $Exchange `
                                                    -Teams $Teams
                    }
                    else {
                        throw "Connector cannot be found"
                    }
                }
                "Disable" {
                    $connector = Get-AzSentinelDataConnector -ResourceGroupName $ResourceGroup -WorkspaceName $Workspace |?{$_.Kind -eq "Office365"}
                    if($null -ne $connector){
                        Remove-AzSentinelDataConnector -DataConnectorId $connector.Name -ResourceGroupName $ResourceGroup -WorkspaceName $Workspace
                    }
                    else {
                        throw "Connector cannot be found"
                    }
                }
                "Check" {
                    $connector = Get-AzSentinelDataConnector -ResourceGroupName $ResourceGroup -WorkspaceName $Workspace |?{$_.Kind -eq "Office365"}
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