[CmdletBinding()]
param (
    [Parameter(Mandatory = $false)]
    [string]
    $ResourceGroupName,
    [Parameter(Mandatory = $false)]
    [string]
    $WorkspaceName,
    [Parameter(Mandatory = $false)]
    [string]
    $AutomationDefinitionVariable,
    [Parameter(Mandatory = $false)]
    [string]
    $AutomationSnapshotVariable,
    [Parameter(Mandatory = $false)]
    [string]
    $SubscriptionId,
    [Parameter(Mandatory = $false)]
    [string]
    $AutomationSnapshotConnectedVariable
)

function Get-AzureTablesFromDefinition {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [PsCustomObject]
        $EnvironmentTablesDefinition
    )

    $Tables = $EnvironmentTablesDefinition | Select-Object -ExpandProperty Container | Select-Object -ExpandProperty Tables
    return $Tables
}

function Get-AzureSentinelTables {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [string]
        $ResourceGroupName,
        [Parameter(Mandatory = $true)]
        [string]
        $WorkspaceName
    )
      
    $SubscriptionId = (Get-AzContext).Subscription.Id
    $QueryUrl = "/subscriptions/$($SubscriptionId)/resourceGroups/$($ResourceGroupName)/providers/Microsoft.OperationalInsights/workspaces/$($WorkspaceName)/tables?api-version=2020-08-01"
    $Response = Invoke-AzRestMethod -Path $QueryUrl -Method GET
    if($Response.StatusCode -eq 200) {
        $Collection = ($Response.Content | ConvertFrom-Json).value
        return $Collection | Select-Object -ExpandProperty name 
    }
    else {
        throw $Response.Content
    }
}

function ConvertTo-Hashtable
{
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true, ValueFromPipeline = $true)]
        [PsCustomObject] 
        $InputObject
    )

    $hashtable = @{}
    
    $InputObject.PSObject.Properties | ForEach-Object {
        $hashtable[$_.Name] = $_.Value
    }
    return $hashtable
}

function ConvertArrayTo-Hashtable {
    param (
        [Parameter(Mandatory = $true)]
        [array]
        $Tables
    )

    $TableRegistry = @{}
    $Tables | ForEach-Object {
        if(-not $TableRegistry.ContainsKey($_)) {
            $TableRegistry.Add($_, $true)
        }
    } 
    return $TableRegistry 
}

function Get-AzureManagedIdentityAccessToken {
    $resource= "?resource=https://management.azure.com/" 
    $url = $env:IDENTITY_ENDPOINT + $resource 
    $Headers = New-Object "System.Collections.Generic.Dictionary[[String],[String]]" 
    $Headers.Add("X-IDENTITY-HEADER", $env:IDENTITY_HEADER) 
    $Headers.Add("Metadata", "True") 
    $accessToken = Invoke-RestMethod -Uri $url -Method 'GET' -Headers $Headers
    return $accessToken
}

function Compare-AzSentinelTables {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $false)]
        [Hashtable]
        $RecordTables,
        [Parameter(Mandatory = $false)]
        [array]
        $Tables
    )

    if(($null -ne $RecordTables) -and ($null -ne $Tables)) {
        $Differences1 = $Tables | Where-Object { -not $RecordTables.ContainsKey($_) }
        $NewRecordTable = ConvertArrayTo-Hashtable -Tables $Tables
        $Keys = $RecordTables.Keys
        $Differences2 = $Keys | Where-Object { -not $NewRecordTable.ContainsKey($_) }
        return -not(($Differences1 -gt 0) -or ($Differences2 -gt 0))
    }
    else {
        return $false
    }
}

