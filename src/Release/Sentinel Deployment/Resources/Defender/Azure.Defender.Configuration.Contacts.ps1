[CmdletBinding()]
param (
    [Parameter(Mandatory = $true)]
    [string]
    $Name,
    [Parameter(Mandatory = $false)]
    [switch]
    $AlertAdmin,
    [Parameter(Mandatory = $false)]
    [switch]
    $NotifyOnAlert,
    [Parameter(Mandatory = $false)]
    [string]
    $Phone = "",
    [Parameter(Mandatory = $false)]
    [string]
    $Email = ""
)

Set-AzSecurityContact -Name $Name -Email $Email -Phone $Phone -AlertAdmin:$AlertAdmin -NotifyOnAlert:$NotifyOnAlert