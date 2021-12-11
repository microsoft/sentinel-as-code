[CmdletBinding()]
param (
    [Parameter(Mandatory = $true)]
    [string]
    $AccountUserPrincipalName,
    [Parameter(Mandatory = $false)]
    [datetime]
    $StartDate = (Get-Date).AddDays(-1),
    [Parameter(Mandatory = $false)]
    [datetime]
    $EndDate = (Get-Date)
)

Get-PSSession | Remove-PSSession
$Credential = Get-Credential
Connect-IPPSSession -Credential $Credential

try {
    $SearchName = "Search for Compromised Account $($AccountUserPrincipalName) between $StartDate and $EndDate" 
    $OnlyMailsMatchQuery = "(sent>=`"$($StartDate)`" AND sent<`"$($EndDate)`") OR (received>=`"$($StartDate)`" AND received<`"$($EndDate)`")"
    $Locations = @($AccountUserPrincipalName)
    $Search = Get-ComplianceSearch -Identity $SearchName -ErrorAction SilentlyContinue
    if($null -ne $Search) {
        Stop-ComplianceSearch -Identity $SearchName -ErrorAction SilentlyContinue -Force    
        Remove-ComplianceSearch -Identity $SearchName -Confirm:$false -ErrorAction SilentlyContinue
    }

    New-ComplianceSearch -Name $SearchName -ExchangeLocation $Locations -ContentMatchQuery $OnlyMailsMatchQuery -Force -AllowNotFoundExchangeLocationsEnabled $true -ErrorAction Stop
    Start-ComplianceSearch -Identity $SearchName
}
finally {
    Get-PSSession | Remove-PSSession
}