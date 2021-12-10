[CmdletBinding()]
param (
    [Parameter(Mandatory = $true)]
    [string]
    $Path,
    [Parameter(Mandatory = $true)]
    [string]
    $OutputPath,
    [Parameter(Mandatory = $true)]
    [int]
    $MajorVersion,
    [Parameter(Mandatory = $false)]
    [int]
    $MinorVersion = 0,
    [Parameter(Mandatory = $false)]
    [string]
    $Build = 0,
    [Parameter(Mandatory = $false)]
    [switch]
    $PreRelease,
    [Parameter(Mandatory = $false)]
    [string]
    $PreReleasePrefix = "pre"
)

if($PreRelease) {
    $Version = "$($MajorVersion).$($MinorVersion).$($Build)-$($PreReleasePrefix)"
}
else {
    $Version = "$($MajorVersion).$($MinorVersion).$($Build)"
}

$AlreadyExists = Test-Path -LiteralPath $OutputPath
if($true -eq $AlreadyExists)
{
    Remove-Item -LiteralPath $OutputPath -Recurse -Force
}

$SourcePathItem = Get-Item -LiteralPath $Path
$Destination = Join-Path $OutputPath $SourcePathItem.Name
Copy-Item -Path $Path -Filter *.* -Destination $Destination -Recurse -Force
$Directory = Get-ChildItem -Path $Destination -Filter "Version" -Recurse | Select-Object -First 1
Rename-Item -LiteralPath $Directory.FullName -NewName $Version -Force
$Items = Get-ChildItem -LiteralPath $Destination -Filter "*.psd1" -Recurse
$Items | ForEach-Object {
    $ManifestVersion = Get-Content $_.FullName
    $ManifestVersion = $ManifestVersion.Replace("[Version]", $Version)
    $ManifestVersion = $ManifestVersion.Replace("0.0.0", $Version)
    if($PreRelease) {
        $ManifestVersion = $ManifestVersion.Replace("# [PRE-RELEASE] ", [string]::Empty)
    }
    $ManifestVersion | Set-Content $_.FullName
}
Get-ChildItem -LiteralPath $OutputPath -Recurse | ForEach-Object { Write-Host $_.FullName }