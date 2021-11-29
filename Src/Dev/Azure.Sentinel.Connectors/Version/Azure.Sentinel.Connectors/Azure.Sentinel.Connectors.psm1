function Get-AzSentinelConnectorsLocation{
    $ConnectoreModuleBasePath = (Get-Module -Name Azure.Sentinel.Connectors).Path | Split-Path
    return Join-Path -Path $ConnectoreModuleBasePath -ChildPath "Connectors"
}