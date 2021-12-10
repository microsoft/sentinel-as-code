$AzResourcesModule = Get-Module -Name Az.Resources -ListAvailable
if($null -eq $AzResourcesModule){
    Install-Module -Name Az.Resources -Force -AllowClobber
}
Import-Module -Name Az.Resources -Force

#
# Get-Environment provides the Environment definition from the specified File Path
# 
# Schema for an Environment:
#

function Get-Environment {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [string]
        $Path
    )

    $Environment = Get-Content -Path $Path -Raw | ConvertFrom-Json
    $Environment | Add-Member -MemberType NoteProperty -Name "Source" -Value $Path
    return $Environment
}

function Resolve-EnvironmentDefinition {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [string]
        $Path,
        [Parameter(Mandatory = $false)]
        [string]
        $EnvironmentName
    )
    $SubscriptionId = (Get-AzContext).Subscription.Id
    $EnvironmentDefinition = Get-EnvironmentDefinition -Path $Path -SubscriptionId $SubscriptionId -EnvironmentName $EnvironmentName
    if($null -ne $EnvironmentDefinition) {
        $MergedEnvironmentDefinition = Merge-Environment -EnvironmentDefinition $EnvironmentDefinition
        return $MergedEnvironmentDefinition
    }
    else {
        throw "Environment $($EnvironmentName) in Path $($Path) cannot be resolved"
    }

}

function Get-EnvironmentDefinition {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [string]
        $SubscriptionId,
        [Parameter(Mandatory = $true)]
        [string]
        $Path,
        [Parameter(Mandatory = $false)]
        [string]
        $EnvironmentName
    )

    if(Test-Path -Path $Path) {
        $Items = Get-ChildItem -Path $Path -Filter "Environment.json" -Recurse
        if($null -ne $Items) {
            $EnvironmentDefinitions = $Items | ForEach-Object {
                try {
                     Get-Environment -Path $_.FullName
                }
                catch {
                    Write-Error $_
                }
            }
            if([string]::IsNullOrEmpty($EnvironmentName)) {
                $EnvironmentResolution = $EnvironmentDefinitions | Where-Object { $_.SubscriptionId -eq $SubscriptionId }
                if($EnvironmentResolution -is [Array]){
                    throw "Multiple Environments can be resolved, but only expected one"
                }
                else {
                    return $EnvironmentResolution
                }
            }
            else {
                $EnvironmentResolution = $EnvironmentDefinitions | Where-Object { $_.SubscriptionId -eq $SubscriptionId -and $_.Name -eq $EnvironmentName}
                if($EnvironmentResolution -is [Array]){
                    throw "Multiple Environments can be resolved, but only expected one"
                }
                else {
                    return $EnvironmentResolution
                }
            }            
        }
        else {
            throw "Environment file not found in Path $($FullName)"            
        }
    }
    else {
        throw "Path $($FullName) not found"
    }
}