function New-AzSentinelDataExportRuleContainer {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [PsCustomObject]
        $EnvironmentTablesDefinition
    )
    
    Write-Output $EnvironmentTablesDefinition
    if($null -ne $EnvironmentTablesDefinition) {
        $EnvironmentTablesDefinition | ForEach-Object {
            $EnvironmentTableEntry = $_
            try {
                $Container = $EnvironmentTableEntry.Container
                if($null -ne $Container) {
                    $Container.Tables | ForEach-Object {
                        $TableName = "am-$($_.ToLowerInvariant())"
                        Write-Output "Processing Table $($TableName)"
                        if($Container.Kind -eq "EventHub") {
                            $EventHub = Get-AzResource -Name $Container.Name -ResourceGroupName $Container.ResourceGroupName -ResourceType "Microsoft.EventHub/namespaces" -ErrorAction SilentlyContinue
                            if($null -ne $EventHub) {
                               $Capture = $Container.Capture
                                if($null -ne $Capture) {
                                    $StorageAccountName = $Capture.StorageAccountResourceId
                                }
                                New-AzureEventHubWithCapture -ResourceGroupName $Container.ResourceGroupName -EventHubNamespace $Container.Name -EventHubName $TableName -StorageAccountName $StorageAccountName
                            }
                            else {
                                Write-Warning "Event Hub $($Container.Name) in Resource Group $($Container.ResourceGroupName) not exists"
                            }
                        }
                    }

                    $DataExportRuleUrl = "/subscriptions/$($SubscriptionId)/resourcegroups/$($ResourceGroupName)/providers/Microsoft.OperationalInsights/workspaces/$($WorkspaceName)/dataExports/$($DataExportRuleName)?api-version=2020-08-01"
                    $Body = [PSCustomObject]@{
                        properties = [PSCustomObject]@{
                            destination = [PSCustomObject]@{
                                resourceId = $AzEventHubNamespace.ResourceId
                            }
                            tableNames = $ExistingTables
                        }            
                    }
                    $RequestBody = $Body | ConvertTo-Json -Depth 3
                    $Response = Invoke-AzRestMethod -Method PUT -Path $DataExportRuleUrl -Payload $RequestBody
                    if($Response.StatusCode -ne 200) {
                        throw $Response.Content
                    }
                }
            }
            catch {
                Write-Error $_
            }        
        }
    }
    else {
        throw "Environment Definition is null"
    }
}

function Clean-AzureEventHubNotUsed {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [string]
        $ResourceGroupName,
        [Parameter(Mandatory = $true)]
        [string]
        $EventHubNamespace,
        [Parameter(Mandatory = $true)]
        [string[]]
        $Tables
    )

    $AzEventHubs = Get-AzEventHub -ResourceGroupName $ResourceGroupName -Namespace $EventHubNamespace
    if($null -ne $AzEventHubs){
        $AzEventHubsToRemove = $AzEventHubs | Where-Object {-not $Tables.Contains($_.Name)}
        $AzEventHubsToRemove | ForEach-Object {
            $_ | Remove-AzEventHub
        }
    }
}

function New-AzureEventHubWithCapture {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [string]
        $ResourceGroupName,
        [Parameter(Mandatory = $true)]
        [string]
        $EventHubNamespace,
        [Parameter(Mandatory = $true)]
        [string]
        $EventHubName,
        [Parameter(Mandatory = $false)]
        [string]
        $StorageAccountResourceId,
        [Parameter(Mandatory = $false)]
        [int]
        $MessageRetentionInDays = 3,
        [Parameter(Mandatory = $false)]
        [int]
        $PartitionCount = 2,
        [Parameter(Mandatory = $false)]
        [string]
        $ArchiveFormat = "{Namespace}/{EventHub}/{PartitionId}/{Year}/{Month}/{Day}/{Hour}/{Minute}/{Second}"        
    )
    
    Write-Output "Azure Sentinel Integration: Checking Event Hub Instance with Name: $($EventHubName)"
    $AzEventHubTopic = Get-AzEventHub -ResourceGroupName $ResourceGroupName -Namespace $EventHubNamespace -Name $EventHubName -ErrorAction SilentlyContinue
    if($null -eq $AzEventHubTopic) {
        Write-Output "Azure Sentinel Integration: Creating Event Hub Instance $($EventHubName)"
        New-AzEventHub -ResourceGroupName $ResourceGroupName -NamespaceName $EventHubNamespace -Name $EventHubName -MessageRetentionInDays $MessageRetentionInDays -PartitionCount $PartitionCount
        Write-Output "Azure Sentinel Integration: Event Hub Instance $($EventHubName) created"
    }
    else {
        Write-Output "Azure Sentinel Integration: Event Hub Instance $($EventHubName) already exists"
    }
    
    Write-Output "Azure Sentinel Integration: Storage Account: $($StorageAccountResourceId)"
    if($null -ne $StorageAccountResourceId) {
        $ContainerName = $EventHubName.Replace("am", "capture").ToLowerInvariant()
        Write-Output "Azure Sentinel Integration: Event Hub Instance $($EventHubName). Configuring Container $($EventHubName.ToLowerInvariant())  on $($StorageAccountResourceId)"
        $AzStorageAccount = Get-AzResource -ResourceId $StorageAccountResourceId
        New-AzureStorageAccountContainer -StorageAccountName $AzStorageAccount.Name -Name $ContainerName
        Write-Output "Azure Sentinel Integration: Event Hub Instance $($EventHubName) on Namespace $($EventHubNamespace) in Resoruce Group $($ResourceGroupName). Configuring Event Capture on $($StorageAccountResourceId)"
        $EventHub = Get-AzEventHub -ResourceGroupName $ResourceGroupName -Namespace $EventHubNamespace -Name $EventHubName
        $EventHub.CaptureDescription = New-Object -TypeName Microsoft.Azure.Commands.EventHub.Models.PSCaptureDescriptionAttributes
        $EventHub.CaptureDescription.Enabled = $true
        $EventHub.CaptureDescription.IntervalInSeconds = 120
        $EventHub.CaptureDescription.Encoding = "Avro"
        $EventHub.CaptureDescription.SizeLimitInBytes = 10485763
        $EventHub.CaptureDescription.Destination.Name = "EventHubArchive.AzureBlockBlob"
        $EventHub.CaptureDescription.Destination.BlobContainer = $ContainerName
        $EventHub.CaptureDescription.Destination.ArchiveNameFormat = $ArchiveFormat
        $EventHub.CaptureDescription.Destination.StorageAccountResourceId = $StorageAccountResourceId
        Write-Output "Azure Sentinel Integration: Event Hub Instance $($EventHubName). Processing Event Capture on $($StorageAccountResourceId)"
        Set-AzEventHub -ResourceGroupName $ResourceGroupName -Namespace $EventHubNamespace -Name $EventHubName -InputObject $EventHub
        Write-Output "Azure Sentinel Integration: Event Hub Instance $($EventHubName). Event Capture on $($StorageAccountResourceId) configured"
    }
}

