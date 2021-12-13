function Get-AzSentinelConnectorsLocation{
    $ConnectoreModuleBasePath = (Get-Module -Name Microsoft.Sentinel.Connectors -ListAvailable).Path | Split-Path -Parent
    return Join-Path -Path $ConnectoreModuleBasePath -ChildPath "Connectors"
}