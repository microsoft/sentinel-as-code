Set-Variable -Name "DefaultWatchlistApiVersion" -Value "2019-01-01-preview" -Option Constant -ErrorAction SilentlyContinue
function Get-AzSentinelWatchlist {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true, ParameterSetName = "Name")]
        [Parameter(Mandatory = $true, ParameterSetName = "All")]
        [string]
        $ResourceGroupName,
        [Parameter(Mandatory = $true, ParameterSetName = "Name")]
        [Parameter(Mandatory = $true, ParameterSetName = "All")]
        [string]
        $WorkspaceName,
        [Parameter(Mandatory = $true, ParameterSetName = "Name")]
        [string]
        $Name,
        [Parameter(Mandatory = $true, ParameterSetName = "All")]
        [switch]
        $All,
        [Parameter(Mandatory = $false)]
        [string]
        $ApiVersion = $DefaultWatchlistApiVersion
    )

    $AzContext = Get-AzContext
    if($null -eq $AzContext) {
        throw "Az Context not initialized. Requires Connect-AzAccount"
    }

    $Subscription = $AzContext.Subscription
    if($null -eq $Subscription) {
        throw "Az Context not initialized for a Subscription. Requires Connect-AzAccount with Suscription parameter"
    }
    
    $SubscriptionId = $Subscription.Id
    if($All -eq $true) {
        $RequestUrl = "/subscriptions/$($SubscriptionId)/resourceGroups/$($ResourceGroupName)/providers/Microsoft.OperationalInsights/workspaces/$($WorkspaceName)/providers/Microsoft.SecurityInsights/watchlists?api-version=$($ApiVersion)"
        $Response = Invoke-AzRestMethod -Path $RequestUrl -Method GET
        $Watchlist = $Response.Content
        if($Response.StatusCode -eq 200) {
            if(-not [string]::IsNullOrEmpty($Watchlist)) {
                $JsonObject = $Watchlist | ConvertFrom-Json
                $ArrayOfWatchlists = $JsonObject.value | ForEach-Object {
                    return [PSCustomObject]@{
                        Name = $_.name
                        DisplayName = $_.properties.displayName
                        Provider = $_.properties.provider 
                        Id = $_.properties.watchlistId
                    }
                }
                return $ArrayOfWatchlists
            }
        }
        elseif($Response.StatusCode -eq 404) {
            return $null
        } 
        else {
            throw $Response.Content
        } 
    }
    else {
        $RequestUrl = "/subscriptions/$($SubscriptionId)/resourceGroups/$($ResourceGroupName)/providers/Microsoft.OperationalInsights/workspaces/$($WorkspaceName)/providers/Microsoft.SecurityInsights/watchlists/$($Name)?api-version=$($ApiVersion)"
        $Response = Invoke-AzRestMethod -Path $RequestUrl -Method GET
        if($Response.StatusCode -eq 200) {
            $Watchlist = $Response.Content
            if(-not [string]::IsNullOrEmpty($Watchlist)) {
                $JsonObject = $Watchlist | ConvertFrom-Json
                return [PSCustomObject]@{
                    Name = $JsonObject.name
                    DisplayName = $JsonObject.properties.displayName
                    Provider = $JsonObject.properties.provider 
                    Id = $JsonObject.properties.watchlistId
                }
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

function New-AzSentinelWatchlist {
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
        $Name,
        [Parameter(Mandatory = $false)]
        [string]
        $Alias = $Name,
        [Parameter(Mandatory = $false)]
        [string]
        $Description = "",
        [Parameter(Mandatory = $true)]
        [string]
        $Path,
        [Parameter(Mandatory = $true)]
        [string]
        $Provider,
        [Parameter(Mandatory = $false)]
        [string]
        $ApiVersion = $DefaultWatchlistApiVersion
    )

    if((Test-Path -Path $Path)) {
        $FileItem = Get-Item -Path $Path
        $AzContext = Get-AzContext
        if($null -eq $AzContext) {
            throw "Az Context not initialized. Requires Connect-AzAccount"
        }

        $Subscription = $AzContext.Subscription
        if($null -eq $Subscription) {
            throw "Az Context not initialized for a Subscription. Requires Connect-AzAccount with Suscription parameter"
        }
        
        $SubscriptionId = $Subscription.Id
        $rawContent = Get-Content -Path $Path -Raw
        $RequestUrl = "/subscriptions/$($SubscriptionId)/resourceGroups/$($ResourceGroupName)/providers/Microsoft.OperationalInsights/workspaces/$($WorkspaceName)/providers/Microsoft.SecurityInsights/watchlists/$($Alias)?api-version=$($ApiVersion)"
        $Payload = [PSCustomObject]@{
            properties = @{
                "displayName" = $Name
                "watchlistAlias" = $Alias
                "description" = $Description
                "source" = $FileItem.Name
                "provider" = $Provider
                "numberOfLinesToSkip" = 0
                "rawContent" = $rawContent.ToString()
                "contentType" = "text/csv"
            }
        }
        $PayloadAsString = $Payload | ConvertTo-Json
        $Response = Invoke-AzRestMethod -Path $RequestUrl -Payload $PayloadAsString -Method PUT
        if($Response.StatusCode -eq 200) {
            $Response = Invoke-AzRestMethod -Path $RequestUrl -Payload $PayloadAsString -Method PUT
            if($Response.StatusCode -ne 200) {
                throw $Response.Content
            }
        }
        else {
            throw $Response.Content
        }
    }
    else {
        throw "File for Watchlist definition $Path does not exists"
    }
}

function Remove-AzSentinelWatchlist {
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
        $Name,
        [Parameter(Mandatory = $false)]
        [string]
        $ApiVersion = $DefaultWatchlistApiVersion
    )
    $AzContext = Get-AzContext
    if($null -eq $AzContext) {
        throw "Az Context not initialized. Requires Connect-AzAccount"
    }

    $Subscription = $AzContext.Subscription
    if($null -eq $Subscription) {
        throw "Az Context not initialized for a Subscription. Requires Connect-AzAccount with Suscription parameter"
    }
    
    $SubscriptionId = $Subscription.Id
    $RequestUrl = "/subscriptions/$($SubscriptionId)/resourceGroups/$($ResourceGroupName)/providers/Microsoft.OperationalInsights/workspaces/$($WorkspaceName)/providers/Microsoft.SecurityInsights/watchlists/$($Name)?api-version=$($ApiVersion)"
    $Response = Invoke-AzRestMethod -Path $RequestUrl -Method DELETE
    if($Response.StatusCode -ne 200) {
        throw $Response.Content
    }
    Start-Sleep -Seconds 60
}

function Import-AzSentinelWatchlists {
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
        $Path
    )

    if((Test-Path -Path $Path)) {
        $Items = Get-ChildItem -Path $Path -Filter "*.watchlist.metadata.json" -Recurse -File
        if($null -ne $Items) {
            $HasErrors = $false
            $Items | ForEach-Object {
                try {
                    $Item = $_
                    Write-Host "Processing Watchlist: $($Item.Name)"
                    $JsonObject = $Item | Get-Content -Raw | ConvertFrom-Json
                    $WatchlistName = $JsonObject.Name
                    $WatchlistAlias = $JsonObject.Name
                    $WatchlistProvider = $JsonObject.Provider
                    $WatchlistDescription = $JsonObject.Description
                    $WatchlistSource = Join-Path -Path $Item.DirectoryName -ChildPath $JsonObject.Source
                    $Watchlist = Get-AzSentinelWatchlist -ResourceGroupName $ResourceGroupName -WorkspaceName $WorkspaceName -Name $JsonObject.Name
                    if($null -ne $Watchlist) {
                        Remove-AzSentinelWatchlist -ResourceGroupName $ResourceGroupName -WorkspaceName $WorkspaceName -Name $WatchlistName
                        Start-Sleep -Seconds 60
                    }
                    
                    New-AzSentinelWatchlist -ResourceGroupName $ResourceGroupName -WorkspaceName $WorkspaceName -Name $WatchlistName -Path $WatchlistSource -Description $WatchlistDescription -Provider $WatchlistProvider -Alias $WatchlistAlias
                }
                catch {
                    $ErrorActionPreference = "Continue"
                    $HasErrors = $true
                    Write-Error "Error Processing Watchlist $($Item.FullName)"
                    Write-Error $_
                }
            }

            if($HasErrors) {
                throw "Some Watchlists cannot be deployed"
            }
        }
        else {
            Write-Host "No Manifest files found for Watchlist"
        }
    }
    else {
        throw "Invalid Path $Path specified"
    }
}