function New-AzureStorageAccountContainer {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [string]
        $StorageAccountName,
        [Parameter(Mandatory = $true)]
        [string]
        $Name
    )

    $AzStorageContext = New-AzStorageContext -StorageAccountName $StorageAccountName -UseConnectedAccount
    $Container = Get-AzStorageContainer -Name $Name -Context $AzStorageContext -ErrorAction SilentlyContinue
    if($null -eq $Container) {
        New-AzStorageContainer -Context $AzStorageContext -Name $Name.ToLowerInvariant() -Permission Off
    }
}

function Get-AutomationVariableObject{
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [string]
        $VariableName,
        [Parameter(Mandatory = $false)]
        [switch]
        $AsHashtable
    )

    $Value = Get-AutomationVariable -Name $VariableName
    if($AsHashtable) {
        return ConvertFrom-Json -InputObject $Value | ConvertTo-Hashtable
    }
    else {
        return ConvertFrom-Json -InputObject $Value
    }
}

function Set-AutomationVariableObject{
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [string]
        $VariableName,
        [Parameter(Mandatory = $true)]
        [string]
        $Value
    )

    Set-AutomationVariable -Name $VariableName -Value $Value
}

Write-Output "Azure Sentinel Integration: Creating Session On Azure Subscription"
Connect-AzAccount -Identity -Subscription "30ecb500-972c-46a3-9d0f-e2d2c384c47e"
Write-Output "Azure Sentinel Integration: Retrieving Azure Subscription Identifier"
$SubscriptionId = (Get-AzContext).Subscription.Id
Write-Output "Azure Sentinel Integration: Subcription: $($SubscriptionId)"
$EnvironmentTablesDefinition = Get-AutomationVariableObject -VariableName $AutomationDefinitionVariable
if($null -ne $EnvironmentTablesDefinition) {
    Write-Output "Azure Sentinel Integration: Gathering Information from Azure Sentinel Tables"
    $AzTables = Get-AzureSentinelTables -ResourceGroupName $ResourceGroupName -WorkspaceName $WorkspaceName
    $AzTablesToConnect = Get-AzureTablesFromDefinition -EnvironmentTablesDefinition $EnvironmentTablesDefinition
    Write-Output "Azure Sentinel Integration: Gathering Information from Azure Sentinel Tables Snapshot"
    $AzSnapshotTables = Get-AutomationVariableObject -VariableName $AutomationSnapshotVariable -AsHashtable -ErrorAction SilentlyContinue
    $AzSnapshotConnectedTables = Get-AutomationVariableObject -VariableName $AutomationSnapshotConnectedVariable -AsHashtable -ErrorAction SilentlyContinue
    Write-Output "Azure Sentinel Integration: Validating Changes"
    $ChangesVsDefinition = Compare-AzSentinelTables -RecordTables $AzSnapshotTables -Tables $AzTables
    $ChangesVsConnected = Compare-AzSentinelTables -RecordTables $AzSnapshotConnectedTables -Tables $AzTablesToConnect
    if($ChangesVsDefinition -eq $false -or $ChangesVsConnected -eq $false) {
        Write-Output "Azure Sentinel Integration: Changes Detected. Processing..."
        $AzSnapshotTables = ConvertArrayTo-Hashtable -Tables $AzTables
        $TotalNumberOfDefinitions = $EnvironmentTablesDefinition.Length
        Write-Output "Azure Sentinel Integration: Definitions requested: $($TotalNumberOfDefinitions)"
        if($TotalNumberOfDefinitions -gt 10) {
            Write-Warning "Azure Sentinel Integration: Only the first 10 definitions will be processed"
        }
        $ConnectedTables = [System.Collections.ArrayList]@()
        0..9 | ForEach-Object {
            Write-Output "Azure Sentinel Integration: Processing Order in Position $($_)"
            if($_ -lt $TotalNumberOfDefinitions) {
                $EnvironmentTableEntry = $EnvironmentTablesDefinition[$_]
                $Container = $EnvironmentTableEntry.Container
                Write-Output "Azure Sentinel Integration: Container $($Container.Name)"
            }
            else {
                $EnvironmentTableEntry = $null
                $Container = $null
            }
            try {
                if($null -ne $Container) {
                    Write-Output "Azure Sentinel Integration: Processing Container"
                    $Tables = $Container.Tables | Where-Object { $AzSnapshotTables.ContainsKey($_) }
                    $ContainerTables = @()
                    switch($Container.Kind) {
                        "EventHub" {
                                        Write-Output "Azure Sentinel Integration: Container Kind [Event Hub] = $($Container.Name)"
                                        Clean-AzureEventHubNotUsed -ResourceGroupName $Container.ResourceGroupName -EventHubNamespace $Container.Name -Tables $Tables
                                        $Tables | ForEach-Object {
                                            Write-Output "Azure Sentinel Integration: Working over Table $($_)"
                                            $TableName = "am-$($_.ToLowerInvariant())"
                                            $ContainerTables += $_
                                            Write-Output "Azure Sentinel Integration: Taking Table $($_)"
                                            Write-Output "Azure Sentinel Integration: Check Event Hub Namespace $($Container.Name) in Resource Group $($Container.ResourceGroupName)"
                                            $EventHub = Get-AzResource -Name $Container.Name -ResourceGroupName $Container.ResourceGroupName -ResourceType "Microsoft.EventHub/namespaces" -ErrorAction SilentlyContinue
                                            if($null -ne $EventHub) {
                                                Write-Output "Azure Sentinel Integration: Event Hub Namespace $($Container.Name) in Resource Group $($Container.ResourceGroupName) exists"
                                                $Capture = $Container.Capture
                                                if($null -ne $Capture) {
                                                    $StorageAccountResourceId = $Capture.StorageAccountResourceId
                                                }
                                                New-AzureEventHubWithCapture -ResourceGroupName $Container.ResourceGroupName -EventHubNamespace $Container.Name -EventHubName $TableName -StorageAccountResourceId $StorageAccountResourceId
                                                $ResourceId = $EventHub.ResourceId
                                            }
                                            else {
                                                Write-Warning "Event Hub $($Container.Name) in Resource Group $($Container.ResourceGroupName) not exists"
                                            }
                                        }
                                    }
                        "StorageAccount" {
                                    Write-Output "Azure Sentinel Integration: Container Kind [Storage Account] = $($Container.Name)"
                                    $Tables | ForEach-Object {
                                        Write-Output "Azure Sentinel Integration: Working over Table $($_)"
                                        $TableName = "am-$($_.ToLowerInvariant())"
                                        $ContainerTables += $_
                                        Write-Output "Azure Sentinel Integration: Taking Table $($_)"
                                        Write-Output "Azure Sentinel Integration: Check Storage Account $($Container.Name) in Resource Group $($Container.ResourceGroupName)"
                                        $AzStorageAccount = Get-AzResource -Name $Container.Name -ResourceGroupName $Container.ResourceGroupName -ResourceType "Microsoft.Storage/storageAccounts" -ErrorAction SilentlyContinue
                                        if($null -ne $AzStorageAccount) {
                                            Write-Output "Azure Sentinel Integration: Storage Account $($Container.Name) in Resource Group $($Container.ResourceGroupName) exists"
                                            New-AzureStorageAccountContainer -StorageAccountName $Container.Name -Name $TableName
                                            $ResourceId = $AzStorageAccount.ResourceId
                                        }
                                        else {
                                            Write-Warning "Event Hub $($Container.Name) in Resource Group $($Container.ResourceGroupName) not exists"
                                        }
                                    }                        
                                }
                    }

                    if($ContainerTables.Length -gt 0) {
                        $DataExportRuleName = "rule-$($WorkspaceName)-$($_)"
                        Write-Output "Azure Sentinel Integration: Creating Rule with Id $($DataExportRuleName)"
                        $DataExportRuleUrl = "/subscriptions/$($SubscriptionId)/resourcegroups/$($ResourceGroupName)/providers/Microsoft.OperationalInsights/workspaces/$($WorkspaceName)/dataExports/$($DataExportRuleName)?api-version=2020-08-01"
                        $Response = Invoke-AzRestMethod -Method GET -Path $DataExportRuleUrl
                        if($Response.StatusCode -eq 200) {
                            Write-Output "Azure Sentinel Integration: Rule with Id $($DataExportRuleName) is ready to be Removed"
                            $Response = Invoke-AzRestMethod -Method DELETE -Path $DataExportRuleUrl
                            if($Response.StatusCode -ne 200) {
                                throw $Response.Content
                            }
                        }
                        $Body = [PSCustomObject]@{
                            properties = [PSCustomObject]@{
                                destination = [PSCustomObject]@{
                                    resourceId = $ResourceId
                                }
                                tableNames = $ContainerTables
                            }            
                        }
                        $RequestBody = $Body | ConvertTo-Json -Depth 4
                        Write-Output "Azure Sentinel Integration: Rule with Id $($DataExportRuleName) is ready to be Created"
                        $Response = Invoke-AzRestMethod -Method PUT -Path $DataExportRuleUrl -Payload $RequestBody
                        if($Response.StatusCode -ne 200) {
                            throw $Response.Content
                        }
                        else {
                            $TablesConnected = $ContainerTables -join ","
                            Write-Output "Azure Sentinel Integration: Rule with Id $($DataExportRuleName) created for Tables `"$($TablesConnected)`""
                        }
                        $ConnectedTables.AddRange($ContainerTables) | Out-Null    
                    }              
                }
                else {
                    $DataExportRuleName = "rule-$($WorkspaceName)-$($_)"
                    Write-Output "Azure Sentinel Integration: Checking Rule with Id $($DataExportRuleName)"
                    $DataExportRuleUrl = "/subscriptions/$($SubscriptionId)/resourcegroups/$($ResourceGroupName)/providers/Microsoft.OperationalInsights/workspaces/$($WorkspaceName)/dataExports/$($DataExportRuleName)?api-version=2020-08-01"
                    $Response = Invoke-AzRestMethod -Method GET -Path $DataExportRuleUrl
                    if($Response.StatusCode -eq 200) {
                        Write-Output "Azure Sentinel Integration: Rule with Id $($DataExportRuleName) is ready to be Removed"
                        $Response = Invoke-AzRestMethod -Method DELETE -Path $DataExportRuleUrl
                        if($Response.StatusCode -ne 200) {
                            throw $Response.Content
                        }
                        else {
                            Write-Output "Azure Sentinel Integration: Rule with Id $($DataExportRuleName) is Removed"
                        }
                    }
                }
            }
            catch {
                Write-Error $_.Exception.ToString()
            }            
        }
        $TablesConnected = $ConnectedTables -join ","
        Write-Output "Azure Sentinel Integration: Connected Tables `"$($TablesConnected)`""
        $ConnectedHashTables = ConvertArrayTo-Hashtable -Tables $ConnectedTables
        $ConnectedTablesJson = ConvertTo-Json -InputObject $ConnectedHashTables -Depth 2
        $AzSnapshotTablesJson = ConvertTo-Json -InputObject $AzSnapshotTables -Depth 5
        Set-AutomationVariableObject -VariableName $AutomationSnapshotVariable -Value $AzSnapshotTablesJson
        Set-AutomationVariableObject -VariableName $AutomationSnapshotConnectedVariable -Value $ConnectedTablesJson
    }  
    else {
        Write-Output "Azure Sentinel Integration: Changes not detected"
    }      
}
else {
    Write-Warning "Azure Sentinel Integration: Environment Definition is not available on Variable $($AutomationDefinitionVariable)"
}
        
    
