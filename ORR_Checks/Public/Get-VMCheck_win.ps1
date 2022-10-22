
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
        FunctionName    : Get-VMCheck_win
        Created by      : Cody Parker
        Date Coded      : 04/21/2021
        Modified by     : 
        Date Modified   : 

#>
Function Get-VMCheck_win
{
    Param
    (
        [parameter(Position = 0, Mandatory=$true)] [Microsoft.Azure.Commands.Compute.Models.PSVirtualMachine] $VmObj,
        [parameter(Position = 1, Mandatory=$true)] $SqlCredential,
        [parameter(Position = 2, Mandatory=$true)] $sqlInstance,
        [parameter(Position = 3, Mandatory=$true)] $sqlDatabase

    )
    [System.Collections.ArrayList]$Validation = @()
    $ScriptPath = "$((get-module ORR_Checks).modulebase)\Private"

    Try 
    {
        #InvokeAZVMRunCommand returns a string so you need to edit the file to convert the output as a csv 
        $output =  Invoke-AzVMRunCommand -ResourceGroupName $VmObj.ResourceGroupName -VMName $VmObj.Name -CommandId 'RunPowerShellScript' `
            -ScriptPath "$ScriptPath\Validate_Services_win.ps1" -ErrorAction Stop
        
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
        -ScriptPath "$ScriptPath\Validate_Updates_win.ps1" -ErrorAction Stop
        
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

    

    return ($Validation, $services, $updatelist)
}