# 
# Retrieve the Azure Resources available on the Resource Group where Sentinel is deployed
#
function Export-ContextSettings {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [string]
        $ResourceGroupName,
        [Parameter(Mandatory = $true)]
        [string]
        $Path
    )

    $Settings = @{}
    $ResourceGroupElement = Get-AzResourceGroup -Name $ResourceGroupName
    if($null -ne $ResourceGroupElement) {
        $ResourceGroup = [PSCustomObject]@{
            Name = $ResourceGroupElement.ResourceGroupName
            Id = $ResourceGroupElement.ResourceId
        }
        $Settings.Add("ResourceGroup", $ResourceGroup)

        $Tags = $ResourceGroupElement.Tags
        if($null -ne $Tags) {
            $Tags.GetEnumerator() | ForEach-Object {
                $Settings.Add("Tag.$($_.Key)", $_.Value)
            }
        }
    }

    $Connections = Get-AzResource -ResourceGroupName $ResourceGroupName -ResourceType Microsoft.Web/connections -ExpandProperties
    $Connections | ForEach-Object {
        $Name = $_.Name
        $Properties = $_.Properties
        if($null -ne $Properties) {
            $Api = $Properties.api
            if($null -ne $Api) {
                $ConnectionName = $Api.Name
                if(-not [string]::IsNullOrEmpty($ConnectionName)) {
                    if(-not $Settings.ContainsKey($ConnectionName)) {
                        $Connection = [PSCustomObject]@{
                            Name = $Name
                            Id = $_.ResourceId
                        }
                        $Settings.Add($ConnectionName, $Connection)
                    }
                    else {
                        Write-Warning "A connection for $($Name) has been resolved. Duplicate Connection detected"
                    }
                }
                else {
                    Write-Warning "API Naming cannot be resolved"
                }
            }
            else {
                Write-Warning "API cannot be resolved"
            }
        }
        else {
            Write-Warning "Connection Resource $($Name) has not configuration Settings"
        }   
    }

    $ManagedIdentityResource = Get-AzResource -ResourceGroupName $ResourceGroupName -ResourceType Microsoft.ManagedIdentity/userAssignedIdentities | Select-Object -First 1
    $ManagedIdentity = [PSCustomObject]@{
        Name = $ManagedIdentityResource.Name
        Id = $ManagedIdentityResource.ResourceId
    }
    $Settings.Add("ManagedIdentity", $ManagedIdentity)

    $LogAnalyticsResource = Get-AzResource -ResourceGroupName $ResourceGroupName -ResourceType Microsoft.OperationalInsights/workspaces | Select-Object -First 1
    $LogAnalytics = [PSCustomObject]@{
        Name = $LogAnalyticsResource.Name
        Id = $LogAnalyticsResource.ResourceId
    }
    $Settings.Add("Sentinel", $LogAnalytics)

    $AutomationResource = Get-AzResource -ResourceGroupName $ResourceGroupName -ResourceType Microsoft.Automation/automationAccounts | Select-Object -First 1
    $Automation = [PSCustomObject]@{
        Name = $AutomationResource.Name
        Id = $AutomationResource.ResourceId
    }
    $Settings.Add("Automation", $Automation)

    $LocationResource = Get-AzResourceGroup -Name $ResourceGroupName | Select-Object -ExpandProperty Location
    $Location = [PSCustomObject]@{
        Name = $LocationResource
        Id = Get-AzLocationSuffix -Location $LocationResource
    }
    $Settings.Add("Location", $Location)

    $SubscriptionResource = (Get-AzContext).Subscription
    if($null -ne $SubscriptionResource) {
        $Subscription = [PSCustomObject]@{
            Name = $SubscriptionResource.Name
            Id = $SubscriptionResource.Id
        }
        $Settings.Add("Subscription", $Subscription)
    }

    $TenantResource = (Get-AzContext).Tenant
    if($null -ne $TenantResource) {
        $Tenant = [PSCustomObject]@{
            Name = [string]::Empty
            Id = $TenantResource.Id
        }
        $Settings.Add("Tenant", $Tenant)
    }
    Write-Output $Settings
    $Settings | ConvertTo-Json | Out-File $Path
}

#
# Resolves the Azure Location values as a doble-characted prefix
#
function Get-AzLocationSuffix {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [string]
        $Location
    )

    $AzureLocation = Get-AzLocation | Where-Object {$_.Location -eq $Location} | Select-Object -First 1
    if($null -ne $AzureLocation) {
        $DisplayName = $AzureLocation.DisplayName
        $LocationInitialsArray = $DisplayName.ToLowerInvariant().Split(' ') | ForEach-Object { $_[0] }
        $LocationSuffix = -join $LocationInitialsArray
        return $LocationSuffix
    }
    else {
        throw "Unknown Location $($Location)"
    }
}

#
# Resolve a Resource Name based on the template and the additional information
#
function New-NamingConvention{
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [string]
        $NamingTemplate,
        [Parameter(Mandatory = $true)]
        [string]
        $Prefix,
        [Parameter(Mandatory = $true)]
        [string]
        $Suffix,
        [Parameter(Mandatory = $true)]
        [string]
        $EnvironmentName,
        [Parameter(Mandatory = $false)]
        [switch]
        $SkipDashes
    )

    $Builder = [System.Text.StringBuilder]::new($NamingTemplate.ToLowerInvariant())
    [void]$Builder.Replace("{prefix}", $Prefix.ToLowerInvariant())
    [void]$Builder.Replace("{suffix}", $Suffix.ToLowerInvariant())
    [void]$Builder.Replace("{environmentname}", $EnvironmentName.ToLowerInvariant())
    if($SkipDashes) {
        [void]$Builder.Replace("-", [string]::Empty)
    }
    return $Builder.ToString()
}