function Clear-AzSentinelWatchlists {
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
        $Path
    )

    if((Test-Path -Path $Path)) {
        $Items = Get-ChildItem -Filter "*.watchlist.metadata.json" -Recurse -File
        if($null -ne $Items) {
            $HasErrors = $false
            $Items | ForEach-Object {
                try {
                    $Item = $_
                    $JsonObject = $Item | Get-Content -Raw | ConvertFrom-Json
                    $WatchlistName = $JsonObject.Name
                    $Watchlist = Get-AzSentinelWatchlist -ResourceGroupName $ResourceGroupName -WorkspaceName $WorkspaceName -Name $JsonObject.Name
                    if($null -ne $Watchlist) {
                        Remove-AzSentinelWatchlist -ResourceGroupName $ResourceGroupName -WorkspaceName $WorkspaceName -Name $WatchlistName
                    }
                }
                catch {
                    $ErrorActionPreference = "Continue"
                    $HasErrors = $true
                    Write-Error "Error Processing Watchlist $($Item.FullName)"
                    Write-Error $_
                }
            }

            if($HasErrors) {
                throw "Some Watchlists cannot be removed"
            }
        }
        else {
            Write-Host "No Manifest files found for Watchlist"
        }
    }
    else {
        throw "Invalid Path $Path specified"
    }
}