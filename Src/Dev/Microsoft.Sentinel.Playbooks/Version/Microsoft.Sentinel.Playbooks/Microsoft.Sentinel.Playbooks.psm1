function Invoke-AzSentinelPlaybookDeployment {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true, ParameterSetName = "ImportWithSettingsFile")]
        [Parameter(Mandatory = $true, ParameterSetName = "ImportWithSettings")]
        [Parameter(Mandatory = $true, ParameterSetName = "ImportWithOutSettings")]
        [string]
        $ResourceGroupName,
        [Parameter(Mandatory = $true, ParameterSetName = "ImportWithSettingsFile")]
        [Parameter(Mandatory = $true, ParameterSetName = "ImportWithSettings")]
        [Parameter(Mandatory = $true, ParameterSetName = "ImportWithOutSettings")]
        [string]
        $PlaybookFile,
        [Parameter(Mandatory = $true, ParameterSetName = "ImportWithSettings")]
        [hashtable]
        $Parameters,
        [Parameter(Mandatory = $true, ParameterSetName = "ImportWithSettingsFile")]
        [string]
        $ParametersFile,
        [Parameter(Mandatory = $true, ParameterSetName = "ImportWithOutSettings")]
        [switch]
        $NoSettings
    )

    $PlaybookFileExists = Test-Path -LiteralPath $PlaybookFile
    if($PlaybookFileExists) 
    {
        if(-not [string]::IsNullOrEmpty($ParametersFile)) {
            $ParametersFileExists = Test-Path -LiteralPath $ParametersFile
            if($ParametersFileExists) {
                New-AzResourceGroupDeployment -ResourceGroupName $ResourceGroupName -TemplateFile $PlaybookFile -TemplateParameterFile $ParametersFile -Mode Incremental
            }
            else {
                throw "Settings File not exists"
            }
        }
        elseif($null -ne $Parameters) {
            New-AzResourceGroupDeployment -ResourceGroupName $ResourceGroupName -TemplateFile $PlaybookFile -TemplateParameterObject $Parameters -Mode Incremental
        }
        elseif($NoSettings) {
            New-AzResourceGroupDeployment -ResourceGroupName $ResourceGroupName -TemplateFile $PlaybookFile -Mode Incremental
        }
        else {
            throw "Invalid Parameters"
        }
    }
}

function Import-AzSentinelPlaybooks {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [string]
        $Path,
        [Parameter(Mandatory = $true)]
        [string]
        $SettingsFile
    )

    $PathExists = Test-Path -Path $Path
    if($PathExists) {
        $Settings = Import-ContextSettings -SettingsFile $SettingsFile -AsHashtable
        $ResourceGroupName = $Settings.ResourceGroup.Name
        $Items = Get-ChildItem -Path $Path -Filter "Playbooks" -Recurse -Directory
        $HasErrors = $false
        $Items | ForEach-Object {
            $CurrentPlaybookDirectory = $_
            try {
                $ArmItems = $CurrentPlaybookDirectory | Get-ChildItem -Include "*.json" -Exclude "*.parameters.json" -File 
                $ArmItems | ForEach-Object {
                    $ArmItem = $_
                    $ParameterFilePath = Join-Path -Path $CurrentPlaybookDirectory -ChildPath $ArmItem.Name.Replace(".json", ".parameters.json")
                    if(-not (Test-Path -Path $ParameterFilePath)) {
                        $TranformPSItem = Merge-ParametersSettings -Settings $Settings -File $ParameterFilePath -PassThru -NameTemplate $ArmItem.Name 
                        Write-Host ([string]::Empty)
                        Write-Host "$($ArmItem.Name) without parameters file" -ForegroundColor Blue
                        Write-Host ([string]::Empty)
                        Invoke-AzSentinelPlaybookDeployment -ResourceGroupName $ResourceGroupName -PlaybookFile $TranformPSItem.FullName -NoSettings 
                    }
                    else {
                        $TranformPSItem = Merge-ParametersSettings -Settings $Settings -File $ParameterFilePath -PassThru
                        Write-Host ([string]::Empty)
                        Write-Host "$($ArmItem.Name) with parameters file $($TranformPSItem.Name)" -ForegroundColor Blue
                        Write-Host ([string]::Empty)
                        Invoke-AzSentinelPlaybookDeployment -ResourceGroupName $ResourceGroupName -PlaybookFile $ArmItem.FullName -ParametersFile $TranformPSItem.FullName 
                    }
                }
            }
            catch {
                $ErrorActionPreference = 'Continue'
                $HasErrors = $true
                Write-Error $_
            }
            finally{
                if($null -ne $TranformPSItem) {
                    Remove-Item -LiteralPath $TranformPSItem.FullName
                }

                $TranformPSItem = $null
            }
        }

        if($HasErrors){
            throw "Some Playbooks cannot be Deployed"
        }
    }
}