function Merge-Environment {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [PsCustomObject]
        $EnvironmentDefinition
    )

    $Definition = [PSCustomObject]@{
        Source = $EnvironmentDefinition.Source
        Location = $EnvironmentDefinition.Location
    }

    $Prefix = Get-AzLocationSuffix -Location $EnvironmentDefinition.Location
    $NamingTemplate = $EnvironmentDefinition.NamingConvention
    $EnvironmentName = $EnvironmentDefinition.Name

    $ResourceGroupDefinition = $EnvironmentDefinition.ResourceGroup
    if($null -ne $ResourceGroupDefinition) {
        switch ($ResourceGroupDefinition.Type) {
            "Literal" { 
                $ResourceGroupName = $ResourceGroupDefinition.ResourceGroupName
                $Definition | Add-Member -MemberType NoteProperty -Name "ResourceGroupName" -Value $ResourceGroupName
            }
            "Automatic" {
                $ResourceGroupName = New-NamingConvention -Prefix $Prefix -EnvironmentName $EnvironmentName -Suffix "rg" -NamingTemplate $NamingTemplate
                $Definition | Add-Member -MemberType NoteProperty -Name "ResourceGroupName" -Value $ResourceGroupName
            }
            Default {
                throw "Definition Type $_ for Resource Group is no Supported"
            }
        }
    }
    else {
        throw "Resource Group must be defined"
    }

    $Resources = $EnvironmentDefinition.Resources
    if($null -ne $Resources) {
        $SentinelDefinition = $Resources.Sentinel
        if($null -ne $SentinelDefinition) {
            switch ($SentinelDefinition.Type) {
                "Literal" {
                    $Definition | Add-Member -MemberType NoteProperty -Name "LogAnalyticsWorkspaceName" -Value $SentinelDefinition.LogAnalyticsWorkspaceName
                    $Definition | Add-Member -MemberType NoteProperty -Name "ManagedIdentityName" -Value $SentinelDefinition.ManagedIdentityName
                    $Definition | Add-Member -MemberType NoteProperty -Name "SentinelConnectionName" -Value $SentinelDefinition.SentinelConnectionName
                    $Definition | Add-Member -MemberType NoteProperty -Name "KeyVaultName" -Value $SentinelDefinition.KeyVaultName
                    $Definition | Add-Member -MemberType NoteProperty -Name "KeyVaultConnectionName" -Value $SentinelDefinition.KeyVaultConnectionName
                }
                "Automatic" {
                    $LogAnalyticsWorkspaceName = New-NamingConvention -Prefix $Prefix -EnvironmentName $EnvironmentName -Suffix "log" -NamingTemplate $NamingTemplate
                    $ManagedIdentityName = New-NamingConvention -Prefix $Prefix -EnvironmentName $EnvironmentName -Suffix "managedid" -NamingTemplate $NamingTemplate
                    $SentinelConnectionName = New-NamingConvention -Prefix $Prefix -EnvironmentName $EnvironmentName -Suffix "sentinelconnection" -NamingTemplate $NamingTemplate
                    $KeyVaultConnectionName = New-NamingConvention -Prefix $Prefix -EnvironmentName $EnvironmentName -Suffix "akvconnection" -NamingTemplate $NamingTemplate
                    $KeyVaultName = New-NamingConvention -Prefix $Prefix -EnvironmentName $EnvironmentName -Suffix "akv" -NamingTemplate $NamingTemplate
                    $Definition | Add-Member -MemberType NoteProperty -Name "LogAnalyticsWorkspaceName" -Value $LogAnalyticsWorkspaceName
                    $Definition | Add-Member -MemberType NoteProperty -Name "ManagedIdentityName" -Value $ManagedIdentityName
                    $Definition | Add-Member -MemberType NoteProperty -Name "SentinelConnectionName" -Value $SentinelConnectionName
                    $Definition | Add-Member -MemberType NoteProperty -Name "KeyVaultName" -Value $KeyVaultName
                    $Definition | Add-Member -MemberType NoteProperty -Name "KeyVaultConnectionName" -Value $KeyVaultConnectionName
                }
                Default {
                    throw "Defintion Type $_ not Supported"
                }
            }
        }

        $AutomationDefinition = $Resources.Automation
        if($null -ne $AutomationDefinition)
        {
            if($null -ne $AutomationDefinition) {
                switch ($AutomationDefinition.Type) {
                    "Literal" {
                        $Definition | Add-Member -MemberType NoteProperty -Name "AutomationAccountName" -Value $AutomationDefinition.LogAnalyticsWorkspaceName
                        $Definition | Add-Member -MemberType NoteProperty -Name "AutomationAccountConnectionName" -Value $AutomationDefinition.ManagedIdentityName
                    }
                    "Automatic" {
                        $AutomationAccountName = New-NamingConvention -Prefix $Prefix -EnvironmentName $EnvironmentName -Suffix "automation" -NamingTemplate $NamingTemplate
                        $AutomationAccountConnectionName = New-NamingConvention -Prefix $Prefix -EnvironmentName $EnvironmentName -Suffix "automationconnection" -NamingTemplate $NamingTemplate
                        $Definition | Add-Member -MemberType NoteProperty -Name "AutomationAccountName" -Value $AutomationAccountName
                        $Definition | Add-Member -MemberType NoteProperty -Name "AutomationAccountConnectionName" -Value $AutomationAccountConnectionName
                    }
                    Default {
                        throw "Defintion Type $_ not Supported"
                    }
                }
            }
        }

        $IntegrationDefinition = $Resources.Integration
        if($null -ne $IntegrationDefinition)
        {
            if($null -ne $IntegrationDefinition) {
                switch ($IntegrationDefinition.Type) {
                    "Literal" {
                        $Definition | Add-Member -MemberType NoteProperty -Name "EventHubNamespaces" -Value $IntegrationDefinition.EventHubNamespaces
                        $Definition | Add-Member -MemberType NoteProperty -Name "StorageAccountName" -Value $IntegrationDefinition.StorageAccountName
                    }
                    "Automatic" {
                        $MaxEventHubNamespaces = [int]$IntegrationDefinition.MaxEventHubNamespaces
                        if($MaxEventHubNamespaces -le 10) {
                            $EventHubNamespaces = @()
                            1..$MaxEventHubNamespaces | ForEach-Object {
                                $EventHubNamespace = New-NamingConvention -Prefix $Prefix -EnvironmentName $EnvironmentName -Suffix "eh$(([string]$_).Padleft(3, "0"))" -NamingTemplate $NamingTemplate
                                $EventHubNamespaces += $EventHubNamespace
                            }                    
                            $StorageAccount = New-NamingConvention -Prefix $Prefix -EnvironmentName $EnvironmentName -Suffix "sta" -NamingTemplate $NamingTemplate -SkipDashes
                            $Definition | Add-Member -MemberType NoteProperty -Name "EventHubNamespaces" -Value $EventHubNamespaces
                            $Definition | Add-Member -MemberType NoteProperty -Name "StorageAccountName" -Value $StorageAccount
                        }
                        else {
                            throw "Maximum number of Event Hub Namespaces to be defined must be 10"
                        }
                    }
                    Default {
                        throw "Defintion Type $_ not Supported"
                    }
                }
            }
        }
    }

    $Definition | Add-Member -MemberType NoteProperty -Name "Properties" -Value $EnvironmentDefinition.Properties
    return $Definition
}

