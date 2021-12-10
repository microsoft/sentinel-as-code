$Module = Get-Module -Name Az.SecurityInsights -ListAvailable
if($null -eq $Module) {
    Install-Module -Name Az.SecurityInsights -Force
}

$ModulesLocation = Split-Path -Path $MyInvocation.MyCommand.Definition -Parent
Import-Module -Name "$($ModulesLocation)\Azure.Connectors.Common.psm1"

function New-AzSentinelTaxiiConnector {
    param (
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string] $ResourceGroup,   
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string] $Workspace,
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string] $TaxiiServer,
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string] $CollectionId,
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string] $WorkspaceId,
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string] $FriendlyName,
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string] $UserName,
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string] $Password,
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [ValidateSet("OnePerMinute", "OnePerHour", "OnePerDay")]
        [string] 
        $PoolingFrequency,
        [Parameter(Mandatory = $false)]
        [ValidateSet("Enabled", "Disabled")]
        [string] $TaxiiClient = "Enabled",
        [Parameter(Mandatory = $false)]
        [string] 
        $TaxiiLookbackPeriod = "01/01/1970 00:00:00"
        )
     

    switch ($PoolingFrequency) {
        "OnePerMinute" {
            $PoolingFrequencyValue = 0
        }
        "OnePerHour" {
            $PoolingFrequencyValue = 1
        }
        "OnePerDay" {
            $PoolingFrequencyValue = 2
        }
    }
    
    
    $connectorId = (New-Guid).Guid
    $AzContext= Get-AzContext
    $etag = (New-Guid).Guid
    $ApiUrl = "https://management.azure.com/subscriptions/$($azcontext.Subscription.Id)/resourceGroups/$($ResourceGroup)/providers/Microsoft.OperationalInsights/workspaces/$($Workspace)/providers/Microsoft.SecurityInsights/dataConnectors/$($connectorId)?api-version=2020-01-01"
    $Body = [PSCustomObject]@{
        kind = "ThreatIntelligenceTaxii"
        etag = $etag
        properties = [PSCustomObject]@{
            tenantId = $AzContext.Tenant.Id
            taxiiServer = $TaxiiServer
            collectionId = $CollectionId
            workspaceId = $WorkspaceId
            friendlyName = $FriendlyName
            userName = $UserName
            password = $Password
            taxiiLookbackPeriod = $Taxii
            pollingFrequency = $PoolingFrequencyValue
            dataTypes = [PSCustomObject]@{
                taxiiClient = [PSCustomObject]@{
                    State = $TaxiiClient.ToLowerInvariant()
                }
            }
        }
    }
    $RequestBody = ConvertTo-Json $Body -Depth 5

    try {
        $authHeader = @{
            'Content-Type'='application/json'
            'Authorization'='Bearer ' + (Get-AzAccessToken).Token
        }
        $httpResponse = Invoke-webrequest -Uri $ApiUrl -Method PUT -Headers $authHeader -Body $RequestBody -UseBasicParsing
        Write-Host "Successfully updated data connector: Taxii Data Connector"
    }
    catch {
        $errorReturn = $_
        $errorResult = ($errorReturn | ConvertFrom-Json ).error
        Write-Verbose $_
        Write-Error "Unable to invoke webrequest with error message: $($errorResult.message)" -ErrorAction Stop
    }       
}

function Get-AzTaxiiSentinelConnector{
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string] $ResourceGroup,   
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string] $Workspace,
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string] $TaxiiServer,
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string] $CollectionId
    )

    $AzContext= Get-AzContext
    $ApiUrl = "https://management.azure.com/subscriptions/$($azcontext.Subscription.Id)/resourceGroups/$($ResourceGroup)/providers/Microsoft.OperationalInsights/workspaces/$($Workspace)/providers/Microsoft.SecurityInsights/dataConnectors?api-version=2020-01-01"
    
    try {
        $authHeader = @{
            'Content-Type'='application/json'
            'Authorization'='Bearer ' + (Get-AzAccessToken).Token
        }
        $httpResponse = Invoke-WebRequest -Uri $ApiUrl -Method GET -Headers $authHeader -Body $RequestBody -UseBasicParsing
        $Content = ($httpResponse.Content | ConvertFrom-Json) 
        $ConnectorList = $Content.value
        $TaxiiConnector = $ConnectorList | Where-Object {$_.kind -eq "ThreatIntelligenceTaxii" -and $_.Properties.taxiiServer -eq $TaxiiServer -and $_.Properties.collectionId -eq $CollectionId}
        return $TaxiiConnector
    }
    catch {
        $errorReturn = $_
        $errorResult = ($errorReturn | ConvertFrom-Json ).error
        Write-Verbose $_
        Write-Error "Unable to invoke webrequest with error message: $($errorResult.message)" -ErrorAction Stop
    }
}

