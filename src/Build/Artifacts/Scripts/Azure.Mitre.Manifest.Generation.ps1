[CmdletBinding()]
param (
    [Parameter(Mandatory = $true)]
    [string]
    $Path,
    [Parameter(Mandatory = $true)]
    [string]
    $OutputPath,
    [Parameter(Mandatory = $false)]
    [switch]
    $ShowReport
)

$ManifestItems = Get-ChildItem -Path $Path -Include @("*.mitre.manifest.json") -Recurse
$ManifestArray = @()
$ManifestItems | ForEach-Object {
    $File = $_
    $ManifestItem = Get-Content -Path $File.FullName -Raw | ConvertFrom-Json
    $ManifestItem | ForEach-Object {
        $Manifest = $_
        $Manifest.Techniques | ForEach-Object {
            $Row = [PSCustomObject]@{
                Scenario = $File.Directory.Parent.Name
                Kind = (Split-Path $File.Directory -Leaf)
                Artifact = $File.Name
                Name = $File.Name.Replace(".mitre.manifest.json", [string]::Empty) 
                Tactic = $Manifest.Tactic
                Technique = $_
            }
            $ManifestArray += $Row
        }
    }
}

if($ShowReport){
    $ManifestArray | Format-Table Scenario,Name,Tactic,Technique
}

$ManifestArray | ConvertTo-Csv -Delimiter "," -NoTypeInformation | Out-File -FilePath $OutputPath