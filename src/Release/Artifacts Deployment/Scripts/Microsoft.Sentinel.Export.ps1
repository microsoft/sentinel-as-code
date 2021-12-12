[CmdletBinding()]
param (
    [Parameter(Mandatory = $true)]
    [string]
    $WorkspaceName,
    [Parameter(Mandatory = $true)]
    [string]
    $ResourceGroupName,
    [Parameter(Mandatory = $true)]
    [string]
    $AutomationAccountName,
    [Parameter(Mandatory = $true)]
    [string]
    $Path,
    [Parameter(Mandatory = $true)]
    [ValidateSet("Json", "Yaml")]
    [string]
    $Format,
    [Parameter(Mandatory = $false)]
    [switch]
    $ClearBeforeIfExists
)

if(($ClearBeforeIfExists -eq $true) -and (Test-Path -Path $Path)) {
    Remove-Item -Path $Path -Recurse -Force
}

Write-Host "Exporting Runbooks"
$RunbooksPath = Join-Path -Path $Path -ChildPath "Runbooks"
Export-AzureAutomationRunbook -ResourceGroupName $ResourceGroupName -AutomationAccountName $AutomationAccountName -Path $RunbooksPath
Write-Host "Exporting Connections"
$PlaybookConnectionsPath = Join-Path -Path $Path -ChildPath "Connections"
Export-AzSentinelPlaybookConnections -ResourceGroupName $ResourceGroupName -Path $PlaybookConnectionsPath
Write-Host "Exporting Playbooks"
$PlaybooksPath = Join-Path -Path $Path -ChildPath "Playbooks"
Export-AzSentinelPlaybook -ResourceGroupName $ResourceGroupName -Path $PlaybooksPath
Write-Host "Exporting Hunting Rules"
$HuntingRulesPath = Join-Path -Path $Path -ChildPath "HuntingRules"
Export-AzSentinelHuntingRules  -ResourceGroupName $ResourceGroupName -WorkspaceName $WorkspaceName -Path $HuntingRulesPath -Format $Format
Write-Host "Exporting Analytics Rules"
$AnalyticsRulesPath = Join-Path -Path $Path -ChildPath "AnalyticsRules"
Export-AzSentinelAnalyticsRules  -ResourceGroupName $ResourceGroupName -WorkspaceName $WorkspaceName -Path $AnalyticsRulesPath -Format $Format
Write-Host "Exporting Alert & Playbooks Connections"
$AlertAndPlaybooksConnectionsPath = Join-Path -Path $Path -ChildPath "AlertAndPlaybooksConnections"
Export-AzPlaybookAndRuleConnections -ResourceGroupName $ResourceGroupName -WorkspaceName $WorkspaceName -Path $AlertAndPlaybooksConnectionsPath -Format $Format
Write-Host "Exporting Automation Rules"
$AutomationRulesPath = Join-Path -Path $Path -ChildPath "AutomationRules"
Export-AzSentinelAutomationRules  -ResourceGroupName $ResourceGroupName -WorkspaceName $WorkspaceName -Path $AutomationRulesPath -Format $Format