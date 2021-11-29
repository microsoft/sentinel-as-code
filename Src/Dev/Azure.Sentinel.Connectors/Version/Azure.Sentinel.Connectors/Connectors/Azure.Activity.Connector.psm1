$Module = Get-Module -Name Az.SecurityInsights -ListAvailable
if($null -eq $Module) {
    Install-Module -Name Az.SecurityInsights -Force
}

$ModulesLocation = Split-Path -Path $MyInvocation.MyCommand.Definition -Parent
Import-Module -Name "$($ModulesLocation)\Azure.Connectors.Common.psm1"

function Get-AzSentinelActivityConnector {
    param (
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string] $ResourceGroup,   
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string] $Workspace
        )
     
    $AzContext= Get-AzContext
    $ApiUrl = "https://management.azure.com/subscriptions/$($azcontext.Subscription.Id)/resourceGroups/$($ResourceGroup)/providers/Microsoft.OperationalInsights/workspaces/$($Workspace)/datasources?$filter=kind='AzureActivityLog'&api-version=2020-08-01"
    
    try {
        $Headers = @{
            'Content-Type'='application/json'
            'Authorization'='Bearer ' + (Get-AzAccessToken).Token
        }
        
        # AzureActivityLog is already connected, compose body with existing etag for update
        $Output = Invoke-WebRequest -Uri $ApiUrl -Method Get -Headers $Headers | ConvertFrom-Json
        Write-Host "Connector for Azure Activity is already enabled"
        return ($Output | ConvertFrom-Json -Depth 3).value
    }
    catch { 
        $errorReturn = $_
        #If return code is 404 we are assuming AzureActivityLog is not enabled yet
        if ($_.Exception.Response.StatusCode.value__ = 404) {
            return $null
        }
        #Any other eeror code is interpreted as error 
        else {
            $errorResult = ($errorReturn | ConvertFrom-Json ).error
            Write-Verbose $_.Exception.Message
            Write-Error "Unable to invoke webrequest with error message: $($errorResult.message)" -ErrorAction Stop           
        }
    }
}

function Set-AzSentinelActivityConnector {
    param (
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string] $SubscriptionId, 
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string] $ResourceGroup,   
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string] $Workspace,   
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string] $ConnectorId,   
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string] $Etag
        )
     
    try {
        $ApiUrl = "https://management.azure.com/subscriptions/$($SubscriptionId)/resourceGroups/$($ResourceGroup)/providers/Microsoft.OperationalInsights/workspaces/$($Workspace)/datasources/$($ConnectorId)?api-version=2020-08-01"
        
        #Check if AzureActivityLog is already connected (there is no better way yet) [assuming there is only one AzureActivityLog from same subscription connected]
        $connectorProperties = @{
            linkedResourceId = "/subscriptions/$($SubscriptionId)/providers/microsoft.insights/eventtypes/management"
        }        
        
        $connectorBody = @{
            kind = "AzureActivityLog"
            etag = $Etag
            properties = $connectorProperties
            name = $ConnectorId
            type = "Microsoft.OperationalInsights/workspaces/datasources"
        } 
        
        $Headers = @{
            'Content-Type'='application/json'
            'Authorization'='Bearer ' + (Get-AzAccessToken).Token
        }

        Invoke-WebRequest -Uri $ApiUrl -Method Put -Headers $Headers -Body ($connectorBody | ConvertTo-Json -EnumsAsStrings)
    }
    catch {
        $errorReturn = $_
        $errorResult = ($errorReturn | ConvertFrom-Json ).error
        Write-Verbose $_.Exception.Message
        Write-Error "Unable to invoke webrequest with error message: $($errorResult.message)" -ErrorAction Stop
    }  
}


