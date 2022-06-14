<#
    .SYNOPSIS
        The main file to run the Server Operational Readdiness Review (ORR) process
    .DESCRIPTION
        the Ps1 that actually runs the ORR workflow and outputs the validation steps
    .PARAMETER Hostname
        The Server name of the Server being ORR'd
    .PARAMETER Environment
        Specifies the Cloud platform and tennant to connect to
            "VMWARE" 
            
    .PARAMETER Subscription
        The friendly name of the subscription where the VM was built
    .PARAMETER Resource Group
        The Resource group name where the VM was built
    .PARAMETER Operating System
        Can be left null but a simple Windows or Linux is prefered
    .PARAMETER Requestor
        The name of the VM requestor
    .PARAMETER Created By
        The name of the IT professional who did the build
    .PARAMETER Ticket Number
        The Snow ticket that stared the build process and where the requirements and approvals are sourced 
    .PARAMETER RunTenableScan
        A quick way to not run the tennable scan (aprox 1 hour) for testing purposes. 
        Approved Values
            "Yes"
            "No"

    .EXAMPLE
        {
            "Hostname" : "TXAINFAZU021",
            "Environment" : "AzureCloud",
            "Subscription" : "Enterprise",
            "Resource Group" : "308-Utility",
            "Operating System" : "",
            "Requestor" : "Christopher Reilly",
            "Created By" : "Ricky Barbour",
            "Ticket Number" : "SCTASK0014780", 
            "RunTenableScan" : "Yes"
        }       

    .NOTES
        Created by      : Cody Parker and Claire Larvin
        Date Coded      : 04/16/2021
        Modified by     : Casey Cooper
        Date Modified   : 06/14/2022
        #>

        Links:
        Nuget powershell module 
            https://docs.microsoft.com/en-us/azure/devops/artifacts/tutorials/private-powershell-library?view=azure-devops
    #>
    
    
    #============================================#>
    
    
    <#============================================
    import-module if the version in this folder isn't the one that you have
    #============================================#>
    <#if(($null -eq (get-module ORR_Checks).version) -and 
    ((get-module ORR_Checks).version -ne (test-modulemanifest .\ORR_Checks\ORR_Checks.psd1).Version)){
        Import-Module .\ORR_Checks -Force -WarningAction SilentlyContinue -ErrorAction Stop
    }#>
    
    <#============================================
    Get variables
    #============================================#>
    Set-StrictMode -version 3 
    set-strictMode -Off
    [Uri]$Url = "https://textron.splunkcloud.com/"
    $VmRF = @()
#Changed AZCheck to VMCheck varriable Casey
    $VMCheck = @()
    $VMobj = @()
    $validateErpmOU = @()
    $validateErpmAdmins = @()
    $validateMcafee = @()
    $SplunkCheck = @()
    $validateTenable = @()
    $tennableVulnerabilities = @()
    $SqlCredential = @()
    $sqlInstance = 'txadbsazu001.database.windows.net'
    $sqlDatabase = 'TIS_CMDB'
    
#get Server Build variables from VM_Request_Fields.json
Try
{
    $VmRF = Get-Content .\VM_Request_Fields.json | convertfrom-json -AsHashtable
}
catch{ write-error "Could not load VM_Request_Fields.json `r`n $($_.Exception)" -erroraction stop }

<#============================================ 
Get Credentials
#============================================#>
Try{
    #connect to VMWare and make sure the context is Enterprise where the keyvault exists

    #Ignoring certificates and forcing https protocol
    Set-PowerCLIConfiguration -InvalidCertificateAction:Ignore

    #connecting to VCenter Server(currently needs credentials)
     Connect-VIServer -Server txainfnwh066v.txt.textron.com -Protocol https
     
     #-Environment AzureCloud -Tenant '2d5b202c-8c07-4168-a551-66f570d429b3' -WarningAction ignore > $null
    #Set-AzContext -Subscription 'Enterprise' > $null

    #$TenableAccessKey = Get-AzKeyVaultSecret -vaultName 'kv-308' -name 'ORRChecks-TenableAccessKey-10m' -AsPlainText 
    #$TenableSecretKey = Get-AzKeyVaultSecret -vaultName 'kv-308' -name 'ORRChecks-TenableSecretKey-10m' -AsPlainText 
    #$SqlCredential = New-Object System.Management.Automation.PSCredential ('ORRCheckSql', ((Get-AzKeyVaultSecret -vaultName "kv-308" -name 'ORRChecks-Sql').SecretValue))
    #$SplunkCredential = New-Object System.Management.Automation.PSCredential ('svc_tis_midrange', ((Get-AzKeyVaultSecret -vaultName 'kv-308' -name 'ORRChecks-Splunk').SecretValue)) 
    #$GovAccount = New-Object System.Management.Automation.PSCredential ('768ca4de-5c94-4879-9c74-be8d0217ff01',((Get-AzKeyVaultSecret -vaultName 'kv-308' -name 'ORRChecks-GCCHAccess').SecretValue))
    #$prodpass = Get-AzKeyVaultSecret -vaultName 'kv-308' -name 'SNOW-API-Password' -AsPlainText 
}
Catch{
    Write-Error "could not get keys from key vault" -ErrorAction Stop
}

#Write-Host "Running ORR on Server $($VmRF.Hostname)"
