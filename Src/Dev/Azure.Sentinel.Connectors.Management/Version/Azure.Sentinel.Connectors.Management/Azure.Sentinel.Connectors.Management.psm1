function Invoke-DataConnector {
[CmdletBinding()]
param (
    [Parameter(Mandatory = $true)]
    [string]
    $ResourceGroupName,
    [Parameter(Mandatory = $true)]
    [string]
    $Workspace,
    [Parameter(Mandatory = $true)]
    [ValidateSet("Enable", "Disable", "Update", "Check")]
    $Action,
    [Parameter(Mandatory = $true)]
    [string]
    $ConnectorsPath,
    [Parameter(Mandatory = $true)]
    [string]
    $ConnectorSettingsPath
)
    $ErrorActionPreference = 'Stop'

    Write-Verbose "Searching for Connectors on $ConnectorSettingsPath"
    $Connectors = Get-DataConnectors -Path $ConnectorSettingsPath
    if($null -ne $Connectors) {
        Write-Verbose "Connectors resolved. Resolving..."
        # First we need to load the Connector Modules
        $ConnectorModules = Get-ChildItem -LiteralPath $ConnectorsPath -Filter "*.psm1"
        $CodeModulesBuilder = [System.Text.StringBuilder]::new()
        $ConnectorModules | ForEach-Object {
            Write-Verbose "Resolving $($_.FullName)"
            [void]$CodeModulesBuilder.AppendLine("using module $($_.FullName)")
        }

        # Creating the Execution of de ScriptBlock
        $UsingScriptBlockCode = $CodeModulesBuilder.ToString()
        $HasError = $false
        $Connectors | ForEach-Object {
            try{
                $ErrorActionPreference = 'Continue'
                $CodeBuilder = [System.Text.StringBuilder]::new()
                [void]$CodeBuilder.Append($UsingScriptBlockCode)
                [void]$CodeBuilder.AppendLine("return [$($_)DataConnector]::new()")
                $ConnectorNewCommand =  [scriptblock]::Create($CodeBuilder)
                $Connector = Invoke-Command -ScriptBlock $ConnectorNewCommand
                if($null -ne $Connector) {
                    Write-Host "Invoking Connector [$_] with the following settings:"
                    Write-Host "   Resource Group: $($ResourceGroupName)"
                    Write-Host "   Workspace: $($Workspace)"
                    Write-Host "   Action: $($Action)"
                    $Parameters = Get-DataConnectorSettings -ConnectorName $_ -Path $ConnectorSettingsPath
                    if($null -ne $Parameters) {
                        $Parameters.GetEnumerator() | ForEach-Object {
                            $Key = $_.Key
                            $Value = $_.Value
                            if($Value -is [array]) {
                                Write-Host "   $($Key):"
                                $_.Value.GetEnumerator() | ForEach-Object {
                                    if($_ -is [hashtable]){
                                        $_.GetEnumerator() | ForEach-Object {
                                            Write-Host "           $($_.Key): $($_.Value)"
                                        }
                                    }
                                    elseif($_ -is [array]){
                                        $_.GetEnumerator() | ForEach-Object {
                                            Write-Host "           $($_)"
                                        }
                                    }
                                }
                            }
                            else {
                                Write-Host "   $($Key): $($Value)"
                            }
                        }
                    }
                    $Connector.Invoke($ResourceGroupName, $Workspace, $Action, $Parameters)
                }
                else {
                    throw "Connector $($_) cannot be resolver to be used with Settings"
                }
            }
            catch{
                Write-Error $_
                if($VerbosePreference -ne 'SilentlyContinue') {
                    Write-Output $_.Exception
                }
                $HasError = $true
            }
        }

        if($true -eq $HasError) {
            throw "At least one connector raise an error"
        }
    }
    else {
        Write-Warning "Connector Settings not available for the Location $ConnectorSettingsPath"
    }
}

enum ConnectorAction{
    Enable
    Disable
    Update
    Check
}

function Get-DataConnectors{
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [string]
        $Path
    )

    if((Test-Path -Path $Path)){
        return Get-ChildItem -Path $Path -Filter "*.settings.json" | Select-Object -ExpandProperty Name | ForEach-Object { $_.Replace(".settings.json", [string]::Empty) }
    }
    else {
        Write-Warning "Settings not available for Connectors in Path $($Path)"
        return $null
    }
}

function Get-DataConnectorSettings{
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [string]
        $ConnectorName,
        [Parameter(Mandatory = $true)]
        [string]
        $Path
    )

    $FullName = Join-Path -Path $Path -ChildPath "$($ConnectorName).settings.json"
    if((Test-Path -Path $FullName)){
        return Get-Content -Path $FullName -Raw | ConvertFrom-Json -AsHashtable
    }
    else {
        Write-Warning "Settings not available for Connector $($ConnectorName) in Path $($Path)"
        return $null
    }
}

function Get-ConnectorAction {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [ValidateSet("Enable", "Disable", "Update", "Check")]
        [string]
        $Action
    )    

    switch ($Action) {
        "Enable" {  
            return [ConnectorAction]::Enable
        }
        "Disable" {  
            return [ConnectorAction]::Disable
        }
        "Update" {  
            return [ConnectorAction]::Update
        }
        "Check" {  
            return [ConnectorAction]::Check
        }
        Default {
            throw "Not Supported"
        }
    }
}

#
# Connector Class Template
#
class DataConnector {

    DataConnector() {
        
    }

    #
    #  Invoke Method Signature 
    #
    [void] Invoke ([string]$ResourceGroup, [string]$Workspace, [ConnectorAction] $Action, [Hashtable] $Parameters) {
        throw "Not Implemented Method in Abstract class"
    }
}