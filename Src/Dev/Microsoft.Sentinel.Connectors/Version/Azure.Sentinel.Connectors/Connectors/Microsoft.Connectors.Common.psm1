function Get-ConnectorsCredentials {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [string]
        $KeyVault,
        [Parameter(Mandatory = $true)]
        [string]
        $SecretName
    )
    $KeyVaultSecret = Get-AzKeyVaultSecret -VaultName $KeyVault -Name $SecretName
    $SecretBSTR = [System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($KeyVaultSecret.SecretValue)
    try {
        $SecretAsString = [System.Runtime.InteropServices.Marshal]::PtrToStringBSTR($SecretBSTR)
    } 
    finally {
        [System.Runtime.InteropServices.Marshal]::ZeroFreeBSTR($SecretBSTR)
    }
    $JsonCredentials = $SecretAsString | ConvertFrom-Json
    $User = $JsonCredentials.User
    $SecurePassword = ConvertTo-SecureString -String $JsonCredentials.Password -AsPlainText -Force
    $Credential = New-Object System.Management.Automation.PSCredential($User, $SecurePassword)
    return $Credential
}

function Get-SessionCredentials {
    $AzContext = Get-AzContext 
    if($null -ne $AzContext)
    {
        $Account = $AzContext.Account
        if($null -ne $Account)
        {
            $ClientId = $Account.Id
            $Secret = $Account.ExtendedProperties.ServicePrincipalSecret
            $SecureSecret = ConvertTo-SecureString -String $Secret -AsPlainText -Force
            $Credential = New-Object System.Management.Automation.PSCredential($ClientId, $SecureSecret)
            return $Credential
        }
    }
    throw "Not Valid Credentials"
}



function New-ImpersonationContext {
    [CmdletBinding()]
    [OutputType([System.Management.Automation.PSCredential])]
    param (
        [Parameter(Mandatory = $true)]
        [string]
        $KeyVault,
        [Parameter(Mandatory = $true)]
        [string]
        $SecretName
    )
    if($null -ne (Get-AzContext)) {
        $CurrentCredentials = Get-SessionCredentials
        $ImpersonationCredentials = Get-ConnectorsCredentials -KeyVault $KeyVault -SecretName $SecretName
        if(-not [string]::IsNullOrEmpty((Get-AzContext).Subscription.Id)) {
            Connect-AzAccount -Tenant (Get-AzContext).Subscription.TenantId -Subscription (Get-AzContext).Subscription.Id -Credential $ImpersonationCredentials | Out-Null 
        }
        else {
            Connect-AzAccount -Tenant (Get-AzContext).Subscription.TenantId -Credential $ImpersonationCredentials | Out-Null 
        }
        return $CurrentCredentials
    }
    else {
        throw "New Impersonation Context requires Azure Context"
    }
}

function Close-ImpersonationContext {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [System.Management.Automation.PSCredential]
        $Credentials
    )

    if($null -ne (Get-AzContext)) {
        if(-not [string]::IsNullOrEmpty((Get-AzContext).Subscription.Id)) {
            Connect-AzAccount -ServicePrincipal -Tenant (Get-AzContext).Subscription.TenantId -Subscription (Get-AzContext).Subscription.Id -Credential $Credentials
        }
        else {
            Connect-AzAccount -ServicePrincipal -Tenant (Get-AzContext).Subscription.TenantId -Credential $Credentials 
        }
    }
    else {
        throw "Close Impersonation Context requires Azure Context"
    }
}

function Use-Impersonation {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true, ValueFromPipeline = $true)]
        [System.Management.Automation.ScriptBlock]
        $Code,
        [Parameter(Mandatory = $false)]
        [string]
        $KeyVault,
        [Parameter(Mandatory = $false)]
        [string]
        $SecretName,
        [Parameter(Mandatory = $false)]
        [switch]
        $Impersonate
    )

    if($Impersonate) {
        $Credentials = New-ImpersonationContext -KeyVault $KeyVault -SecretName $SecretName
    }
    try {
        Invoke-Command -ScriptBlock $Code
    }
    finally {
        if($Impersonate -and ($null -ne $Credentials)) {
            Close-ImpersonationContext -Credentials $Credentials
        }
    }
}

Set-Alias -Name RunAs -Value Use-Impersonation
