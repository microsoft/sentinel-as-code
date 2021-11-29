function Deploy-AzAutomationRunbook{
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [string]
        $Path,
        [Parameter(Mandatory = $true)]
        [string]
        $SettingsFile
    )
    $Settings = Import-ContextSettings -SettingsFile $SettingsFile -AsHashtable
    $ResourceGroupName = $Settings.ResourceGroup.Name
    $AutomationAccountName = $Settings.Automation.Name
    $PathExists = Test-Path -Path $Path
    if($PathExists) {
        $Items = Get-ChildItem -Path $Path -Filter "Runbooks" -Recurse -Directory
        $Items | ForEach-Object {
            $CurrentPlaybookDirectory = $_
            try {
                Import-AzureAutomationRunbook -Path $CurrentPlaybookDirectory `
                                                -ResourceGroupName $ResourceGroupName `
                                                -AutomationAccountName $AutomationAccountName
            }
            catch
            { 
                $ErrorActionPreference = 'Continue'
                Write-Error $_
            }
        }
    }
}
function Import-AzureAutomationRunbook {
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
        $AutomationAccountName
    )

    #PowerShell, GraphicalPowerShell, PowerShellWorkflow, GraphicalPowerShellWorkflow, Graph, Python2, Python3
    $RunbookPathExists = Test-Path -Path $Path
    if($RunbookPathExists) {
        $RunbookPSItems = Get-ChildItem -Include "*.ps1", "*.psd1" -File -Path $Path -Recurse
        if($null -ne $RunbookPSItems) {
            $ShouldBeArray = $RunbookPSItems -is [Array]
            $ShouldBeTwoOrThreeItems = $RunbookPSItems.Length -eq 2
            if($ShouldBeArray -and $ShouldBeTwoOrThreeItems) {
                $ManifestFile = $RunbookPSItems | Where-Object {$_.Name.EndsWith(".psd1")} 
                if($null -eq $ManifestFile) {
                    throw "A Runboook manifest File with extension .psd1 must be included"
                }
                $PowershellScriptFile = $RunbookPSItems | Where-Object {$_.Name.EndsWith(".ps1")}     
                if($null -eq $PowershellScriptFile) {
                    throw "A Runbook Powershell Script File with extension .ps1 must be included"
                }
                
                $Manifest = Import-PowerShellDataFile -LiteralPath $ManifestFile.FullName
                $Modules = $Manifest.Modules
                if($null -ne $Modules -and $Modules -is [Hashtable]) {
                    $PowershellGalleryBaseUrl = "https://www.powershellgallery.com/api/v2/package/"
                    $Modules.GetEnumerator() | ForEach-Object {
                        $Module = Get-AzAutomationModule -ResourceGroupName $ResourceGroupName `
                                                -AutomationAccountName $AutomationAccountName `
                                                -Name $_.Key -ErrorAction SilentlyContinue
                        if($null -ne $Module) {
                            $ModuleVersion = [Version]$Module.Version
                            $RequiredModuleVersion = [Version]$_.Value
                            if($ModuleVersion -lt $RequiredModuleVersion) {
                                Import-AzAutomationModule -ResourceGroupName $ResourceGroupName `
                                                 -AutomationAccountName $AutomationAccountName `
                                                 -Name $_.Key `
                                                 -ContentLinkUri "$($PowershellGalleryBaseUrl)/$($_.Key)/$($_.Value)" 
                                do {
                                    Start-Sleep -Milliseconds 1000
                                    $Module = Get-AzAutomationModule -ResourceGroupName $ResourceGroupName `
                                                        -AutomationAccountName $AutomationAccountName `
                                                        -Name $_.Key -ErrorAction SilentlyContinue
                                }
                                until(($null -eq $Module) -or ($Module.ProvisioningState -eq "Succeeded") -or ($Module.ProvisioningState -eq "Failed"))
                                if($Module.ProvisioningState -ne "Succeeded") {
                                    throw "Module $($Module) with Requested Version $($_.Value) not completed. Status $($Module.ProvisioningState)"
                                }
                            }
                        }
                        else {
                            Import-AzAutomationModule -ResourceGroupName $ResourceGroupName `
                                                 -AutomationAccountName $AutomationAccountName `
                                                 -Name $_.Key `
                                                 -ContentLinkUri "$($PowershellGalleryBaseUrl)/$($_.Key)/$($_.Value)" 
                            do {
                                Start-Sleep -Milliseconds 1000
                                $Module = Get-AzAutomationModule -ResourceGroupName $ResourceGroupName `
                                                    -AutomationAccountName $AutomationAccountName `
                                                    -Name $_.Key -ErrorAction SilentlyContinue
                            }
                            until(($null -eq $Module) -or ($Module.ProvisioningState -eq "Succeeded") -or ($Module.ProvisioningState -eq "Failed"))
                            if($Module.ProvisioningState -ne "Succeeded") {
                                throw "Module $($Module) with Requested Version $($_.Value) not completed. Status $($Module.ProvisioningState)"
                            }
                        }
                    }
                }

                $AutomationRunbook = Get-AzAutomationRunbook -ResourceGroupName $ResourceGroupName `
                                        -AutomationAccountName $AutomationAccountName `
                                        -Name $Manifest.Name `
                                        -ErrorAction SilentlyContinue
                if($null -ne $AutomationRunbook){
                    Remove-AzAutomationRunbook  -ResourceGroupName $ResourceGroupName `
                                                -AutomationAccountName $AutomationAccountName `
                                                -Name $Manifest.Name `
                                                -Force
                }
                                        
                Import-AzAutomationRunbook -Path $PowershellScriptFile.FullName `
                                            -ResourceGroupName $ResourceGroupName `
                                            -AutomationAccountName $AutomationAccountName `
                                            -Name $Manifest.Name `
                                            -Type $Manifest.Type `
                                            -Description $Manifest.Description `
                                            -Published
            }
        }
        else {
            throw "Runbooks elements in folder $($Path) not include Manifest and Script"
        }
    }
    else {
        throw "Runbook deployment $($Path) is empty"
    }
}

