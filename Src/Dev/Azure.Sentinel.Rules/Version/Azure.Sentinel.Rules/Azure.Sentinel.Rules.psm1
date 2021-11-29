#requires -module @{ModuleName = 'Az.Accounts'; ModuleVersion = '1.5.2'}

$Module = Get-Module -Name Az.SecurityInsights -ListAvailable -ErrorAction SilentlyContinue
if($null -eq $Module) {
    Install-Module -Name Az.SecurityInsights -Force
}

$YamlModule = Get-Module -Name powershell-yaml -ListAvailable -ErrorAction SilentlyContinue
if($null -eq $YamlModule) {
    Install-Module -Name powershell-yaml -Force
}

function Get-AzSentinelAnalyticRule {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [string]
        $ResourceGroupName,
        [Parameter(Mandatory = $true)]
        [string]
        $WorkspaceName,
        [Parameter(Mandatory = $false)]
        [string]
        $AlertId,
        [Parameter(Mandatory = $false)]
        [switch]
        $IncludeETag
    )

    $Workspace = Get-AzOperationalInsightsWorkspace -Name $WorkspaceName -ResourceGroupName $ResourceGroupName
    $SingleAlertRequest = -not ([string]::IsNullOrEmpty($AlertId))
    if($SingleAlertRequest)
    {
        $Url = "$($Workspace.ResourceId)/providers/Microsoft.SecurityInsights/alertRules/$($AlertId)?api-version=2020-01-01"
        $Response = Invoke-AzRestMethod -Path $Url -Method GET 
        if($Response.StatusCode -eq 200) {
            $AlertRule = $Response.Content | ConvertFrom-Json
            if ($null -ne $AlertRule) {
                Write-Verbose "Found Analytic Rule with Id $AlertId"
                $Alert = Convert-AzSentinelAnalyticsRule -SentinelRule $AlertRule
                if($IncludeETag){
                    $Alert | Add-Member -NotePropertyName "ETag" -NotePropertyValue $AlertRule.etag -Force
                }
                return $Alert
            }
        }
        else {
            Write-Verbose "$($WorkspaceName) has not Analytic Rules with Id $AlertId"
            return $null
        }
    }
    else {
        $Url = "$($Workspace.ResourceId)/providers/Microsoft.SecurityInsights/alertRules?api-version=2020-01-01"
        $Response = Invoke-AzRestMethod -Path $Url -Method GET 
        $Content = $Response.Content | ConvertFrom-Json
        $AlertRules = $Content.value
        if ($null -ne $AlertRules) {
            $alertRulesSet = [System.Collections.ArrayList]@()
            Write-Verbose "Found $($AlertRules.count) analytic rules"
            $AlertRules | ForEach-Object {
                $Alert = Convert-AzSentinelAnalyticsRule -SentinelRule $_
                if($IncludeETag){
                    $Alert | Add-Member -NotePropertyName "ETag" -NotePropertyValue $AlertRule.etag -Force
                }
                [void]$alertRulesSet.Add($Alert)
            }
            return $alertRulesSet
        }
        else {
            Write-Verbose "$($WorkspaceName) has not Analytic Rules defined"
            return $null;
        }
    }
}

function Convert-AzSentinelAnalyticsRule {
    param (
        [Parameter(Mandatory = $true)]
        [PsCustomObject]
        $SentinelRule 
    )

    switch ($SentinelRule.kind) {
        "Fusion" {  
            $SentinelRuleProperties = $SentinelRule.properties
            $Rule = [PSCustomObject]@{
                AlertRuleTemplateName = $SentinelRuleProperties.alertRuleTemplateName
                Id = $SentinelRule.name
                DisplayName = $SentinelRuleProperties.displayName
                Description = $SentinelRuleProperties.description
                Severity = $SentinelRuleProperties.severity
                Enabled = $SentinelRuleProperties.enabled
                Kind = $SentinelRule.kind
            }
        }
        "Scheduled" {
            $SentinelRuleProperties = $SentinelRule.properties
            $Rule = [PSCustomObject]@{
                AlertRuleTemplateName = $SentinelRuleProperties.alertRuleTemplateName
                Id = $SentinelRule.name
                Enabled = $SentinelRuleProperties.enabled
                DisplayName = $SentinelRuleProperties.displayName
                Description = $SentinelRuleProperties.description
                Query = $SentinelRuleProperties.query
                SeveritiesFilter = $SentinelRuleProperties.severitiesFilter
                Severity = $SentinelRuleProperties.severity
                QueryFrequency = $SentinelRuleProperties.queryFrequency
                QueryPeriod = $SentinelRuleProperties.queryPeriod
                TriggerOperator = $SentinelRuleProperties.triggerOperator
                TriggerThreshold = $SentinelRuleProperties.triggerThreshold
                Tactics = $SentinelRuleProperties.tactics
                EventGroupSettings = $SentinelRuleProperties.eventGroupingSettings
                SuppressionDuration = $SentinelRuleProperties.suppressionDuration
                SuppressionEnabled = $SentinelRuleProperties.suppressionEnabled
                IncidentConfiguration = $SentinelRuleProperties.incidentConfiguration
                EntityMappings = $SentinelRuleProperties.entityMappings
                Kind = $SentinelRule.kind
            }
        }
        "MLBehaviorAnalytics" {
            $SentinelRuleProperties = $SentinelRule.properties
            $Rule = [PSCustomObject]@{
                AlertRuleTemplateName = $SentinelRuleProperties.alertRuleTemplateName
                Id = $SentinelRule.name
                Enabled = $SentinelRuleProperties.enabled
                DisplayName = $SentinelRuleProperties.displayName
                Description = $SentinelRuleProperties.description
                Severity = $SentinelRuleProperties.severity
                Tactics = $SentinelRuleProperties.tactics
                Kind = $SentinelRule.kind
            }
        }
        "MicrosoftSecurityIncidentCreation" {
            $SentinelRuleProperties = $SentinelRule.properties
            $Rule = [PSCustomObject]@{
                AlertRuleTemplateName = $SentinelRuleProperties.alertRuleTemplateName
                Id = $SentinelRule.name
                Enabled = $SentinelRuleProperties.enabled
                DisplayName = $SentinelRuleProperties.displayName
                Description = $SentinelRuleProperties.description
                SeveritiesFilter = $SentinelRuleProperties.severitiesFilter
                DisplayNamesExcludeFilter = $SentinelRuleProperties.displayNamesExcludeFilter
                DisplayNamesFilter = $SentinelRuleProperties.displayNamesFilter
                ProductFilter = $SentinelRuleProperties.productFilter
                Tactics = $SentinelRuleProperties.tactics
                Kind = $SentinelRule.kind
            }
        }
        "Anomaly" {
            $SentinelRuleProperties = $SentinelRule.properties
            if($null -ne $SentinelRuleProperties){
                $CustomizableObservations = $SentinelRuleProperties.customizableObservations
            }
            $Rule = [PSCustomObject]@{
                AlertRuleTemplateName = $SentinelRuleProperties.alertRuleTemplateName
                Id = $SentinelRule.name
                Enabled = $SentinelRuleProperties.enabled
                DisplayName = $SentinelRuleProperties.displayName
                Description = $SentinelRuleProperties.description
                AnomalyVersion = $SentinelRuleProperties.anomalyVersion
                MultiSelectObservations = $CustomizableObservations.multiSelectObservations
                SingleSelectObservations = $CustomizableObservations.singleSelectObservations
                PrioritizeExcludeObservations = $CustomizableObservations.prioritizeExcludeObservations
                ThresholdObservations = $CustomizableObservations.thresholdObservations
                SingleValueObservations = $SentinelRuleProperties.singleValueObservations
                Frequency = $SentinelRuleProperties.frequency
                IsDefaultRule = $SentinelRuleProperties.isDefaultRule
                RuleStatus = $SentinelRuleProperties.ruleStatus
                Tactics = $SentinelRuleProperties.tactics
                AnomalyRuleVersion = $SentinelRuleProperties.anomalyRuleVersion
                Kind = $SentinelRule.kind
            }
        }
        Default {
            throw "Not Supported Rule"
        }
    }
    return $Rule;
}

