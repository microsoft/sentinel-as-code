[CmdletBinding()]
param (
    [Parameter(Mandatory = $true)]
    [string]
    $Name,
    [Parameter(Mandatory = $true)]
    [string]
    $Path,
    [Parameter(Mandatory = $true)]
    [string]
    $NuGetApiKey,
    [Parameter(Mandatory = $false)]
    [switch]
    $PreRelease
)

$Item = Get-ChildItem -Path $Path -Filter "*.psd1" -Recurse | Select-Object -First 1
if($null -ne $Item) {
    $Directory = $Item.Directory
    if($PreRelease){
        $env:PSModulePath = $env:PSModulePath + "$([System.IO.Path]::PathSeparator)$($Directory.FullName)"
        Publish-Module -Name $Directory.Name -Exclude @("README.md") -Repository $Name -NuGetApiKey $NuGetApiKey -Credential $Credentials -Force -AllowPrerelease:$PreRelease
    }
    else {
        Publish-Module -Path $Directory.FullName -Repository $Name -NuGetApiKey $NuGetApiKey -Credential $Credentials -Force
    }
}
else {
    throw "Module PSD Manifest not found"
}