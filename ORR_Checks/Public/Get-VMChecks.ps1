
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
    Param
    (
        [parameter(Position = 0, Mandatory=$true)] [String] $VmName
    )
    [System.Collections.ArrayList]$Validation = @()

    <#============================================
    Login to the VM
    #============================================#>


    
    # This block will enable PS remoting into a server from the Azure Serial Console
    # This needs to be enabled to bypass the issue with non domain joined servers
    ######################################################################
    # $remotecommand = "Enable-PSRemoting -Force"
    # $Bytes = [System.Text.Encoding]::Unicode.GetBytes($remotecommand)
    # $EncodedCommand = [Convert]::ToBase64String($Bytes)
    # $EncodedCommand

    # $target = @($VmName)
    # try 
    # {
    #     Invoke-AzVMRunCommand -Name $target

    #     $Validation.add([PSCustomObject]@{System = 'Azure'
    #                     Step = 'Authentication'
    #                     SubStep = 'Login'
    #                     Status = 'Passed'
    #                     FriendlyError = ''
    #                     PsError = ''}) > $null 
    # }
    # catch
    # {
    #     $Validation.add([PSCustomObject]@{System = 'Azure'
    #                     Step = 'Authentication'
    #                     SubStep = 'Login'
    #                     Status = 'Failed'
    #                     FriendlyError = 'Could not get into'
    #                     PsError = $PSItem.Exception}) > $null 
    # }
    ######################################################################
    #Connect-AzAccount -Environment AzureCloud
    #$IP = Get-AzNetworkInterface -Name txainfazu901396
    #$cred = (Get-AzKeyVaultSecret -VaultName tisutility -Name 'tis-midrange' | select Name), `
     #(Get-AzKeyVaultSecret -VaultName tisutility -Name 'tis-midrange').SecretValue
    
    # Try
    # {
    #     Enter-PSSession -ComputerName $VmName `
    #         -Credential $cred  

    #         $Validation.add([PSCustomObject]@{System = 'Server'
    #         Step = 'Authentication'
    #         SubStep = 'Login'
    #         Status = 'Passed'
    #         FriendlyError = ''
    #         PsError = ''}) > $null 
    # }
    # Catch{
    #     $Validation.add([PSCustomObject]@{System = 'Server'
    #                     Step = 'Authentication'
    #                     SubStep = 'Login'
    #                     Status = 'Failed'
    #                     FriendlyError = "Could not get into $($VmName.Name)"
    #                     PsError = $PSItem.Exception}) > $null
        
    #     return $Validation
    # }

    <#==================================================
    Validate against services that should be running
    #===================================================#>

    Try 
    {
        $services =  Invoke-AzVMRunCommand -VMName $VmName -CommandId 'RunPowerShellScript' `
            -ScriptPath '.\ORR_Checks\Private\Validation_Checks.ps1'
        
        foreach ($service in $services)
        {
            if (($null -eq $service.DisplayName) -or ($service.Status -ne 'Running'))
            {
                $Validation.add([PSCustomObject]@{System = 'Server'
                Step = 'Validation'
                SubStep = 'Services'
                Status = 'Failed'
                FriendlyError = 'The service' + $service.DisplayName + ' is not running or not installed.'
                PsError = $PSItem.Exception}) > $null 
            }
            else 
            {
                $Validation.add([PSCustomObject]@{System = 'Server'
                Step = 'Validation'
                SubStep = "Services - $($service.DisplayName)"
                Status = 'Passed'
                FriendlyError = ''
                PsError = ''}) > $null                
            }
        }
    }
    Catch 
    {
        $Validation.add([PSCustomObject]@{System = 'Server'
        Step = 'Validation'
        SubStep = 'Services'
        Status = 'Failed'
        FriendlyError = 'Could not retrieve services'
        PsError = $PSItem.Exception}) > $null 

        return $Validation
    }
    

   
    
    <#============================================
    Run system updates
    #============================================#>

    # try
    # {
    #     #Install-Module -Name PSWindowsUpdate -Scope CurrentUser -Force
    #     $updatelist = Get-WindowsUpdate

    #     if ($updatelist.Count -gt 0)
    #     {
    #         $Validation.add([PSCustomObject]@{System = 'Server'
    #         Step = 'Validation'
    #         SubStep = 'Updates'
    #         Status = 'Failed'
    #         FriendlyError = 'There are still pending Windows Updates'
    #         PsError = $PSItem.Exception}) > $null 
    #     }
    #     else
    #     {
    #         $Validation.add([PSCustomObject]@{System = 'Server'
    #         Step = 'Validation'
    #         SubStep = 'Updates'
    #         Status = 'Passed'
    #         FriendlyError = ''
    #         PsError = ''}) > $null 
    #     }
    # }
    # catch
    # {
    #     $Validation.add([PSCustomObject]@{System = 'Server'
    #     Step = 'Validation'
    #     SubStep = 'Updates'
    #     Status = 'Failed'
    #     FriendlyError = 'Could not install modules'
    #     PsError = $PSItem.Exception}) > $null 

    #     return $Validation
    # }

    <#============================================
    Take hostname out of TIS_CMDB
    #============================================#>

    # $sqlInstance = 'txadbsazu001.database.windows.net'
    # $sourcedbname = 'TIS_CMDB'
    # $sqlcred = (Get-AzKeyVaultSecret -VaultName tisutility -Name 'testuser' | select Name), `
    # (Get-AzKeyVaultSecret -VaultName tisutility -Name 'testuser').SecretValue

    # try 
    # {
    #     $connection = Invoke-DbaQuery -SqlInstance $sqlInstance -Database $sourcedbname -SqlCredential $sqlcred `
    #         -Query "(select * from dbo.AzureAvailableServers where [server name] = $VmName)"

    #     if ($null -eq $connection)
    #     {
    #         $Validation.add([PSCustomObject]@{System = 'SQL'
    #         Step = 'Validation'
    #         SubStep = 'Server Name'
    #         Status = 'Passed'
    #         FriendlyError = ''
    #         PsError = ''}) > $null 
    #     }
    #     else 
    #     {
    #         $Validation.add([PSCustomObject]@{System = 'SQL'
    #         Step = 'Validation'
    #         SubStep = 'Server Name'
    #         Status = 'Failed'
    #         FriendlyError = 'Please take the Server name out of the SQL DB'
    #         PsError = $PSItem.Exception}) > $null 
    #     }
    # }
    # catch 
    # {
    #     $Validation.add([PSCustomObject]@{System = 'SQL'
    #     Step = 'Authentication'
    #     SubStep = 'Server Name'
    #     Status = 'Failed'
    #     FriendlyError = 'Could not login to SQL DB'
    #     PsError = $PSItem.Exception}) > $null 

    #     return $Validation
    # }
}