function Remove-AzSentinelAnalyticRule {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [string]
        $ResourceGroupName,
        [Parameter(Mandatory = $true)]
        [string]
        $WorkspaceName,
        [Parameter(Mandatory = $false)]
        [string]
        $AlertId
    )

    $Url = "$($Workspace.ResourceId)/providers/Microsoft.SecurityInsights/alertRules/$($AlertId)?api-version=2020-01-01"
    $Response = Invoke-AzRestMethod -Path $Url -Method DELETE 
    if(($Response.StatusCode -ne 200) -and ($Response.StatusCode -ne 204)) {
        throw "Analytic Rule with Id $AlertId cannot be deleted"
    }
}

function New-AzSentinelAnalyticRule {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [PsCustomObject]
        $Rule,
        [Parameter(Mandatory = $true)]
        [string]
        $ResourceGroupName,
        [Parameter(Mandatory = $true)]
        [string]
        $WorkspaceName
    )

    try {
        $Workspace = Get-AzOperationalInsightsWorkspace -Name $WorkspaceName -ResourceGroupName $ResourceGroupName
        
        Write-Verbose -Message "Get analytic rule $DisplayName"
        $AnalyticRule = Get-AzSentinelAnalyticRule -ResourceGroupName $ResourceGroupName -WorkspaceName $WorkspaceName -AlertId $Rule.Id -IncludeETag -WarningAction SilentlyContinue

        if ($null -ne $AnalyticRule) {
            Write-Verbose -Message "Analytic rule $($DisplayName) is deployed on Sentinel"
            $ETag = $null
            if($AnalyticRule.Kind -eq "Fusion") {
                Remove-AzSentinelAnalyticRule -WorkspaceName $WorkspaceName -ResourceGroupName $ResourceGroupName -AlertId $AnalyticRule.Id
            }
            else {
                $ETag = $AnalyticRule.ETag
            }

            $RuleItem = [PSCustomObject]@{
                name = $AnalyticRule.Id
                etag = $ETag
                type = "Microsoft.SecurityInsights/alertRules"
                kind = $AnalyticRule.Kind
                id = "$($Workspace.ResourceId)/providers/Microsoft.SecurityInsights/alertRules/$($AnalyticRule.Id)"
                properties = @{}
            }
            
            $ruleId = $AnalyticRule.Id
        }
        else {
            Write-Verbose -Message "Analytic rule $($DisplayName) is new on this Azure Sentinel"

            if($Rule.Id){
                $identifier = $Rule.Id
            }
            else {
                $identifier = (New-Guid).Guid
            }
            
            $RuleItem = [PSCustomObject]@{
                name = $identifier
                etag = $null
                type = "Microsoft.SecurityInsights/alertRules"
                kind = $Rule.Kind
                id = "$($Workspace.ResourceId)/providers/Microsoft.SecurityInsights/alertRules/$identifier"
                properties = @{}
            }

            $ruleId = $identifier
        }

        switch ($Rule.Kind) {
            "Fusion" { 
                $RuleProperties = $Rule.GetEnumerator()
                $RuleProperties = $RuleProperties | Where-Object { ($_.Key -ne "Id") -and`
                                                 ($_.Key -ne "Kind") -and`
                                                 ($_.Key -ne "DisplayName") -and`
                                                 ($_.Key -ne "Severity") -and`
                                                 ($_.Key -ne "Description") }
            }
            "Scheduled" { 
                $RuleProperties = $Rule.GetEnumerator()
                $RuleProperties = $RuleProperties | Where-Object { ($_.Key -ne "Id") -and`
                                                 ($_.Key -ne "Kind") }
            }
            "MicrosoftSecurityIncidentCreation" { 
                $RuleProperties = $Rule.GetEnumerator()
                $RuleProperties = $RuleProperties | Where-Object { ($_.Key -ne "Id") -and`
                                                 ($_.Key -ne "Kind") }
            }
            "MLBehaviorAnalytics" { 
                $RuleProperties = $Rule.GetEnumerator()
                $RuleProperties = $RuleProperties | Where-Object { ($_.Key -ne "Id") -and`
                                                 ($_.Key -ne "Kind") -and`
                                                 ($_.Key -ne "DisplayName") -and`
                                                 ($_.Key -ne "Description") -and`
                                                 ($_.Key -ne "Severity") -and`
                                                 ($_.Key -ne "Tactics") }
            }
            "Anomaly" { 
                $CustomizableObservations = [PSCustomObject]@{
                    MultiSelectObservations = $Rule.MultiSelectObservations
                    SingleSelectObservations =  $Rule.SingleSelectObservations
                    PrioritizeExcludeObservations = $Rule.PrioritizeExcludeObservations
                    ThresholdObservations = $Rule.ThresholdObservations
                    SingleValueObservations = $Rule.SingleValueObservations
                }

                $Rule.Add("CustomizableObservations", $CustomizableObservations)
                
                $RuleProperties = $Rule.GetEnumerator()
                $RuleProperties = $RuleProperties | Where-Object { ($_.Key -ne "Id") -and`
                                                                    ($_.Key -ne "Kind") -and`
                                                                    ($_.Key -ne "Severity") -and`
                                                                    ($_.Key -ne "MultiSelectObservations") -and`
                                                                    ($_.Key -ne "SingleSelectObservations") -and`
                                                                    ($_.Key -ne "PrioritizeExcludeObservations") -and`
                                                                    ($_.Key -ne "ThresholdObservations") -and`
                                                                    ($_.Key -ne "SingleValueObservations") -and`
                                                                    ($_.Key -ne "Description") }
            }
            Default {
                throw "Not Supported Rule"
            }
        }
        
        $RuleProperties | ForEach-Object{
            $Key = "$([char]::ToLowerInvariant($_.Key[0]))$($_.Key.Substring(1))"
            $Value = $_.Value
            $RuleItem.properties.Add($Key, $Value)
        }

        $Url = "$($Workspace.ResourceId)/providers/Microsoft.SecurityInsights/alertRules/$($ruleId)?api-version=2020-01-01"
        $Body = $RuleItem | ConvertTo-Json -Depth 10
        $Response = Invoke-AzRestMethod -Path $Url -Method PUT -Payload $Body
        if(($Response.StatusCode -ne 200) -and ($Response.StatusCode -ne 201)){
            throw $Response.Content
        }
    }
    catch {
        Write-Verbose $_
        throw "Error creating or updating an Analytic rule with error $($_.Exception.Message)" 
    }
}

function Clear-FileName {
    param(
        [Parameter(Mandatory = $true)]
        [string]
        $Name
    )

    $invalidChars = [System.IO.Path]::GetInvalidFileNameChars()
    $cleanName = [RegEx]::Replace($Name, "[$invalidChars]", [string]::Empty)
    return $cleanName
}

function Save-AzSentinelRule {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true, ValueFromPipeline = $true)]
        [PSCustomObject]
        $Rule,
        [Parameter(Mandatory = $true)]
        [ValidateSet("Json", "Yaml")]
        [string]
        $Format,
        [Parameter(Mandatory = $true)]
        [ValidateSet("Analytics", "Hunting", "LiveStream", "Automation")]
        [string]
        $Kind,
        [Parameter(Mandatory = $true)]
        [string]
        $Path
    )

    if($null -ne $Rule) {
        $Name = $Rule.DisplayName
        if([string]::IsNullOrEmpty($Name)) {
            $Name = $Rule.Id
        }
        $Name = Clear-FileName -Name $Name
        $OutputPathFileName = Join-Path -Path $Path -ChildPath "$($Name).$($Kind.ToLowerInvariant()).rule.$($Format.ToLowerInvariant())"
        switch ($Format) {
            "Yaml" { 
                $Rule | ConvertTo-Yaml -OutFile $OutputPathFileName -Force
                }
            "Json" { 
                $Rule | ConvertTo-Json -Depth 10 -EnumsAsStrings | Out-File -FilePath $OutputPathFileName -Force 
            }
            Default {}
        }
    }
    else {
        throw "Rule is null or invalid"
    }
}

function Import-AzSentinelAnalyticRules {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [string]
        $ResourceGroupName,
        [Parameter(Mandatory = $true)]
        [string]
        $WorkspaceName,
        [Parameter(Mandatory = $true)]
        [string]
        $Path,
        [Parameter(Mandatory = $true)]
        [ValidateSet("Json","Yaml","All")]
        [string]
        $Format
    )

    $IncludeFiles = @()
    switch ($Format) {
        "Yaml" {
            $IncludeFiles += "*.analytics.rule.yaml"
        }
        "Json" {
            $IncludeFiles += "*.analytics.rule.json"
        }
        Default {
            $IncludeFiles += "*.analytics.rule.json"
            $IncludeFiles += "*.analytics.rule.yaml"
        }
    }

    $HasErrors = $false
    $AlertDefinitions = Get-ChildItem -Path $Path -Include $IncludeFiles -Recurse -File
    $AlertDefinitions | ForEach-Object {
        $File = $_
        Write-Host ([string]::Empty)
        Write-Host "$($_.Name)" -ForegroundColor Blue
        Write-Host ([string]::Empty)
        try {
            if($File.Name.EndsWith(".yaml")) {
                $Definition = Get-Content -Path $File.FullName -Raw | ConvertFrom-Yaml
            }
            if($File.Name.EndsWith(".json")) {
                $Definition = Get-Content -Path $File.FullName -Raw | ConvertFrom-Json -Depth 2
            }
            Write-Output $Definition
            if($null -ne $Definition) {            
                New-AzSentinelAnalyticRule -ResourceGroupName $ResourceGroupName -WorkspaceName $WorkspaceName -Rule $Definition
            }
            else {
                throw "Not supported file"
            }
        }
        catch {
            $ErrorActionPreference = 'Continue'
            $HasErrors = $true
            Write-Error $_
        }
    }

    if($HasErrors){
        throw "Some Rules cannot be Deployed"
    }
}

function Remove-AzSentinelHuntingRule {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string] $ResourceGroupName,
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string] $WorkspaceName
    )

    $Workspace = Get-AzOperationalInsightsWorkspace -Name $WorkspaceName -ResourceGroupName $ResourceGroupName
        
    Write-Verbose -Message "Get hunting rule $DisplayName"
    $Rule = Get-AzSentinelHuntingRule -ResourceGroup $ResourceGroupName -WorkspaceName $WorkspaceName -RuleId $HuntingRule.Id -Filter $HuntingRule.Category -IncludeEtag -WarningAction SilentlyContinue

    if ($null -ne $Rule) {
        $huntingRulesUri = "$($Workspace.ResourceId)/savedSearches/{0}?api-version=2017-04-26-preview" -f $ruleId
        Write-Verbose "Removing hunting rule: $($DisplayName)"
        Write-Verbose -Message "Using URI: $($huntingRulesUri)"

        $httpResponse = Invoke-AzRestMethod -Path $huntingRulesUri -Method DELETE -Payload $BodyAsJson
        if($httpResponse.StatusCode -ne 200){
            throw $Response.Content
        }
    }
}

function New-AzSentinelHuntingRule {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string] 
        $ResourceGroupName,
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string] 
        $WorkspaceName,
        [Parameter(Mandatory = $true)]
        [PsCustomObject]
        $HuntingRule
    )
    try {
        $Workspace = Get-AzOperationalInsightsWorkspace -Name $WorkspaceName -ResourceGroupName $ResourceGroupName
        
        Write-Verbose -Message "Get hunting rule $DisplayName"
        $Rule = Get-AzSentinelHuntingRule -ResourceGroup $ResourceGroupName -WorkspaceName $WorkspaceName -RuleId $HuntingRule.Id -Filter $HuntingRule.Category -IncludeEtag -WarningAction SilentlyContinue

        if ($null -ne $Rule) {
            Write-Verbose -Message "Hunting rule $($DisplayName) is deployed on Sentinel"

            $RuleItem = [PSCustomObject]@{
                Name = $Rule.Id
                Etag = $Rule.ETag
                Id = "$($Workspace.ResourceId)/savedSearches/$identifier"
            }
            $ruleId = $Rule.Id
        }
        else {
            Write-Verbose -Message "Hunting rule $($DisplayName) is new on this Azure Sentinel"

            if($HuntingRule.Id){
                $identifier = $HuntingRule.Id
            }
            else {
                $identifier = (New-Guid).Guid
            }
            
            $RuleItem = [PSCustomObject]@{
                Name = $identifier
                Etag = $null
                Id = "$($Workspace.ResourceId)/savedSearches/$identifier"
            }
            $ruleId = $identifier
        }

        $DisplayName = $HuntingRule.DisplayName
        
        [PSCustomObject]$body = @{
            "name"       = $RuleItem.Name
            "eTag"       = $RuleItem.Etag
            "id"         = $RuleItem.Id
            "properties" = @{
                'Category'             = $HuntingRule.Category
                'DisplayName'          = $HuntingRule.DisplayName
                'Query'                = $HuntingRule.Query
                [pscustomobject]'Tags' = @(
                    @{
                        'Name'  = "description"
                        'Value' = $HuntingRule.Description
                    },
                    @{
                        "Name"  = "tactics"
                        "Value" = $Tactics -join ','
                    },
                    @{
                        "Name"  = "createdBy"
                        "Value" = ""
                    },
                    @{
                        "Name"  = "createdTimeUtc"
                        "Value" = "$(Get-Date)"
                    }
                )
            }
        }

        $huntingRulesUri = "$($Workspace.ResourceId)/savedSearches/{0}?api-version=2017-04-26-preview" -f $ruleId
        $BodyAsJson = ($body | ConvertTo-Json -Depth 10 -EnumsAsStrings)
        Write-Verbose "Updating new hunting rule: $($DisplayName)"
        Write-Verbose -Message "Using URI: $($huntingRulesUri)"

        $httpResponse = Invoke-AzRestMethod -Path $huntingRulesUri -Method Put -Payload $BodyAsJson
        if($httpResponse.StatusCode -ne 200){
            throw $Response.Content
        }
    }
    catch {
        Write-Verbose $_
        throw "Error creating or updating an Hunting rule with error $($_.Exception.Message)" 
    }
}


function Get-AzSentinelHuntingRule {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]
        $ResourceGroupName,
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]
        $WorkspaceName,
        [Parameter(Mandatory = $false)]
        [string]
        $RuleId,
        [Parameter(Mandatory = $false)]
        [ValidateSet("HuntingQueries", "LiveStreamQueries", "All")]
        [string]
        $Filter = "All",
        [Parameter(Mandatory = $false)]
        [switch]
        $IncludeEtag
    )

    switch ($Filter) {
        "HuntingQueries" {  
            $NamingFilter = "Hunting Queries"
        }
        "LiveStreamQueries" {
            $NamingFilter = "Live Stream Queries"
        }
    }
    
    $Workspace = Get-AzOperationalInsightsWorkspace -Name $WorkspaceName -ResourceGroupName $ResourceGroupName
    if([string]::IsNullOrEmpty($RuleId)) {
        $huntingRulesUri = "$($Workspace.ResourceId)/savedSearches?api-version=2020-08-01"
    }
    else {
        $huntingRulesUri = "$($Workspace.ResourceId)/savedSearches/$($RuleId)?api-version=2020-08-01"
    }

    Write-Verbose -Message "Using URI: $($huntingRulesUri)"

    try {
        $httpResponse = Invoke-AzRestMethod -Path $huntingRulesUri -Method Get
        if($null -ne $httpResponse) {
            if($httpResponse.StatusCode -eq 200) {
                if([string]::IsNullOrEmpty($RuleId)) {
                    $Content = $httpResponse.Content | ConvertFrom-Json
                    if("All" -ne $Filter) {
                        $huntingRules = $Content.value | Where-Object { $_.properties.Category -eq $NamingFilter }
                    }
                    else {
                        $huntingRules = $Content.value | Where-Object { ($_.properties.Category -eq "Hunting Queries") -or ($_.properties.Category -eq "Live Stream Queries") }
                    }
                    if ($null -ne $huntingRules) {
                        $huntingRulesSet = [System.Collections.ArrayList]@()
                        Write-Verbose "Found $($huntingRules.count) rules"
                        $huntingRules | ForEach-Object {
                            $Properties = $_.properties
                            switch ($Properties.Category) {
                                "Hunting Queries" {
                                    $Kind = "Hunting"
                                }
                                "Live Stream Queries" {
                                    $Kind = "LiveStream"
                                }
                            }

                            $Rule = [PSCustomObject]@{
                                Category = $Kind
                                DisplayName = $Properties.DisplayName
                                Version = $Properties.Version
                                Query = $Properties.Query
                                Id = $_.name
                                Description = ($Properties.Tags | Where-Object {$_.Name -eq "description"}).Value
                                Tactics = Get-TacticsAsArray -Tactics ($Properties.Tags | Where-Object {$_.Name -eq "tactics"}).Value
                            }
                            if($IncludeETag) {
                                $Rule | Add-Member -NotePropertyName etag -NotePropertyValue $_.etag -Force
                            }
                            $huntingRulesSet.Add($Rule) | Out-Null
                        }
                        return $huntingRulesSet
                    }
                    else {
                        Write-Verbose "$($WorkspaceName) has not Hunting Rules defined"
                        return $null;
                    }
                }
                else {
                    $huntingRule = $httpResponse.Content | ConvertFrom-Json
                    switch ($huntingRule.properties.Category) {
                        "Hunting Queries" {
                            $Kind = "Hunting"
                        }
                        "Live Stream Queries" {
                            $Kind = "LiveStream"
                        }
                    }
                    
                    $Rule = [PSCustomObject]@{
                        Category = $Kind
                        DisplayName = $huntingRule.DisplayName
                        Query = $huntingRule.Query
                        Id = $huntingRule.name
                        Description = ($HuntingRule.Tags | Where-Object {$_.Name -eq "description"}).Value
                        Tactics = Get-TacticsAsArray -Tactics ($HuntingRule.Tags | Where-Object {$_.Name -eq "tactics"}).Value
                    }
                    if($IncludeETag) {
                        $Rule | Add-Member -NotePropertyName etag -NotePropertyValue $huntingRule.etag -Force
                    }                    
                    return $Rule
                }
            }
        }        
    }
    catch {
        Write-Debug $_
        throw "Unexpected Error getting the information for Hunting Rules with message: $($_.Exception.Message)"
    }    
}

function Export-AzSentinelHuntingRules {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [string]
        $Path,
        [Parameter(Mandatory = $true)]
        [string]
        $ResourceGroupName,
        [Parameter(Mandatory = $true)]
        [string]
        $WorkspaceName,
        [Parameter(Mandatory = $true)]
        [ValidateSet("Json", "Yaml")]
        [string]
        $Format,
        [Parameter(Mandatory = $false)]
        [string]
        $RuleId,
        [Parameter(Mandatory = $false)]
        [ValidateSet("Hunting Queries", "Livestream Queries", "All")]
        [string]
        $Filter = "All"
    )

    if(-not (Test-Path -Path $Path)) {
        New-Item -Path $Path -ItemType Directory -Force | Out-Null
    }

    if([string]::IsNullOrEmpty($RuleId)) {
        $huntingRules = Get-AzSentinelHuntingRule -WorkspaceName $WorkspaceName -ResourceGroup $ResourceGroupName -Filter $Filter
    }
    else {
        $huntingRules = Get-AzSentinelHuntingRule -WorkspaceName $WorkspaceName -ResourceGroup $ResourceGroupName -RuleId $RuleId -Filter $Filter
    }

    if($null -ne $huntingRules) {
        if(-not [string]::IsNullOrEmpty($RuleId)) {
            Write-Host "Exporting Hunting Rule $($huntingRules.DisplayName)"
            $kind = $huntingRules.Category
            $huntingRules | Save-AzSentinelRule -Kind $Kind -Format $Format -Path $Path
        }
        else {
            $huntingRules | ForEach-Object {
                Write-Host "Exporting Hunting Rule $($_.DisplayName)"
                $_ | Save-AzSentinelRule -Kind $_.Category -Format $Format -Path $Path
            }
        }
    }
}

function Get-TacticsAsArray {
    param (
        [Parameter(Mandatory = $false)]
        [string]
        $Tactics
    )
    
    if(-not [string]::IsNullOrEmpty($Tactics)) {
        return $Tactics -split ","
    }
    else {
        return @($Tactics)
    }
}

function Import-AzSentinelHuntingRules {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [string]
        $ResourceGroupName,
        [Parameter(Mandatory = $true)]
        [string]
        $WorkspaceName,
        [Parameter(Mandatory = $true)]
        [string]
        $Path,
        [Parameter(Mandatory = $true)]
        [ValidateSet("Json","Yaml","All")]
        [string]
        $Format
    )

    $IncludeFiles = @()
    switch ($Format) {
        "Yaml" {
            $IncludeFiles += "*.hunting.rule.playbooks.yaml"
        }
        "Json" {
            $IncludeFiles += "*.hunting.rule.playbooks.json"
        }
        Default {
            $IncludeFiles += "*.hunting.rule.playbooks.json"
            $IncludeFiles += "*.hunting.rule.playbooks.yaml"
        }
    }

    $HasErrors = $false
    $AlertDefinitions = Get-ChildItem -Path $Path -Include $IncludeFiles -Recurse -File
    $AlertDefinitions | ForEach-Object {
        $File = $_
        Write-Host ([string]::Empty)
        Write-Host "$($_.Name)" -ForegroundColor Blue
        Write-Host ([string]::Empty)
        try {
            if($File.Name.EndsWith(".yaml")) {
                $Definition = Get-Content -Path $File.FullName -Raw | ConvertFrom-Yaml
            }
            if($File.Name.EndsWith(".json")) {
                $Definition = Get-Content -Path $File.FullName -Raw | ConvertFrom-Json -Depth 2
            }
            Write-Output $Definition
            if($null -ne $Definition) {            
                New-AzSentinelHuntingRule -ResourceGroup $ResourceGroupName -WorkspaceName $WorkspaceName -HuntingRule $AlertDefinition
            }
            else {
                throw "Not supported file"
            }
        }
        catch {
            $ErrorActionPreference = 'Continue'
            $HasErrors = $true
            Write-Error $_
        }
    }

    if($HasErrors){
        throw "Some Analytic Rules cannot be Deployed"
    }
}

function Export-AzSentinelAnalyticsRules {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [string]
        $Path,
        [Parameter(Mandatory = $true)]
        [string]
        $ResourceGroupName,
        [Parameter(Mandatory = $true)]
        [string]
        $WorkspaceName,
        [Parameter(Mandatory = $true)]
        [ValidateSet("Json", "Yaml")]
        [string]
        $Format,
        [Parameter(Mandatory = $false)]
        [string]
        $AlertId
    )

    if(-not (Test-Path -Path $Path)) {
        New-Item -Path $Path -ItemType Directory -Force | Out-Null
    }

    if([string]::IsNullOrEmpty($AlertId)) {
        $Rules = Get-AzSentinelAnalyticRule -ResourceGroupName $ResourceGroupName -WorkspaceName $WorkspaceName
        if($null -ne $Rules) {
            $Rules | ForEach-Object {
                $SentinelRule = $_
                Write-Host "Exporting Analytic Rule $($SentinelRule.DisplayName)"
                $SentinelRule | Save-AzSentinelRule -Kind Analytics -Format $Format -Path $Path
            }
        }
    }
    else {
        $SentinelRule = Get-AzSentinelAnalyticRule -ResourceGroupName $ResourceGroupName -WorkspaceName $WorkspaceName -AlertId $RuleId
        Write-Host "Exporting Analytic Rule $($SentinelRule.DisplayName)"
        $SentinelRule | Save-AzSentinelRule -Kind Analytics -Format $Format -Path $Path
    }
}

function Export-AzPlaybookAndRuleConnections{
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $false)]
        [string]
        $AlertRuleId,
        [Parameter(Mandatory = $true)]
        [string]
        $ResourceGroupName,
        [Parameter(Mandatory = $true)]
        [string]
        $WorkspaceName,
        [Parameter(Mandatory = $true)]
        [string]
        $Path,
        [Parameter(Mandatory = $true)]
        [ValidateSet("Json", "Yaml")]
        [string]
        $Format
    )

    if(-not (Test-Path -Path $Path)) {
        New-Item -Path $Path -ItemType Directory -Force | Out-Null
    }

    if([string]::IsNullOrEmpty($AlertRuleId)){
        $AlertRuleArray = Get-AzSentinelAnalyticRule -ResourceGroupName $ResourceGroupName -WorkspaceName $WorkspaceName -ErrorAction SilentlyContinue
    }
    else {
        $AlertRule = Get-AzSentinelAnalyticRule -ResourceGroupName $ResourceGroupName -WorkspaceName $WorkspaceName -AlertRuleId $AlertRuleId -ErrorAction SilentlyContinue    
        $AlertRuleArray = @(AlertRule)
    }
    
    if($null -ne $AlertRuleArray) {
        $AlertRuleArray | ForEach-Object {
            $AlertRule = $_
            $AlertRuleId = $AlertRule.Id
            $RuleActions = Get-AzSentinelAlertRuleAction -ResourceGroupName $ResourceGroupName -WorkspaceName $WorkspaceName -AlertRuleId $AlertRuleId -ErrorAction SilentlyContinue
            if($null -ne $RuleActions) {
                $RuleActions | ForEach-Object {
                    $RuleAction = $_
                    $Name = $RuleAction.Name
                    Write-Host "Exporting Alert Rule & Playbook Connection $($Name)"
                    $Name = Clear-FileName -Name $Name
                    $OutputPathFileName = Join-Path -Path $Path -ChildPath "$($Name).analytics.rule.playbooks.$($Format.ToLowerInvariant())"
                    switch ($Format) {
                        "Yaml" { 
                            $RuleAction | ConvertTo-Yaml -OutFile $OutputPathFileName -Force
                            }   
                        "Json" { 
                            $RuleAction | ConvertTo-Json -EnumsAsStrings | Out-File -FilePath $OutputPathFileName -Force 
                        }
                        Default {}
                    }
                }
            }
        }
    }
}

function Import-AzPlaybookAndRuleConnections
{
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [string]
        $ResourceGroupName,
        [Parameter(Mandatory = $true)]
        [string]
        $WorkspaceName,
        [Parameter(Mandatory = $true)]
        [string]
        $Path,
        [Parameter(Mandatory = $true)]
        [ValidateSet("Json", "Yaml", "All")]
        [string]
        $Format,
        [Parameter(Mandatory = $true)]
        [string]
        $SettingsFile
    )
    $Settings = Import-ContextSettings -SettingsFile $SettingsFile -AsHashtable
    Write-Verbose "Filter: $Format on Path: $Path"
    $IncludeFiles = @()
    switch ($Format) {
        "Yaml" {
            $IncludeFiles += "*.analytics.rule.playbooks.yaml"
        }
        "Json" {
            $IncludeFiles += "*.analytics.rule.playbooks.json"
        }
        Default {
            $IncludeFiles += "*.analytics.rule.playbooks.json"
            $IncludeFiles += "*.analytics.rule.playbooks.yaml"
        }
    }
    $HasErrors = $false
    $AlertDefinitions = Get-ChildItem -Path $Path -Include $IncludeFiles -Recurse -File
    $AlertDefinitions | ForEach-Object {
        $File = $_
        try {
            Write-Host ([string]::Empty)
            Write-Host "$($_.Name)" -ForegroundColor Blue
            Write-Host ([string]::Empty)

            $TransformedItem = Merge-ParametersSettings -Settings $Settings -File $File.FullName -PassThru -NameTemplate "analytics.rule.playbooks.json"
            if($File.Name.EndsWith(".yaml")) {
                $Definition = Get-Content -Path $TransformedItem.FullName -Raw | ConvertFrom-Yaml
            }
            if($File.Name.EndsWith(".json")) {
                $Definition = Get-Content -Path $TransformedItem.FullName -Raw | ConvertFrom-Json -Depth 2
            }
            Write-Output $Definition
            if($null -ne $Definition) {
                $Playbook = $Definition.Playbook
                if($null -ne $Playbook) {
                    Connect-AlertRuleAndPlaybook -ActionId $Definition.ActionId `
                                                    -AlertRuleId $Definition.AlertRuleId `
                                                    -ResourceGroup $ResourceGroupName `
                                                    -LogicAppName $Playbook `
                                                    -WorkspaceName $WorkspaceName
                }
                else {
                    Write-Warning "Playbooks are not defined on $($_.FullName)"
                }
            }
            else {
                throw "File ($File.FullName) is not valid"
            }
        }
        catch {
            $ErrorActionPreference = 'Continue'
            $HasErrors = $true
            Write-Error $_
        } 
        finally
        {
            if($null -ne $TransformedItem) {
                Remove-Item -LiteralPath $TransformedItem.FullName
            }
        }
    }

    if($HasErrors){
        throw "Some Rule Connections cannot be Deployed"
    }
}

function Connect-AlertRuleAndPlaybook {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [string]
        $AlertRuleId,
        [Parameter(Mandatory = $true)]
        [string]
        $ActionId,
        [Parameter(Mandatory = $true)]
        [string]
        $ResourceGroupName,
        [Parameter(Mandatory = $true)]
        [string]
        $LogicAppName,
        [Parameter(Mandatory = $true)]
        [string]
        $WorkspaceName
    )
    Write-Host "Preparing Connection between $AlertRuleId and $LogicAppName on $WorkspaceName in resource group $ResourceGroupName"
    $AlertRule = Get-AzSentinelAnalyticRule -ResourceGroupName $ResourceGroupName -WorkspaceName $WorkspaceName -AlertId $AlertRuleId 
    $LogicAppResourceId = Get-AzLogicApp -ResourceGroupName $ResourceGroupName -Name $LogicAppName 
    Write-Host "Setinel Alert Rule"
    Write-Output $AlertRule
    Write-Host "Logic App Definition"
    Write-Output $LogicAppResourceId    
    if($null -ne $LogicAppResourceId -and $null -ne $AlertRule) {
        $LogicAppTriggerUri = Get-AzLogicAppTriggerCallbackUrl -ResourceGroupName $ResourceGroupName -Name $LogicAppName -TriggerName "When_a_response_to_an_Azure_Sentinel_alert_is_triggered"
        Write-Host "Trigger Definition"
        Write-Output $LogicAppTriggerUri
        if($null -ne $LogicAppTriggerUri) {
            Write-Host "Rule Action: $RuleAction"
            $RuleAction = Get-AzSentinelAlertRuleAction -ResourceGroupName $ResourceGroupName -WorkspaceName $WorkspaceName -AlertRuleId $AlertRuleId -ActionId $ActionId -ErrorAction SilentlyContinue
            Write-Output $RuleAction
            if($null -eq $RuleAction) {
                New-AzSentinelAlertRuleAction -ResourceGroupName $ResourceGroupName -WorkspaceName $WorkspaceName -AlertRuleId $AlertRuleId -LogicAppResourceId ($LogicAppResourceId.Id) -TriggerUri ($LogicAppTriggerUri.Value) -ActionId $ActionId
            }
            else {
                Update-AzSentinelAlertRuleAction -ResourceGroupName $ResourceGroupName -WorkspaceName $WorkspaceName -AlertRuleId $AlertRuleId -LogicAppResourceId ($LogicAppResourceId.Id) -TriggerUri ($LogicAppTriggerUri.Value) -ActionId $ActionId
            }
        }
        else {
            throw "Trigger for Sentinel not found for Logic App $LogicAppName"
        }
    }
    else {
        if($null -eq $LogicAppResourceId -and $null -eq $AlertRule) {
            throw "Logic App $($LogicAppName) and Alert Rule with Id $($AlertRuleId) on Workspace $($WorkspaceName) not found in Resource Group $($ResourceGroupName)"
        }
        elseif($null -eq $AlertRule) {
            throw "Alert Rule with Id $($AlertRuleId) on Workspace $($WorkspaceName) not found in Resource Group $($ResourceGroupName)"
        }
        elseif($null -eq $LogicAppResourceId) {
            throw "Logic App $($LogicAppName) not found in Resource Group $($ResourceGroupName)"
        }
    }
}

function Get-AzSentinelAutomationRule {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [string]
        $ResourceGroupName,
        [Parameter(Mandatory = $true)]
        [string]
        $WorkspaceName,
        [Parameter(Mandatory = $false)]
        [string]
        $Id,
        [Parameter(Mandatory = $false)]
        [switch]
        $IncludeEtag
    )
  
    $SubscriptionId = (Get-AzContext).Subscription.Id
    if(-not [string]::IsNullOrEmpty($Id)) {
      $Response = Invoke-AzRestMethod -Path "/subscriptions/$($SubscriptionId)/resourcegroups/$($ResourceGroupName)/providers/microsoft.operationalinsights/workspaces/$($WorkspaceName)/providers/Microsoft.SecurityInsights/automationRules/$($Id)?api-version=2019-01-01-preview" -Method GET
        if($Response.StatusCode -eq 200) {
            $AutomationRule = $Response.Content | ConvertFrom-Json
            $AutomationRuleObject = [PSCustomObject]@{
            Id = $AutomationRule.name
            Name = $AutomationRule.properties.displayName
            Order = $AutomationRule.properties.order
            Trigger = [PSCustomObject]@{
                Enabled = $AutomationRule.properties.triggeringLogic.isEnabled
                ExpirationTimeUtc = $AutomationRule.properties.triggeringLogic.expirationTimeUtc
                TriggersOn = $AutomationRule.properties.triggeringLogic.triggersOn
                TriggersWhen = $AutomationRule.properties.triggeringLogic.triggersWhen
                Conditions = $AutomationRule.properties.triggeringLogic.conditions
            }
            Actions = $AutomationRule.properties.actions
            }
            if($IncludeEtag) {
            $AutomationRuleObject | Add-Member -NotePropertyName etag -NotePropertyValue $AutomationRule.etag -Force
            }
            return $AutomationRuleObject
        }
        elseif($Response.StatusCode -eq 404) {
            return $null
        }
        else {
            throw $Response.Content
        }
    }
    else {
        $Response = Invoke-AzRestMethod -Path "/subscriptions/$($SubscriptionId)/resourcegroups/$($ResourceGroupName)/providers/microsoft.operationalinsights/workspaces/$($WorkspaceName)/providers/Microsoft.SecurityInsights/automationRules?api-version=2019-01-01-preview" -Method GET
        if($Response.StatusCode -eq 200) {
            $AutomationRules = $Response.Content | ConvertFrom-Json
            $AutomationRuleObjects = [System.Collections.ArrayList]@()
            $AutomationRules.value | ForEach-Object {
            $AutomationRule = $_
            [PSCustomObject]@{
                Id = $AutomationRule.name
                Name = $AutomationRule.properties.displayName
                Order = $AutomationRule.properties.order
                Trigger = [PSCustomObject]@{
                Enabled = $AutomationRule.properties.triggeringLogic.isEnabled
                ExpirationTimeUtc = $AutomationRule.properties.triggeringLogic.expirationTimeUtc
                TriggersOn = $AutomationRule.properties.triggeringLogic.triggersOn
                TriggersWhen = $AutomationRule.properties.triggeringLogic.triggersWhen
                Conditions = $AutomationRule.properties.triggeringLogic.conditions
                }
                Actions = $AutomationRule.properties.actions
            }
            if($IncludeEtag) {
                $AutomationRuleObject | Add-Member -NotePropertyName etag -NotePropertyValue $_.etag -Force
            }
            $AutomationRuleObjects.Add($AutomationRuleObject) | Out-Null
            }
        }
        elseif($Response.StatusCode -eq 404) {
            return $null
        }
        else {
            throw $Response.Content
        }
    }
}
  
    function New-AzSentinelAutomationRule {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true, ParameterSetName = "Default")]
        [Parameter(Mandatory = $true, ParameterSetName = "RuleSet")]
        [string]
        $ResourceGroupName,
        [Parameter(Mandatory = $true, ParameterSetName = "Default")]
        [Parameter(Mandatory = $true, ParameterSetName = "RuleSet")]
        [string]
        $WorkspaceName,
        [Parameter(Mandatory = $true, ParameterSetName = "Default")]
        [string]
        $DisplayName,
        [Parameter(Mandatory = $true, ParameterSetName = "Default")]
        [string]
        $Id,
        [Parameter(Mandatory = $false, ParameterSetName = "Default")]
        [int]
        $Order = 1,
        [Parameter(Mandatory = $true, ParameterSetName = "Default")]
        [PsCustomObject]
        $Trigger,
        [Parameter(Mandatory = $true, ParameterSetName = "Default")]
        [PsCustomObject]
        $Actions,
        [Parameter(Mandatory = $true, ParameterSetName = "RuleSet")]
        [PsCustomObject]
        $Rule
    )

    if($null -ne $Rule) {
        $DisplayName = $Rule.Name
        $Id = $Rule.Id
        $Order = $Rule.Order
        $Trigger = $Rule.Trigger
        $Actions = $Rule.Actions
    }

    $SubscriptionId = (Get-AzContext).Subscription.Id
    $ExistingRule = Get-AzSentinelAutomationRule -ResourceGroupName $ResourceGroupName -WorkspaceName $WorkspaceName -Id $Id -IncludeEtag
    if($null -eq $ExistingRule) {
        [PSCustomObject]$body = @{
            id       = "/subscriptions/$($SubscriptionId)/resourcegroups/$($ResourceGroupName)/providers/microsoft.operationalinsights/workspaces/$($WorkspaceName)/providers/Microsoft.SecurityInsights/automationRules/$($Id)"
            name     = $Id
            type     = "Microsoft.SecurityInsights/AutomationRules"
            properties = [PSCustomObject] @{
                displayName = $DisplayName
                order = $Order
                triggeringLogic = @{
                    expirationTimeUtc = $Trigger.ExpirationTimeUtc
                    isEnabled = $Trigger.Enabled
                    triggersOn = $Trigger.TriggersOn
                    triggersWhen = $Trigger.TriggersWhen
                    conditions = $Trigger.Conditions
                }
                actions = [System.Collections.ArrayList]@()
            }
        }    
    }
    else {
        [PSCustomObject]$body = @{
            id       = "/subscriptions/$($SubscriptionId)/resourcegroups/$($ResourceGroupName)/providers/microsoft.operationalinsights/workspaces/$($WorkspaceName)/providers/Microsoft.SecurityInsights/automationRules/$($Id)"
            etag     = $ExistingRule.etag
            name     = $Id
            type     = "Microsoft.SecurityInsights/AutomationRules"
            properties = [PSCustomObject] @{
                displayName = $DisplayName
                order = $Order
                triggeringLogic = @{
                    expirationTimeUtc = $Trigger.ExpirationTimeUtc
                    isEnabled = $Trigger.Enabled
                    triggersOn = $Trigger.TriggersOn
                    triggersWhen = $Trigger.TriggersWhen
                    conditions = $Trigger.Conditions
                }
                actions = [System.Collections.ArrayList]@()
            }
        }
    }
    $body.properties.actions.AddRange($Actions)
    $Payload = ConvertTo-Json -InputObject $body -Depth 10
    $Response = Invoke-AzRestMethod -Path "/subscriptions/$($SubscriptionId)/resourcegroups/$($ResourceGroupName)/providers/microsoft.operationalinsights/workspaces/$($WorkspaceName)/providers/Microsoft.SecurityInsights/automationRules/$($Id)?api-version=2019-01-01-preview" -Payload $Payload -Method PUT 
    if(($Response.StatusCode -ne 200) -and ($Response.StatusCode -ne 201)) {
        throw $Response.Content
    }
}
  
  function Remove-AzSentinelAutomationRule {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [string]
        $ResourceGroupName,
        [Parameter(Mandatory = $true)]
        [string]
        $WorkspaceName,
        [Parameter(Mandatory = $true)]
        [string]
        $Id
    )
  
    $SubscriptionId = (Get-AzContext).Subscription.Id
    $Response = Invoke-AzRestMethod -Path "/subscriptions/$($SubscriptionId)/resourcegroups/$($ResourceGroupName)/providers/microsoft.operationalinsights/workspaces/$($WorkspaceName)/providers/Microsoft.SecurityInsights/automationRules/$($Id)?api-version=2019-01-01-preview" -Method DELETE
    if(($Response.StatusCode -eq 200) -or ($Response.StatusCode -eq 201)) {
      Write-Verbose "Succesfully Automation Rule Removed"
    }
    elseif($Response.StatusCode -eq 404) {
      Write-Warning "Automation Rule not Found"
    }
    else {
      throw $Response.Content
    }  
  }
  
  
  
function Export-AzSentinelAutomationRules{
[CmdletBinding()]
param (
    [Parameter(Mandatory = $true)]
    [string]
    $ResourceGroupName,
    [Parameter(Mandatory = $true)]
    [string]
    $WorkspaceName,
    [Parameter(Mandatory = $false)]
    [string]
    $Id,
    [Parameter(Mandatory = $true)]
    [string]
    $Path,
    [Parameter(Mandatory = $true)]
    [ValidateSet("Json", "Yaml")]
    [string]
    $Format
)

    if(-not (Test-Path -Path $Path)) {
        New-Item -Path $Path -ItemType Directory -Force | Out-Null
    }

    if(-not [string]::IsNullOrEmpty($Id)) {
        $Rule = Get-AzSentinelAutomationRule -ResourceGroupName $ResourceGroupName -WorkspaceName $WorkspaceName -Id $Id
        if($null -ne $Rule) {
            Write-Host "Exporting Automation Rule $($Rule.Name)"
            $Rule | Save-AzSentinelRule -Format $Format -Path $Path -Kind Automation
        }
        else {
            Write-Error "Rule Not Found"
        }
    }
    else {
        $Rules = Get-AzSentinelAutomationRule -ResourceGroupName $ResourceGroupName -WorkspaceName $WorkspaceName
        if($null -ne $Rules) {
            $Rules | ForEach-Object {
                Write-Host "Exporting Automation Rule $($_.Name)"
                $_ | Save-AzSentinelRule -Format $Format -Path $Path -Kind Automation
            }
        }
        else {
            Write-Warning "Rules not available"
        }
    }    
}
  
function Import-AzSentinelAutomationRules {
[CmdletBinding()]
param (
    [Parameter(Mandatory = $true)]
    [string]
    $ResourceGroupName,
    [Parameter(Mandatory = $true)]
    [string]
    $WorkspaceName,
    [Parameter(Mandatory = $true)]
    [string]
    $Path,
    [Parameter(Mandatory = $true)]
    [ValidateSet("Json","Yaml","All")]
    [string]
    $Format,
    [Parameter(Mandatory = $true)]
    [string]
    $SettingsFile
)

    $IncludeFiles = @()
    switch ($Format) {
        "Yaml" {
            $IncludeFiles += "*.automatic.rule.yaml"
        }
        "Json" {
            $IncludeFiles += "*.automatic.rule.json"
        }
        Default {
            $IncludeFiles += "*.automatic.rule.json"
            $IncludeFiles += "*.automatic.rule.yaml"
        }
    }
    
    $HasErrors = $false
    $Settings = Import-ContextSettings -SettingsFile $SettingsFile -AsHashtable
    $AlertDefinitions = Get-ChildItem -Path $Path -Include $IncludeFiles -Recurse -File
    $AlertDefinitions | ForEach-Object {
        $File = $_
        Write-Host ([string]::Empty)
        Write-Host "$($_.Name)" -ForegroundColor Blue
        Write-Host ([string]::Empty)
        try {
            $TransformedItem = Merge-ParametersSettings -Settings $Settings -File $File.FullName -PassThru
            if($File.Name.EndsWith(".yaml")) {
                $Definition = Get-Content -Path $TransformedItem.FullName -Raw | ConvertFrom-Yaml
            }
            if($File.Name.EndsWith(".json")) {
                $Definition = Get-Content -Path $TransformedItem.FullName -Raw | ConvertFrom-Json -Depth 2
            }

            if($null -ne $Definition) {            
                New-AzSentinelAutomationRule -ResourceGroup $ResourceGroupName -WorkspaceName $WorkspaceName -Rule $Definition
            }
            else {
                throw "Not supported file"
            }
        }
        catch {
            $ErrorActionPreference = 'Continue'
            $HasErrors = $true
            Write-Error $_
        }  
        finally
        {
            if($null -ne $TransformedItem) {
                Remove-Item -LiteralPath $TranformPSItem.FullName
            }
            $TranformPSItem = $null
        }
    }

    if($HasErrors){
        throw "Some Automation Rules cannot be Deployed"
    }
}