function Export-AzSentinelPlaybook {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [string]
        $ResourceGroupName,
        [Parameter(Mandatory = $false)]
        [string]
        $PlaybookName,
        [Parameter(Mandatory = $true)]
        [string]
        $Path
    )

    if(-not (Test-Path -Path $Path)) {
        New-Item -Path $Path -ItemType Directory -Force | Out-Null
    }

    if([string]::IsNullOrEmpty($PlaybookName)) {
        $Playbooks = Get-AzResource -ResourceGroup $ResourceGroupName -ResourceType "Microsoft.Logic/workflows"
    }
    else {
        $Playbooks = Get-AzResource -ResourceGroup $ResourceGroupName -ResourceType "Microsoft.Logic/workflows" -Name $PlaybookName
    }

    if($null -ne $Playbooks) {
        if(-not [string]::IsNullOrEmpty($PlaybookName)) {
            Write-Host "Exporting Playbook $($Playbooks.Name)"
            $OutputFilePath = Join-Path -Path $Path -ChildPath $Playbooks.Name
            Export-AzResourceGroup -ResourceGroupName $ResourceGroupName -Path $OutputFilePath -IncludeParameterDefaultValue -IncludeComments -Resource $Playbooks.ResourceId -Force | Out-Null
        }
        else {
            $Playbooks | ForEach-Object {
                Write-Host "Exporting Playbook $($_.Name)"
                $OutputFilePath = Join-Path -Path $Path -ChildPath "$($_.Name).json"
                Export-AzResourceGroup -ResourceGroupName $ResourceGroupName -Path $OutputFilePath -IncludeParameterDefaultValue -IncludeComments -Resource $_.ResourceId -Force | Out-Null
            }
        }
    }
    else {
        Write-Warning "Not detected playbooks in Resource Group $($ResourceGroupName)"
    }
}

function Export-AzSentinelPlaybookConnections {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [string]
        $ResourceGroupName,
        $PlaybookName,
        [Parameter(Mandatory = $true)]
        [string]
        $Path
    )

    if(-not (Test-Path -Path $Path)) {
        New-Item -Path $Path -ItemType Directory -Force | Out-Null
    }

    $Connections = Get-AzResource -ResourceGroup $ResourceGroupName -ResourceType "Microsoft.Web/connections" -ExpandProperties
    
    if($null -ne $Connections) {
        $Connections | ForEach-Object {
            $Properties = $_.Properties
            if($null -ne $Properties) {
                $Api = $Properties.api
                if(($Api.name -ne "keyvault") -and ($Api.name -ne "azureautomation") -and ($Api.name -ne "azuresentinel")) {
                    Write-Host "Exporting Connection $($_.Name)"
                    $OutputFilePath = Join-Path -Path $Path -ChildPath "$($_.Name).json"
                    Export-AzResourceGroup -ResourceGroupName $ResourceGroupName -Path $OutputFilePath -IncludeParameterDefaultValue -IncludeComments -Resource $_.ResourceId -Force | Out-Null
                }
                else {
                    Write-Warning "Skipping Connection $($_.Name) because is a Default Infrastructure connection"
                }
            }
            else {
                Write-Warning "Skipping Connection $($_.Name) because Property Definition is not available"
            }
        }
    }
    else {
        Write-Warning "Not detected playbooks in Resource Group $($ResourceGroupName)"
    }
}