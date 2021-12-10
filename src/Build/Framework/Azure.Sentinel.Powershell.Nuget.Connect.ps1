[CmdletBinding()]
param (
    [Parameter(Mandatory = $true)]
    [string]
    $Name,
    [Parameter(Mandatory = $true)]
    [string]
    $NuGetApiKey,
    [Parameter(Mandatory = $true)]
    [string]
    $Location
)

$SecureNuGetApiKey = ConvertTo-SecureString -String $NuGetApiKey -AsPlainText -Force
$Credentials = New-Object System.Management.Automation.PSCredential("[NO INFORMED]", $SecureNuGetApiKey)
$PSRepository = Get-PSRepository -Name $Name -ErrorAction SilentlyContinue
if($null -eq $PSRepository -or [string]::Empty -eq $PSRepository) {
    Register-PSRepository -Name $Name -SourceLocation $Location -PublishLocation $Location -InstallationPolicy Trusted -Credential $Credentials
}