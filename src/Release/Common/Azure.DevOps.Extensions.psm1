function Set-AzureDevOpsVariable {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true, Position = 0)]
        [string]
        [ValidateNotNullOrEmpty]
        $Name,
        [Parameter(Mandatory=$true, Position = 1)] 
        [ValidateSet("=")]
        [char]
        $Link,
        [Parameter(Mandatory = $true, Position = 2)]
        [object]
        [ValidateNotNullOrEmpty]
        $Value
    )

    Write-Host "##vso[task.setvariable variable=$($Name);issecret=false]$($Value)"
}

Set-Alias -Name dynamic -Value Set-AzureDevOpsVariable -Option ReadOnly