function Import-ContextSettings{
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [string]
        $SettingsFile,
        [Parameter(Mandatory = $false)]
        [switch]
        $AsHashtable
    )

    $SettingsFileExists = Test-Path -Path $SettingsFile -PathType Leaf
    if(-not $SettingsFileExists){
        throw "Settings file not found"
    }

    $Settings = Get-Content -Path $SettingsFile -Raw | ConvertFrom-Json -AsHashtable:$AsHashtable
    return $Settings
}

function Merge-ParametersSettings {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [hashtable]
        $Settings,
        [Parameter(Mandatory = $true)]
        [string]
        $File,
        [Parameter(Mandatory = $false)]
        [switch]
        $PassThru,
        [Parameter(Mandatory = $false)]
        [string]
        $NameTemplate = "parameters.json"
    )

    $ParametersContent = Get-Content -Path $File -Raw
    Write-Verbose " ### BEGIN PARAMETERS FILE ##"
    Write-Verbose $ParametersContent
    Write-Verbose " ### END PARAMETERS FILE ##"
    $Builder = [System.Text.StringBuilder]::new($ParametersContent)
    $Settings.GetEnumerator() | ForEach-Object {
        Write-Verbose "Key: $($_.Key.ToLowerInvariant()) => (Id: $($_.Value.Id))"
        Write-Verbose "Key: $($_.Key.ToLowerInvariant()) => (Name: $($_.Value.Name))"
        Write-Verbose "Replacing => [settings('($_.Key.ToLowerInvariant())').Id]"
        [void]$Builder.Replace("[settings('$($_.Key.ToLowerInvariant())').Id]", $_.Value.Id)
        Write-Verbose "Replacing => [settings('$($_.Key.ToLowerInvariant())').Name]"
        [void]$Builder.Replace("[settings('$($_.Key.ToLowerInvariant())').Name]", $_.Value.Name)
        Write-Verbose "Replacing => [settings('$($_.Key.ToLowerInvariant())').id]"
        [void]$Builder.Replace("[settings('$($_.Key.ToLowerInvariant())').id)]", $_.Value.Id)
        Write-Verbose "Replacing => [settings('$($_.Key.ToLowerInvariant())').name]"
        [void]$Builder.Replace("[settings('$($_.Key.ToLowerInvariant())').name)]", $_.Value.Name)
    }

    $TemplateParametersFileOutput = $File.Replace($NameTemplate, "transformed.$($NameTemplate)")
    Write-Verbose " ### BEGIN TRANSFORMED PARAMETERS FILE ##"
    Write-Verbose $Builder.ToString()
    Write-Verbose " ### END TRANSFORMED PARAMETERS FILE ##"
    $Builder.ToString() | Out-File -FilePath $TemplateParametersFileOutput -Force
    if($PassThru) {
        return Get-Item -LiteralPath $TemplateParametersFileOutput
    }
}