function Export-AzureAutomationRunbook {
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
        $AutomationAccountName,
        [Parameter(Mandatory = $false)]
        [string]
        $RunbookName,
        [Parameter(Mandatory = $false)]
        [ValidateSet("Draft", "Published")]
        [string]
        $Slot = "Published"
    )

    if(-not (Test-Path -Path $Path)) {
        New-Item -Path $Path -ItemType Directory -Force | Out-Null
    }

    $ModulesNotGlobal = Get-AzAutomationModule -ResourceGroupName $ResourceGroupName -AutomationAccountName $AutomationAccountName | Where-Object {$_.IsGlobal -eq $false}
    $ManifestModules = @{}
    $ModulesNotGlobal | ForEach-Object {
        $ManifestModules.Add($_.Name, $_.Version)
    }
    if(-not [string]::IsNullOrEmpty($RunbookName)) {
        $Runbook = Get-AzAutomationRunbook -ResourceGroupName $ResourceGroupName -AutomationAccountName $AutomationAccountName -Name $RunbookName -ErrorAction SilentlyContinue
        if($null -ne $Runbook) {
            $FileName = Join-Path -Path $Path -ChildPath "$($Runbook.Name).psd1"
            New-AzRunbookManifest -Name $Runbook.Name -Description $Runbook.Description -Type $Runbook.RunbookType -Modules $ManifestModules -FileName $FileName
            Export-AzAutomationRunbook -ResourceGroupName $ResourceGroupName -AutomationAccountName $AutomationAccountName -OutputFolder $Path -Slot $Slot -Name $RunbookName
        }
        else {
            Write-Error "Runbook $($RunbookName) not exists"
        }
    }
    else {
        $Runbooks = Get-AzAutomationRunbook -ResourceGroupName $ResourceGroupName -AutomationAccountName $AutomationAccountName
        if($null -ne $Runbooks) {
            $Runbooks | ForEach-Object {
                switch ($_.State) {
                    default {
                        $Slot = "Draft"
                    }
                    "Published" {
                        $Slot = "Published"
                    }
                }
                $FileName = Join-Path -Path $Path -ChildPath "$($_.Name).psd1"
                New-AzRunbookManifest -Name $_.Name -Description $_.Description -Type $_.RunbookType -Modules $ManifestModules -FileName $FileName
                Export-AzAutomationRunbook -ResourceGroupName $ResourceGroupName -AutomationAccountName $AutomationAccountName -OutputFolder $Path -Slot $Slot -Name $_.Name
            }
        }
    }
}

function New-AzRunbookManifest {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [string]
        $Name,
        [Parameter(Mandatory = $false)]
        [string]
        $Description,
        [Parameter(Mandatory = $true)]
        [ValidateSet("PowerShell","GraphPowerShell","PowerShellWorkflow","GraphPowerShellWorkflow","Python2","Python3")]
        [string]
        $Type,
        [Parameter(Mandatory = $false)]
        [hashtable]
        $Modules,
        [Parameter(Mandatory = $true)]
        [string]
        $FileName
    )

    if($null -eq $Modules) {
        $Manifest = @{
            Name = $Name
            Description = $Description
            Type = $Type
        }
    }
    else {
        $Manifest = @{
            Name = $Name
            Description = $Description
            Type = $Type
            Modules = $Modules
        }
    }
    
    $ManifestAsString = $Manifest | ConvertTo-Json -Depth 3
    $ManifestBuilder = [System.Text.StringBuilder]::new($ManifestAsString)
    [void]$ManifestBuilder.Replace("{", "@{")
    [void]$ManifestBuilder.Replace(":", " =")
    [void]$ManifestBuilder.Replace("`"Name`"", "Name")
    [void]$ManifestBuilder.Replace("`"Description`"", "Description")
    [void]$ManifestBuilder.Replace("`"Type`"", "Type")
    [void]$ManifestBuilder.Replace("`"Modules`"", "Modules")
    $ManifestBuilder.ToString() | Out-File -FilePath $FileName
}