function New-AzSentinelActivityConnector {
    param (
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string] $SubscriptionId, 
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string] $ResourceGroup,   
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string] $Workspace,   
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string] $ConnectorId
        )
     
    try {
        $ApiUrl = "https://management.azure.com/subscriptions/$($SubscriptionId)/resourceGroups/$($ResourceGroup)/providers/Microsoft.OperationalInsights/workspaces/$($Workspace)/datasources/$($ConnectorId)?api-version=2020-08-01"
        
        #Check if AzureActivityLog is already connected (there is no better way yet) [assuming there is only one AzureActivityLog from same subscription connected]
        $connectorProperties = @{
            linkedResourceId = "/subscriptions/$($SubscriptionId)/providers/microsoft.insights/eventtypes/management"
        }        
        
        $connectorBody = @{
            kind = "AzureActivityLog"
            properties = $connectorProperties
            name = $ConnectorId
            type = "Microsoft.OperationalInsights/workspaces/datasources"
        } 

        $Headers = @{
            'Content-Type'='application/json'
            'Authorization'='Bearer ' + (Get-AzAccessToken).Token
        }
        
        Invoke-WebRequest -Uri $ApiUrl -Method Put -Headers $Headers -Body ($connectorBody | ConvertTo-Json -EnumsAsStrings)
    }
    catch {
        $errorReturn = $_
        $errorResult = ($errorReturn | ConvertFrom-Json ).error
        Write-Verbose $_.Exception.Message
        Write-Error "Unable to invoke webrequest with error message: $($errorResult.message)" -ErrorAction Stop
    }  
}

function Remove-AzSentinelActivityConnector {
    param (
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string] $SubscriptionId, 
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string] $ResourceGroup,   
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string] $Workspace,   
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string] $ConnectorId
        )
     
    try {

        $Headers = @{
            'Content-Type'='application/json'
            'Authorization'='Bearer ' + (Get-AzAccessToken).Token
        }

        $ApiUrl = "https://management.azure.com/subscriptions/$($SubscriptionId)/resourceGroups/$($ResourceGroup)/providers/Microsoft.OperationalInsights/workspaces/$($Workspace)/datasources/$($ConnectorId)?api-version=2020-08-01"
        
        $Response = Invoke-WebRequest -Uri $ApiUrl -Method Delete -Headers $Headers
        if(($Response.StatusCode -ne 200) -or ($Response.StatusCode -ne 204)) {
            throw "Error deleting Activity Log Connector"
        }
    }
    catch {
        $errorReturn = $_
        $errorResult = ($errorReturn | ConvertFrom-Json ).error
        Write-Verbose $_.Exception.Message
        Write-Error "Unable to invoke webrequest with error message: $($errorResult.message)" -ErrorAction Stop
    }  
}

class AzureActivityDataConnector : DataConnector {

    AzureActivityDataConnector () {

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
                        New-AzSentinelActivityConnector -ResourceGroup $ResourceGroup `
                                                        -Workspace $Workspace `
                                                        -SubscriptionId $SubscriptionId `
                                                        -ConnectorId $SubscriptionId
                    }
                    "Update" {  
                        $Connector = Get-AzSentinelActivityConnector -ResourceGroup $ResourceGroup -Workspace $Workspace  | Where-Object {$_.properties.linkedResourceId -eq "/subscriptions/$($SubscriptionId)/providers/microsoft.insights/eventtypes/management"}
                        if($null -ne $Connector){
                            Set-AzSentinelActivityConnector -ResourceGroup $ResourceGroup `
                                                        -Workspace $Workspace `
                                                        -SubscriptionId $SubscriptionId `
                                                        -ConnectorId $connector.name `
                                                        -Etag $connector.etag
                        }
                        else {
                            throw "Connector cannot be found"
                        }
                    }
                    "Disable" {
                        $Connector = Get-AzSentinelActivityConnector -ResourceGroup $ResourceGroup -Workspace $Workspace  | Where-Object {$_.properties.linkedResourceId -eq "/subscriptions/$($SubscriptionId)/providers/microsoft.insights/eventtypes/management"}
                        if($null -ne $Connector){
                            Remove-AzSentinelActivityConnector -ResourceGroup $ResourceGroup `
                                                                -Workspace $Workspace `
                                                                -SubscriptionId $SubscriptionId `
                                                                -ConnectorId $connector.name 
                        }
                        else {
                            throw "Connector cannot be found"
                        }
                    }
                    "Check" {
                        $Connector = Get-AzSentinelActivityConnector -ResourceGroup $ResourceGroup -Workspace $Workspace  | Where-Object {$_.properties.linkedResourceId -eq "/subscriptions/$($SubscriptionId)/providers/microsoft.insights/eventtypes/management"}
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