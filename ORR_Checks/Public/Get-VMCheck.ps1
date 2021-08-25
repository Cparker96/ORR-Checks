
<#
    .SYNOPSIS
        Validate VM in Azure
    .DESCRIPTION
        This function logs into the VM and performs various validation checks on services, admin/admin groups, AD configuration, etc.
    .PARAMETER Environment
        The $VmObj variable which pulls in metadata from the server 
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
        [parameter(Position = 0, Mandatory=$true)] [Microsoft.Azure.Commands.Compute.Models.PSVirtualMachine] $VmObj,
        [parameter(Position = 1, Mandatory=$true)] $SqlCredential
        )
    [System.Collections.ArrayList]$Validation = @()
    $ScriptPath = "$((get-module ORR_Checks).modulebase)\Private"

    $IP = Get-AzNetworkInterface -ResourceId $VmObj.NetworkProfile.NetworkInterfaces.Id
    
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
    Validate updates were executed
    #============================================#>
    try 
    {
        $validateupdates = Invoke-AzVMRunCommand -ResourceGroupName $VmObj.ResourceGroupName -VMName $VmObj.Name -CommandId 'RunPowerShellScript' `
        -ScriptPath "$ScriptPath\Validate_Updates.ps1"
        
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

    try 
    {
        $connection = Invoke-DbaQuery -SqlInstance $sqlInstance -Database $sourcedbname -SqlCredential $SqlCredential `
            -Query "(select * from dbo.AzureAvailableServers where [server name] = @Name)" -SqlParameters @{ Name = $VmObj.Name}
            
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
    [void]$ValidationPassed.add([PSCustomObject]@{System = 'Server'; Step = 'Validation'; SubStep = 'Services - Tenable Nessus Agent'; Status = 'Passed'; FriendlyError = ''; PsError = ''})
    [void]$ValidationPassed.add([PSCustomObject]@{System = 'Server'; Step = 'Validation'; SubStep = 'Updates'; Status = 'Passed'; FriendlyError = ''; PsError = ''})
    [void]$ValidationPassed.add([PSCustomObject]@{System = 'SQL'; Step = 'Validation'; SubStep = 'Server Name'; Status = 'Passed'; FriendlyError = ''; PsError = ''})



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




