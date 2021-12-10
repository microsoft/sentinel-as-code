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
    $AutomationAccount,
    [Parameter(Mandatory = $true)]
    [string]
    $Path,
    [Parameter(Mandatory = $false)]
    [string]
    $EnvironmentTablesPath,
    [Parameter(Mandatory = $false)]
    [switch]
    $RestartState,
    [Parameter(Mandatory = $false)]
    [bool]
    $EncryptDefinition = $false,
    [Parameter(Mandatory = $false)]
    [string]
    $AzureDataExportConnectedSnapshot = "AzureDataExportConnectedSnapshot",
    [Parameter(Mandatory = $false)]
    [string]
    $AzureDataExportRuleTableDefinition = "AzureDataExportRuleTableDefinition",
    [Parameter(Mandatory = $false)]
    [string]
    $AzureDataExportSnapshot = "AzureDataExportSnapshot"
)

Import-AzureAutomationRunbook -Path $Path -AutomationAccount $AutomationAccount -ResourceGroupName $ResourceGroupName

$AzureDataExportConnectedSnapshotVariable = Get-AzAutomationVariable -ResourceGroupName $ResourceGroupName -AutomationAccountName $AutomationAccount -Name $AzureDataExportConnectedSnapshot -ErrorAction SilentlyContinue
if($null -eq $AzureDataExportConnectedSnapshotVariable -or $RestartState) {
    if($null -eq $AzureDataExportConnectedSnapshotVariable) {
        New-AzAutomationVariable -ResourceGroupName $ResourceGroupName -AutomationAccountName $AutomationAccount -Name $AzureDataExportConnectedSnapshot -Value "@{}" -Encrypted $false
    }
    else {
        Set-AzAutomationVariable -ResourceGroupName $ResourceGroupName -AutomationAccountName $AutomationAccount -Name $AzureDataExportConnectedSnapshot -Value "@{}" -Encrypted $false
    }
}

$AzureDataExportConnectedSnapshotVariable = Get-AzAutomationVariable -ResourceGroupName $ResourceGroupName -AutomationAccountName $AutomationAccount -Name $AzureDataExportSnapshot -ErrorAction SilentlyContinue
if($null -eq $AzureDataExportConnectedSnapshotVariable -or $RestartState) {
    if($null -eq $AzureDataExportConnectedSnapshotVariable) {
        New-AzAutomationVariable -ResourceGroupName $ResourceGroupName -AutomationAccountName $AutomationAccount -Name $AzureDataExportSnapshot -Value "@{}" -Encrypted $false
    }
    else {
        Set-AzAutomationVariable -ResourceGroupName $ResourceGroupName -AutomationAccountName $AutomationAccount -Name $AzureDataExportSnapshot -Value "@{}" -Encrypted $false
    }
}

if($null -ne $EnvironmentTablesPath) {
    $EnvironmentTableDefinition = Get-Content -Path $EnvironmentTablesPath -Raw
    $Builder = [System.Text.StringBuilder]::new($EnvironmentTableDefinition)
    Write-Output $Builder.ToString()
    $AzureDataExportRuleTableDefinitionVariable = Get-AzAutomationVariable -ResourceGroupName $ResourceGroupName -AutomationAccountName $AutomationAccount -Name $AzureDataExportRuleTableDefinition -ErrorAction SilentlyContinue
    if($null -eq $AzureDataExportRuleTableDefinitionVariable) {
        New-AzAutomationVariable -ResourceGroupName $ResourceGroupName -AutomationAccountName $AutomationAccount -Name $AzureDataExportRuleTableDefinition -Value $Builder.ToString() -Encrypted $EncryptDefinition
    }
    else {
        Set-AzAutomationVariable -ResourceGroupName $ResourceGroupName -AutomationAccountName $AutomationAccount -Name $AzureDataExportRuleTableDefinition -Value $Builder.ToString() -Encrypted $EncryptDefinition
    }
}

$Value = (Get-Date).AddHours(1).ToString("dddd MM/dd/yyyy HH:00")
New-AzAutomationSchedule -ResourceGroupName $ResourceGroupName -AutomationAccountName $AutomationAccount -Name "Azure Data Export Rule Schedule" -StartTime $Value -HourInterval 1 
$Parameters = @{
    "ResourceGroupName" = $ResourceGroupName
    "WorkspaceName" = $WorkspaceName
    "AutomationDefinitionVariable" = $AzureDataExportRuleTableDefinition
    "AutomationSnapshotVariable" = $AzureDataExportSnapshot
    "SubscriptionId" = (Get-AzContext).Subscription.Id
    "AutomationSnapshotConnectedVariable" = $AzureDataExportConnectedSnapshot
}
$RegisterScheduledRunbook = Get-AzAutomationScheduledRunbook -ResourceGroupName $ResourceGroupName -AutomationAccountName $AutomationAccount -ScheduleName "Azure Data Export Rule Schedule" -RunbookName "Azure Sentinel Data Export Rules" -ErrorAction SilentlyContinue
if($null -ne $RegisterScheduledRunbook) {
    Unregister-AzAutomationScheduledRunbook -JobScheduleId $RegisterScheduledRunbook.JobScheduleId -ResourceGroupName $ResourceGroupName -AutomationAccountName $AutomationAccount -Force
}
Register-AzAutomationScheduledRunbook -ResourceGroupName $ResourceGroupName -AutomationAccountName $AutomationAccount -RunbookName "Azure Sentinel Data Export Rules" -ScheduleName "Azure Data Export Rule Schedule" -Parameters $Parameters