<#
    .SYNOPSIS
        Validate that a server is configured in ERPM for OU path
    .DESCRIPTION
        This function authenticates into the server and validates that ERPM is configured properly for OU path
    .PARAMETER Environment
        The $VmObj variable which pulls in metadata from the server 
    .EXAMPLE

    .NOTES
        FunctionName    : Get-ERPMOUCheck
        Created by      : Cody Parker
        Date Coded      : 07/9/2021
        Modified by     : 
        Date Modified   : 

#>
Function Get-ERPMOUCheck
{
    Param
    (
        [parameter(Position = 0, Mandatory=$true)] [Microsoft.Azure.Commands.Compute.Models.PSVirtualMachine] $VmObj
    )
    [System.Collections.ArrayList]$Validation = @()
    Try{
        $erpm = Invoke-AzVMRunCommand -ResourceGroupName $VmObj.ResourceGroupName -VMName $VmObj.Name -CommandId 'RunPowerShellScript' `
        -ScriptPath "$((get-module ORR_Checks).modulebase)\Private\Validate_ERPM_OU.ps1"
    
        $validateerpm = $erpm.Value.message

        if ($validateerpm -notlike "*LDAP://*")
        {
            $validation = [PSCustomObject]@{System = 'Server'
            Step = 'ERPMCheck'
            SubStep = 'ActiveDirectory OU'
            Status = 'Failed'
            FriendlyError = 'The Server Does not have an OU associated in AD'
            PsError = ''}         
        } else {
            $validation = [PSCustomObject]@{System = 'Server'
            Step = 'ERPMCheck'
            SubStep = 'ActiveDirectory OU'
            Status = 'Passed'
            FriendlyError = ''
            PsError = '' }
        }

    }
    Catch{
        $validation = [PSCustomObject]@{System = 'Server'
        Step = 'ERPMCheck'
        SubStep = 'ActiveDirectory OU'
        Status = 'Failed'
        FriendlyError = 'Failed to run ERPM Checks on the server'
        PsError = "$PSItem.Exception" }

        return $validation
    }

    return ($validation, $validateerpm) 
}