function New-AzSentinelWorkbook {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory)]
        [string]
        $ResourceGroupName,
        [Parameter(Mandatory)]
        [string]
        $Workspace,
        [Parameter(Mandatory)]
        [string]
        $MetadataFile,
        [Parameter(Mandatory)]
        [string]
        $MetadataParametersFile,
        [Parameter(Mandatory = $false)]
        [string]
        $TemplatePath = "$PSScriptRoot\Microsoft.Sentinel.Workbooks.template.json"
    )
    $Content = Get-Content -Raw -Path $MetadataFile
    $MetadataParameters = Get-Content -Raw -Path $MetadataParametersFile | ConvertFrom-Json
    $SentinelWorkspace = Get-AzOperationalInsightsWorkspace -Name $Workspace -ResourceGroupName $ResourceGroupName
    $Parameters = @{
        "workbookDisplayName" = $MetadataParameters.Name
        "workbookSourceId" = $SentinelWorkspace.ResourceId
        "workbookData" = $Content 
        "workbookId" = $MetadataParameters.WorkbookId
    }

    $DeploymentId = [guid]::NewGuid().ToString()
    New-AzResourceGroupDeployment -ResourceGroupName $ResourceGroupName -Name "Deployment-Workbook-$($MetadataParameters.Id)-$DeploymentId" -Mode Incremental -TemplateFile $TemplatePath -TemplateParameterObject $Parameters
}

function Remove-AzSentinelWorkbook {
    param (
        [Parameter(Mandatory = $true, ParameterSetName = "RemoveByName")]
        [Parameter(Mandatory = $true, ParameterSetName = "RemoveById")]
        [string]
        $ResourceGroupName,
        [Parameter(Mandatory = $true, ParameterSetName = "RemoveById")]
        [string]
        $Id,
        [Parameter(Mandatory = $true, ParameterSetName = "RemoveByName")]
        [string]
        $Name
    )
    
    if($null -eq $Name) {
        $Resource = Get-AzResource -ResourceType "microsoft.insights/workbooks" -ResourceGroupName $ResourceGroupName -Name $Id
    }
    else {
        $Resource = Get-AzResource -ResourceType "microsoft.insights/workbooks" -ResourceGroupName $ResourceGroupName -TagName "hidden-title" -TagValue $Name
    }

    if($null -ne $Resource) {
        Remove-AzResource -ResourceId $Resource.ResourceId
    }
    else {
        if($null -eq $Name) {
            throw "Resource not found for Resource Group '$ResourceGroup' and Id '$Id'"
        }
        else {
            throw "Resource not found for Resource Group '$ResourceGroup' and Name '$Name'"
        }
    }
}

function Import-AzSentinelWorkbook {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory)]
        [string]
        $ResourceGroupName,
        [Parameter(Mandatory)]
        [string]
        $Workspace,
        [Parameter(Mandatory)]
        [string]
        $Path
    )

    if((Test-Path -Path $Path)) {
        $Items = Get-ChildItem -Path $Path -Recurse -Filter "*.workbook.metadata.json"
        if($null -ne $Items) {
            $Items | ForEach-Object {
                $Parameters = Get-Item -Path $_.FullName.Replace(".workbook.metadata.json", ".workbook.metadata.parameters.json")
                New-AzSentinelWorkbook -ResourceGroupName $ResourceGroupName -Workspace $Workspace -MetadataFile $_.FullName -MetadataParametersFile $Parameters.FullName
            }
        }
    }
}

function Clear-AzSentinelWorkbook {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory)]
        [string]
        $ResourceGroupName,
        [Parameter(Mandatory)]
        [string]
        $Workspace,
        [Parameter(Mandatory)]
        [string]
        $Path
    )

    if((Test-Path -Path $Path)) {
        $Items = Get-ChildItem -Path $Path -Recurse -Filter "*.workbook.metadata.json"
        if($null -ne $Items) {
            $Items | ForEach-Object {
                Remove-AzSentinelWorkbook -ResourceGroupName $ResourceGroup -Name $Item.Name
            }
        }
    }
}