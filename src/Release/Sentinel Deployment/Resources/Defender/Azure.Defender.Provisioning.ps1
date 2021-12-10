[CmdletBinding()]
param (
    [Parameter(Mandatory = $true)]
    [hashtable]
    [ValidateNotNull()]
    $SecurityTierConfiguration
)

$Module = Get-Module -Name Az.Security -ErrorAction SilentlyContinue
if($null -eq $Module){
    Install-Module -Name Az.Security -Force
}

$PricingInformationBlock = Get-AzSecurityPricing
if($null -ne $PricingInformationBlock)
{
    $PricingTiersNames = $PricingInformationBlock | ForEach-Object { $_.Name }
    $SecurityTierConfiguration.GetEnumerator() | ForEach-Object {
        $Item = $_
        try {            
            $IsValid = $PricingTiersNames -contains $Item.Key
            if(-not $IsValid){
                throw "Invalid Azure Service Name"
            }

            if($Item.Value) {
                Set-AzSecurityPricing -Name $Item.Key -PricingTier "Standard"
            }
            else {
                Set-AzSecurityPricing -Name $Item.Key -PricingTier "Free"
            }
        }
        catch {
            if($Item.Value -eq $true) {
                Write-Error "Error while enabling Defender for $($Item.Key)"
            }
            else {
                Write-Error "Error while disabling Defender for $($Item.Key)"
            }

            Write-Error $_
        }
    }
}
else {
    throw "Unexpected error resolving Azure Security Center Pricings"
}