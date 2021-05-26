
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
        [parameter(Position = 0, Mandatory=$true)] [Microsoft.Azure.Commands.Compute.Models.PSVirtualMachine] $VmObj
    )
    [System.Collections.ArrayList]$Validation = @()
    $ScriptPath = "$((get-module ORR_Checks).modulebase)\Private"
    <#============================================
    Login to the VM
    #============================================#>

    $IP = Get-AzNetworkInterface -ResourceId $VmObj.NetworkProfile.NetworkInterfaces.Id
    
    # This block will enable PS remoting into a server from the Azure Serial Console
    # This needs to be enabled to bypass the issue with non domain joined servers
    ######################################################################
    # $remotecommand = "Enable-PSRemoting -Force"
    # $Bytes = [System.Text.Encoding]::Unicode.GetBytes($remotecommand)
    # $EncodedCommand = [Convert]::ToBase64String($Bytes)
    # $EncodedCommand
    #$cred = (Get-AzKeyVaultSecret -VaultName tisutility -Name 'tis-midrange' | select Name), `
     #(Get-AzKeyVaultSecret -VaultName tisutility -Name 'tis-midrange').SecretValue
    
    <#==================================================
    Validate against services that should be running
    #===================================================#>

    Try 
    {
        #InvokeAZVMRunCommand returns a string so you need to edit the file to convert the output as a csv 
        $output =  Invoke-AzVMRunCommand -ResourceGroupName $VmObj.ResourceGroupName -VMName $VmObj.Name -CommandId 'RunPowerShellScript' `
            -ScriptPath "$ScriptPath\Service_Checks.ps1" -ErrorAction Stop
        
        #convert out of CSV so that we will get a object
        $services = $output.Value.message | convertfrom-csv

        foreach ($service in $services)
        {
            if (($null -eq $service.DisplayName) -or ($service.Status -ne 'Running'))
            {
                $Validation.add([PSCustomObject]@{System = 'Server'
                Step = 'Validation'
                SubStep = "Services - $($service.DisplayName)"
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
    #============================================

    Invoke-AzVMRunCommand -ResourceGroupName $VmObj.ResourceGroupName -VMName $VmObj.Name -CommandId 'RunPowerShellScript' `
        -ScriptPath "C:\Users\cparke06\Documents\ORR_Checks\ORR_Checks\Private\Add_Trusted_Hosts.ps1"
    #>
        # try
    # {
    #     $trustedhosts = Invoke-AzVMRunCommand -ResourceGroupName $VmObj.ResourceGroupName -VMName $VmObj.Name -CommandId 'RunPowerShellScript' `
    #     -ScriptPath "C:\Users\cparke06\Documents\ORR_Checks\ORR_Checks\Private\Add_Trusted_Hosts.ps1"

    #     $validatehosts = $trustedhosts.Value.message | convertfrom-csv

    #     foreach ($host in $validatehosts)
    #     {
    #         if ($null -eq $trustedhosts.Value)
    #         {
    #             $Validation.add([PSCustomObject]@{System = 'Server'
    #             Step = 'Validation'
    #             SubStep = "TrustedHosts"
    #             Status = 'Failed'
    #             FriendlyError = 'The VM is not configured for non domain remoting'
    #             PsError = $PSItem.Exception}) > $null 
    #         }
    #         else 
    #         {
    #             $Validation.add([PSCustomObject]@{System = 'Server'
    #             Step = 'Validation'
    #             SubStep = "TrustedHosts"
    #             Status = 'Passed'
    #             FriendlyError = ''
    #             PsError = ''}) > $null 
    #         }
    #     }
    # }   
    # catch 
    # {
    #     $Validation.add([PSCustomObject]@{System = 'Server'
    #     Step = 'Validation'
    #     SubStep = "TrustedHosts"
    #     Status = 'Failed'
    #     FriendlyError = 'The VM is not configured for non domain remoting'
    #     PsError = $PSItem.Exception}) > $null 

    #     return $Validation
    # }
     
    <#============================================
    Run system updates
    #============================================#>
    
    $updates = Invoke-AzVMRunCommand -ResourceGroupName $VmObj.ResourceGroupName -VMName $VmObj.Name -CommandId 'RunPowerShellScript' `
        -ScriptPath "C:\Users\cparke06\Documents\ORR_Checks\ORR_Checks\Private\Run_Updates.ps1"

    <#============================================
    Validate updates were executed
    #============================================#>
    try 
    {
        $validateupdates = Invoke-AzVMRunCommand -ResourceGroupName $VmObj.ResourceGroupName -VMName $VmObj.Name -CommandId 'RunPowerShellScript' `
        -ScriptPath "C:\Users\cparke06\Documents\ORR_Checks\ORR_Checks\Private\Validate_Updates.ps1"
        
        $updatelist = $validateupdates.Value.message | ConvertFrom-Csv

        if ($null -ne $updatelist)
        {
            $Validation.add([PSCustomObject]@{System = 'Server'
            Step = 'Validation'
            SubStep = "Updates"
            Status = 'Failed'
            FriendlyError = 'There are still updates that need to be applied'
            PsError = $PSItem.Exception}) > $null 
        }
        else 
        {
            $Validation.add([PSCustomObject]@{System = 'Server'
            Step = 'Validation'
            SubStep = "Updates"
            Status = 'Passed'
            FriendlyError = ''
            PsError = ''}) > $null 
        }
    }
    catch 
    {
        $Validation.add([PSCustomObject]@{System = 'Server'
        Step = 'Validation'
        SubStep = "Updates"
        Status = 'Failed'
        FriendlyError = 'Check to make sure you have the package installed.'
        PsError = $PSItem.Exception}) > $null 

        return $Validation
    }

    <#============================================
    Take hostname out of TIS_CMDB
    #============================================#>

    $sqlInstance = 'txadbsazu001.database.windows.net'
    $sourcedbname = 'TIS_CMDB'
    $SqlCredential = New-Object System.Management.Automation.PSCredential ('testuser', ((Get-AzKeyVaultSecret -vaultName "tisutility" -name 'testuser').SecretValue))

    try 
    {
        $connection = Invoke-DbaQuery -SqlInstance $sqlInstance -Database $sourcedbname -SqlCredential $SqlCredential `
            -Query "(select * from dbo.AzureAvailableServers where [server name] = @Name)" -SqlParameters @{ Name = "TXAINFAZU289"}
            
        if ($null -eq $connection)
        {
            $Validation.add([PSCustomObject]@{System = 'SQL'
            Step = 'Validation'
            SubStep = 'Server Name'
            Status = 'Passed'
            FriendlyError = ''
            PsError = ''}) > $null 
        }
        else 
        {
            $Validation.add([PSCustomObject]@{System = 'SQL'
            Step = 'Validation'
            SubStep = 'Server Name'
            Status = 'Failed'
            FriendlyError = 'Please take the Server name out of the SQL DB'
            PsError = $PSItem.Exception}) > $null 
        }
    }
    catch 
    {
        $Validation.add([PSCustomObject]@{System = 'SQL'
        Step = 'Authentication'
        SubStep = 'Server Name'
        Status = 'Failed'
        FriendlyError = 'Could not login to SQL DB'
        PsError = $PSItem.Exception}) > $null 

        return $Validation
    }

    <#============================================
    Validate all steps were taken and passed
    Step              SubStep
    ----              -------
    Validation        Services - Microsoft Monitoring Agent
    Validation        Services - McAfee Agent Service
    Validation        Services - SplunkForwarder Service
    Validation        Services - Tenable Nessus Agent
    #============================================#>
  
    [System.Collections.ArrayList]$ValidationPassed = @()
    [void]$ValidationPassed.add([PSCustomObject]@{System = 'Server'; Step = 'Validation'; SubStep = 'Services - Microsoft Monitoring Agent'; Status = 'Passed'; FriendlyError = ''; PsError = ''})
    [void]$ValidationPassed.add([PSCustomObject]@{System = 'Server'; Step = 'Validation'; SubStep = 'Services - McAfee Agent Service'; Status = 'Passed'; FriendlyError = ''; PsError = ''})
    [void]$ValidationPassed.add([PSCustomObject]@{System = 'Server'; Step = 'Validation'; SubStep = 'Services - SplunkForwarder Service'; Status = 'Passed'; FriendlyError = ''; PsError = ''})
    [void]$ValidationPassed.add([PSCustomObject]@{System = 'Server'; Step = 'Validation'; SubStep = 'cccccccccccccccccc'; Status = 'Passed'; FriendlyError = ''; PsError = ''})


    if(!(Compare-Object $Validation $ValidationPassed))
    {
        $Validation.add([PSCustomObject]@{System = 'Server'
                        Step = 'Check'
                        SubStep = 'Passed'
                        Status = 'Passed'
                        FriendlyError = ''
                        PsError = ''}) > $null
    }
    else
    {
        $Validation.add([PSCustomObject]@{System = 'Server'
                        Step = 'Check'
                        SubStep = 'Failed'
                        Status = 'Failed'
                        FriendlyError = ""
                        PsError = ''}) > $null
    }


    return $Validation
}




