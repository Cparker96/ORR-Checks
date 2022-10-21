<#
    .SYNOPSIS
        Validate that a linux server is configured for Tenable
    .DESCRIPTION
        This function authenticates into the server and validates that Tenable is running
    .PARAMETER Environment
        The $VmObj variable which pulls in metadata from the server 
    .EXAMPLE

    .NOTES
        FunctionName    : Get-TenableStatus_lnx
        Created by      : Cody Parker
        Date Coded      : 09/08/2022
        Modified by     : 
        Date Modified   : 

#>

function Get-TenableStatus_lnx
{
    Param
    (
        [parameter(Position = 0, Mandatory=$true)] [Microsoft.Azure.Commands.Compute.Models.PSVirtualMachine] $VmObj
    )

    $ScriptPath = "$((get-module ORR_Checks).modulebase)\Private"
    [System.Collections.ArrayList]$Validation = @()

    try 
    {
        $checktenablestatus = Invoke-AzVMRunCommand -ResourceGroupName $VmObj.ResourceGroupName -VMName $VmObj.Name -CommandId 'RunShellScript' `
        -ScriptPath "$ScriptPath\Validate_Tenable_lnx.sh" -ErrorAction Stop

        $tenablestatus = $checktenablestatus.Value.message

        # I don't really like this way of checking whether the service is running - it works for now, but would
        # ideally like to learn how to split the entire $tenablestatus var into something easy to work with
        # its hard doing it in linux vs. doing it in windows
        # if you have a good way to parse this ugly output of a file a better way, by all means...
    
        if ($tenablestatus -like "*loaded active running*")
        {
            $Validation.add([PSCustomObject]@{System = 'Server'
            Step = 'Tenable'
            SubStep = "Services - Tenable"
            Status = 'Passed'
            FriendlyError = ""
            PsError = ''}) > $null 
        } else {
            $Validation.add([PSCustomObject]@{System = 'Server'
            Step = 'Splunk'
            SubStep = "Services - Tenable"
            Status = 'Failed'
            FriendlyError = 'Tenable failed to initialize or is not running. Please troubleshoot'
            PsError = $PSItem.Exception}) > $null 
        }
    } 
    
    catch {
        $Validation.add([PSCustomObject]@{System = 'Server'
        Step = 'Tenable'
        SubStep = "Services - Tenable"
        Status = 'Failed'
        FriendlyError = 'Failed to check if Tenable is running on the machine. Please troubleshoot'
        PsError = $PSItem.Exception}) > $null 

        return $Validation
    }

    return $Validation, $tenablestatus
}