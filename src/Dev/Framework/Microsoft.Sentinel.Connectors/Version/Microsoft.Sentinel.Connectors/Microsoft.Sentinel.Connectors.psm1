function Get-AzSentinelConnectorsLocation{
    $ConnectoreModuleBasePath = (Get-Module -Name Microsoft.Sentinel.Connectors).Path | Split-Path
    return Join-Path -Path $ConnectoreModuleBasePath -ChildPath "Connectors"
}