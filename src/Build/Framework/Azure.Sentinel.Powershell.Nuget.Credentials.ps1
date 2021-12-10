[CmdletBinding()]
param (
    [Parameter()]
    [string]
    $NuGetApiKey
)

$SecurePatToken = ConvertTo-SecureString -String $NuGetApiKey -AsPlainText -Force
return New-Object System.Management.Automation.PSCredential("[NO INFORMED]", $SecurePatToken)