function Invoke-TaxiiConnectionAction {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [ConnectorAction] 
        $Action,
        [Parameter(Mandatory = $true)]
        [Hashtable] 
        $Parameters
    )

    $TaxiiClient = $Parameters.TaxiiClient 
        if([string]::IsNullOrEmpty($TaxiiClient)){
            $TaxiiClient = "Enabled"
        }

        $WorkspaceResource = Get-AzOperationalInsightsWorkspace -ResourceGroupName $ResourceGroup -Name $Workspace -ErrorAction Stop
        
        $Credential = Get-ConnectorsCredentials -KeyVault $Parameters.KeyVault -SecretName $Parameters.SecretName
        if($null -ne $Credential) {
            switch ($Action) {
                "Enable" {  
                    $Connector = Get-AzTaxiiSentinelConnector -ResourceGroup $ResourceGroup `
                                                                -Workspace $Workspace `
                                                                -TaxiiServer $Parameters.TaxiiServer`
                                                                -CollectionId $Parameters.CollectionId 
                    if($null -eq $Connector) {
                        New-AzSentinelTaxiiConnector -ResourceGroup $ResourceGroup `
                                                        -Workspace $Workspace `
                                                        -TaxiiClient $TaxiiClient `
                                                        -TaxiiServer $Parameters.TaxiiServer`
                                                        -CollectionId $Parameters.CollectionId `
                                                        -WorkspaceId $WorkspaceResource.CustomerId `
                                                        -FriendlyName $Parameters.FriendlyName `
                                                        -UserName $Credential.UserName `
                                                        -Password $Credential.GetNetworkCredential().Password `
                                                        -PoolingFrequency $Parameters.PoolingFrequency
                    }
                    else {
                        Write-Warning "Connector is already activated"
                    }
                }
                "Update" {  
                    $Connector = Get-AzTaxiiSentinelConnector -ResourceGroup $ResourceGroup `
                                                                -Workspace $Workspace `
                                                                -TaxiiServer $Parameters.TaxiiServer`
                                                                -CollectionId $Parameters.CollectionId 
                    if($null -ne $Connector) {
                        Remove-AzSentinelDataConnector -DataConnectorId $Connector.Name -ResourceGroupName $ResourceGroup -WorkspaceName $Workspace
                        New-AzSentinelTaxiiConnector -ResourceGroup $ResourceGroup `
                                                    -Workspace $Workspace `
                                                    -TaxiiClient $TaxiiClient `
                                                    -TaxiiServer $Parameters.TaxiiServer`
                                                    -CollectionId $Parameters.CollectionId `
                                                    -WorkspaceId $Parameters.WorkspaceId `
                                                    -FriendlyName $Parameters.FriendlyName `
                                                    -UserName $Credential.UserName `
                                                    -Password $Credential.GetNetworkCredential().Password `
                                                    -PoolingFrequency $Parameters.PoolingFrequency
                    }
                    else {
                        throw "Connector cannot be found"
                    }
                }
                "Disable" {
                    $Connector = Get-AzTaxiiSentinelConnector -ResourceGroup $ResourceGroup `
                                                                -Workspace $Workspace `
                                                                -TaxiiServer $Parameters.TaxiiServer`
                                                                -CollectionId $Parameters.CollectionId 
                    if($null -ne $Connector){
                        Remove-AzSentinelDataConnector -DataConnectorId $Connector.Name -ResourceGroupName $ResourceGroup -WorkspaceName $Workspace
                    }
                    else {
                        throw "Connector cannot be found"
                    }
                }
                "Check" {
                    $Connector = Get-AzTaxiiSentinelConnector -ResourceGroup $ResourceGroup `
                                                                -Workspace $Workspace `
                                                                -TaxiiServer $Parameters.TaxiiServer`
                                                                -CollectionId $Parameters.CollectionId 
                    Write-Output $Connector
                }
                Default {
                    throw "Unexepected Action Requested"
                }
            }
        }
        else {
            throw "Credentials for Taxii Server are not avaiable"
        }
}

class ThreatIntelligenceTaxiiDataConnector : DataConnector {

    ThreatIntelligenceTaxiiDataConnector () {

    }

    [void] Invoke ([string]$ResourceGroup, [string]$Workspace, [ConnectorAction] $Action, [Hashtable] $Parameters) {
        
        $Configurations = $Parameters.Configurations
        if($null -ne $Configurations){
            $LastErrors = @()
            $Configurations | ForEach-Object {
                try {
                    Invoke-TaxiiConnectionAction -Action $Action -Parameters $_    
                }
                catch{
                    $LastErrors += $_
                }
            }

            if($LastErrors.Length -gt 0) {
                $StringBuilder = [System.Text.StringBuilder]::new()
                $StringBuilder.Append("Taxii Connector raise the following errors: ")
                $LastErrors | ForEach-Object {
                    $StringBuilder.AppendLine("$($_.Exception.Message)")
                }
                throw $StringBuilder.ToString()
            }
        }
        else {
            Invoke-TaxiiConnectionAction -Action $Action -Parameters $Parameters
        }
    }
}