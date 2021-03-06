
<#
    .SYNOPSIS
        Validate VM in Azure
    .DESCRIPTION
        This function logs into the VM and performs various validation checks on services, admin/admin groups, AD configuration, etc.
    .PARAMETER Environment
        The $VmObj variable which pulls in metadata from the server 
    .EXAMPLE
        get-AzureCheck -VmName 'some_server_name' `
        -Environment AzureCloud `
        -Subscription 'some_subscription' `
        -ResourceGroup 'some_resource_group' `
        -Credential $credential
            

    .NOTES
        FunctionName    : Get-VMCheck
        Created by      : 'creator'
        Date Coded      : 04/21/2021
        Modified by     : ...
        Date Modified   : ...

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

    $sqlInstance = 'some_sql_instance'
    $sourcedbname = 'some_sql_database'

   
    
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
                Step = 'VmCheck'
                SubStep = "Services - $($service.DisplayName)"
                Status = 'Failed'
                FriendlyError = 'The service' + $service.DisplayName + ' is not running or not installed.'
                PsError = $PSItem.Exception}) > $null 
            }
            else 
            {
                $Validation.add([PSCustomObject]@{System = 'Server'
                Step = 'VmCheck'
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
        Step = 'VmCheck'
        SubStep = 'Services'
        Status = 'Failed'
        FriendlyError = 'Could not retrieve services'
        PsError = $PSItem.Exception}) > $null 

        return $Validation, $null, $null, $null
    }

    <#============================================
    Validate updates were executed
    #============================================#>
    try 
    {
        $validateupdates = Invoke-AzVMRunCommand -ResourceGroupName $VmObj.ResourceGroupName -VMName $VmObj.Name -CommandId 'RunPowerShellScript' `
        -ScriptPath "$ScriptPath\Validate_Updates.ps1" -ErrorAction Stop
        
        $updatelist = $validateupdates.Value.message

        if (($updatelist -eq '') -or ($null -eq $updatelist))
        {
            $Validation.add([PSCustomObject]@{System = 'Server'
            Step = 'VmCheck'
            SubStep = "Updates"
            Status = 'Passed'
            FriendlyError = ''
            PsError = ''}) > $null 
        }
        else 
        {
            $Validation.add([PSCustomObject]@{System = 'Server'
            Step = 'VmCheck'
            SubStep = "Updates"
            Status = 'Failed'
            FriendlyError = 'There are still updates that need to be applied'
            PsError = $PSItem.Exception}) > $null 
        }
    }
    catch 
    {
        $Validation.add([PSCustomObject]@{System = 'Server'
        Step = 'VmCheck'
        SubStep = "Updates"
        Status = 'Failed'
        FriendlyError = 'Check to make sure you have the package installed.'
        PsError = $PSItem.Exception}) > $null 

        return $Validation, $Services, $null, $null
    }

    <#============================================
    Take hostname out of TIS_CMDB
    #============================================#>
    try 
    {        
        $connection = Invoke-DbaQuery -SqlInstance $sqlInstance -Database $sourcedbname -SqlCredential $SqlCredential `
            -Query "(select * from 'some_sql_table' where [servername] = @Name)" -SqlParameters @{Name = $VmObj.Name} -EnableException
 

        if ($null -eq $connection)
        {
            $Validation.add([PSCustomObject]@{System = 'SQL'
            Step = 'VmCheck'
            SubStep = 'Server Name'
            Status = 'Failed'
            FriendlyError = 'Server Name is not in the SQL DB'
            PsError = ''}) > $null 
        }
        elseif('InUse' -ne $connection.status) 
        {
            $Validation.add([PSCustomObject]@{System = 'SQL'
            Step = 'VmCheck'
            SubStep = 'Server Name'
            Status = 'Failed'
            FriendlyError = 'Please update the Status of the Server in the SQL DB'
            PsError = ''}) > $null 
        }
        else{
            $Validation.add([PSCustomObject]@{System = 'SQL'
            Step = 'VmCheck'
            SubStep = 'Server Name'
            Status = 'Passed'
            FriendlyError = ''
            PsError = ''}) > $null 
        }
    }
    catch 
    {
        $Validation.add([PSCustomObject]@{System = 'SQL'
        Step = 'VmCheck'
        SubStep = 'Server Name'
        Status = 'Failed'
        FriendlyError = 'Could not login to SQL DB'
        PsError = $PSItem.Exception}) > $null 

        return $Validation , $services, $updatelist, $null
    }
    return ($Validation, $services, $updatelist, $connection)
}




