@{
    Name = "Azure Sentinel Data Export Rules"
    Type = "PowerShell"
    Description = "Manage the Data Export Rules based on the Definition by Environment"
    Modules = @{
        "Az.Accounts" = "2.2.8"
        "Az.EventHub" = "1.7.2"
        "Az.Resources" = "3.5.0"
        "Az.Storage" = "3.6.0"
    }
}