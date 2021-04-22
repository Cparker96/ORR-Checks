
<#
    .SYNOPSIS
        Validate VM in Azure
    .DESCRIPTION
        This function logs into the VM and performs various validation checks on services, admin/admin groups, AD configuration, etc.
    .PARAMETER Environment
        The $VmName variable which pulls in metadata from the server 
    .EXAMPLE
        get-AzureCheck -VmName 'TXBMMLINKGCCT02' `
        -Environment AzureCloud `
        -Subscription Enterprise `
        -ResourceGroup 308-Utility `
        -Credential $credential
            

    .NOTES
        FunctionName    : Get-VMCheck
        Created by      : Cody Parker
        Date Coded      : 04/21/2021
        Modified by     : 
        Date Modified   : 

#>
Function Get-VMCheck
{
    Param(
        [parameter(Position = 0, Mandatory=$true)] [String] $VmName
    )
    [pscustomobject]$Validation = @()

    <#============================================
    Login to the VM
    #============================================#>

    Connect-AzAccount -Environment AzureCloud
    $IP = Get-AzNetworkInterface -Name txainfazu901396
    $cred = (Get-AzKeyVaultSecret -VaultName tisutility -Name 'tis-midrange' | select Name), `
     (Get-AzKeyVaultSecret -VaultName tisutility -Name 'tis-midrange').SecretValue
    
    Try
    {
        Enter-PSSession -ComputerName $IP.IpConfigurations.PrivateIpAddress `
            -Credential $cred  
    }
    Catch{
        $Validation += [pscustomobject]@{ValidationStep = 'Authentication'
        FriendlyError = "Could not log in to " + $IP.IpConfigurations.PrivateIpAddress
        PsError = $error[0]}
    }

    <#==================================================
    Validate against services that should be running
    #===================================================#>

    $services = Get-service | Where-Object {$_.DisplayName -in ('Tenable Nessus Agent', 'Microsoft Monitoring Agent', 'McAfee Agent Service', 'SplunkForwarder Service')}

    foreach ($service in $services)
    {
        if (($null -eq $service.DisplayName) -or ($service.Status -ne 'Running'))
        {
            $Validation += [pscustomobject]@{ValidationStep = 'Services'
            FriendlyError = "One of the services is either not running or not installed."
            PsError = $error[0]}
        }
    }
    
    <#============================================
    Run system updates
    #============================================#>

    

    <#============================================
    Take hostname out of TIS_CMDB
    #============================================#>



    Try
    {
        $tags | test-json -schemafile "$($MyInvocation.MyCommand.Path)\Tags_Definition.json" -ErrorAction stop
    }
    catch
    {
        $Validation += [pscustomobject]@{ValidationStep = 'Validation - Tags'
        FriendlyError = "Tags do not meet Validation"
        PsError = "$PSScriptRoot\Tags_Definition.json"}
    }

        #>
    if(!$Validation)
    {
        $Validation += [pscustomobject]@{ValidationStep = 'Azure Checks Passed'
        FriendlyError = ""
        PsError = ''}
    }


    return $Validation
}



