$Module = Get-Module -Name Az.SecurityInsights -ListAvailable
if($null -eq $Module) {
    Install-Module -Name Az.SecurityInsights -Force
}

$ModulesLocation = Split-Path -Path $MyInvocation.MyCommand.Definition -Parent
Import-Module -Name "$($ModulesLocation)\Azure.Connectors.Common.psm1"

class AzureActiveDirectoryDataConnector : DataConnector {

    AzureActiveDirectoryIdentityProtectionDataConnector () {

    }

    [void] Invoke ([string]$ResourceGroup, [string]$Workspace, [ConnectorAction] $Action, [Hashtable] $Parameters) {
        
        RunAs {
            switch ($Action) {
                "Enable" {  
                    $SignInLogs = $false
                    $AuditLogs = $false
                    $NonInteractiveUserSignInLogs = $false
                    $ServicePrincipalSignInLogs = $false
                    $ManagedIdentitySignInLogs = $false
                    $ProvisioningLogs = $false
                    if($null -ne $Parameters.SignInLogs) {
                        $SignInLogs = $Parameters.SignInLogs
                    }
                    if($null -ne $Parameters.AuditLogs) {
                        $AuditLogs = $Parameters.AuditLogs
                    }
                    if($null -ne $Parameters.NonInteractiveUserSignInLogs) {
                        $NonInteractiveUserSignInLogs = $Parameters.NonInteractiveUserSignInLogs
                    }
                    if($null -ne $Parameters.ServicePrincipalSignInLogs) {
                        $ServicePrincipalSignInLogs = $Parameters.ServicePrincipalSignInLogs
                    }
                    if($null -ne $Parameters.ManagedIdentitySignInLogs) {
                        $ManagedIdentitySignInLogs = $Parameters.ManagedIdentitySignInLogs
                    }
                    if($null -ne $Parameters.ProvisioningLogs) {
                        $ProvisioningLogs = $Parameters.ProvisioningLogs
                    }
                    Enable-AzureADConnector -ResourceGroup $ResourceGroup `
                                            -Workspace $Workspace `
                                            -SignInLogs $SignInLogs `
                                            -AuditLogs $AuditLogs `
                                            -NonInteractiveUserSignInLogs $NonInteractiveUserSignInLogs `
                                            -ServicePrincipalSignInLogs $ServicePrincipalSignInLogs `
                                            -ManagedIdentitySignInLogs $ManagedIdentitySignInLogs `
                                            -ProvisioningLogs $ProvisioningLogs 
                }
                "Update" {  
                    Enable-AzureADConnector -ResourceGroup $ResourceGroup `
                                            -Workspace $Workspace `
                                            -SignInLogs $Parameters.SignInLogs `
                                            -AuditLogs $Parameters.AuditLogs `
                                            -NonInteractiveUserSignInLogs $Parameters.NonInteractiveUserSignInLogs `
                                            -ServicePrincipalSignInLogs $Parameters.ServicePrincipalSignInLogs `
                                            -ManagedIdentitySignInLogs $Parameters.ManagedIdentitySignInLogs `
                                            -ProvisioningLogs $Parameters.ProvisioningLogs       
                }
                "Disable" {
                    throw "Not supported"
                }
                "Check" {
                    $Connector = Get-AzSentinelDataConnector -ResourceGroup $ResourceGroup `
                                                            -Workspace $Workspace
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

function Enable-AzureADConnector {
    param
    (
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]
        $ResourceGroup, 
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]
        $Workspace, 
        [Parameter(Mandatory = $false)]
        [ValidateNotNullOrEmpty()]
        [bool]
        $SignInLogs = $true, 
        [Parameter(Mandatory = $false)]
        [ValidateNotNullOrEmpty()]
        [bool]
        $AuditLogs = $true,
        [Parameter(Mandatory = $false)]
        [ValidateNotNullOrEmpty()]
        [bool]
        $NonInteractiveUserSignInLogs = $true,
        [Parameter(Mandatory = $false)]
        [ValidateNotNullOrEmpty()]
        [bool]
        $ServicePrincipalSignInLogs = $true,
        [Parameter(Mandatory = $false)]
        [ValidateNotNullOrEmpty()]
        [bool]
        $ManagedIdentitySignInLogs = $true,
        [Parameter(Mandatory = $false)]
        [ValidateNotNullOrEmpty()]
        [bool]
        $ProvisioningLogs = $true
    )

    $InsightsWorkspace = Get-AzOperationalInsightsWorkspace -ResourceGroupName $ResourceGroup -Name $Workspace -ErrorAction Stop
    $ConnectorName = "Sentinel_$($Workspace)"
    $DiagnosticsManagementApiUrl = "/providers/microsoft.aadiam/diagnosticSettings/{0}?api-version=2017-04-01-preview" -f $ConnectorName
    $RequestBody = @"
{
    "id": "providers/microsoft.aadiam/diagnosticSettings/$ruleName",
    "type": null,
    "name": "Sentinel Log Analytics",
    "location": null,
    "kind": null,
    "tags": null,
    "properties": {
      "storageAccountId": null,
      "serviceBusRuleId": null,
      "workspaceId": "$($InsightsWorkspace.ResourceId)",
      "eventHubAuthorizationRuleId": null,
      "eventHubName": null,
      "metrics": [],
      "logs": [
        {
          "category": "AuditLogs",
          "enabled": $($AuditLogs | ConvertTo-Json),
          "retentionPolicy": { "enabled": false, "days": 0 }
        },
        {
          "category": "SignInLogs",
          "enabled": $($SignInLogs | ConvertTo-Json),
          "retentionPolicy": { "enabled": false, "days": 0 }
        },
        {
            "category": "NonInteractiveUserSignInLogs",
            "enabled": $($NonInteractiveUserSignInLogs | ConvertTo-Json),
            "retentionPolicy": { "enabled": false, "days": 0 }
        },
        {
            "category": "ServicePrincipalSignInLogs",
            "enabled": $($ServicePrincipalSignInLogs | ConvertTo-Json),
            "retentionPolicy": { "enabled": false, "days": 0 }
        },
        {
            "category": "ManagedIdentitySignInLogs",
            "enabled": $($ManagedIdentitySignInLogs | ConvertTo-Json),
            "retentionPolicy": { "enabled": false, "days": 0 }
        },
        {
            "category": "ProvisioningLogs",
            "enabled": $($ProvisioningLogs | ConvertTo-Json),
            "retentionPolicy": { "enabled": false, "days": 0 }
        }
      ]
    },
    "identity": null
  }
"@
    try {
        $httpResponse = Invoke-AzRestMethod -Method Put -Path $DiagnosticsManagementApiUrl -Payload $RequestBody
        Write-Host "Successfully updated data connector: Azure Active Directory Diagnostics"
    }
    catch {
        $errorReturn = $_
        $errorResult = ($errorReturn | ConvertFrom-Json ).error
        Write-Verbose $_
        Write-Error "Unable to invoke webrequest with error message: $($errorResult.message)" -ErrorAction Stop
    }       
}

function Get-AzureADConnector {
    param
    (
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]
        $ResourceGroup, 
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]
        $Workspace
    )

    # Check exists workspace
    Get-AzOperationalInsightsWorkspace -ResourceGroupName $ResourceGroup -Name $Workspace -ErrorAction Stop
    $ConnectorName = "Sentinel_$($Workspace)"
    $DiagnosticsManagementApiUrl = "https://management.azure.com/providers/microsoft.aadiam/diagnosticSettings/{0}?api-version=2017-04-01-preview" -f $ConnectorName
    
    try {
        $httpResponse = Invoke-AzRestMethod -Method Get -Uri $DiagnosticsManagementApiUrl
        Write-Host "Successfully found data connector: Azure Active Directory with status: $($httpResponse.StatusDescription)"
        return $httpResponse.Content | ConvertFrom-Json        
    }
    catch {
        $errorReturn = $_
        $errorResult = ($errorReturn | ConvertFrom-Json ).error
        Write-Verbose $_
        Write-Error "Unable to invoke webrequest with error message: $($errorResult.message)" -ErrorAction Stop
    }       
}

