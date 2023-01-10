<#
    .SYNOPSIS
        Validate that a server is configured in ERPM for Admins
    .DESCRIPTION
        This function authenticates into the server and validates that ERPM is configured properly for Admins
    .PARAMETER Environment
        The $VmObj variable which pulls in metadata from the server 
    .EXAMPLE

    .NOTES
        FunctionName    : Get-ERPMAdminsCheck_win
        Created by      : Cody Parker
        Date Coded      : 07/9/2021
        Modified by     : ...
        Date Modified   : ...

#>
Function Get-ERPMAdminsCheck_win
{
    Param
    (
        [parameter(Position = 0, Mandatory=$true)] [Microsoft.Azure.Commands.Compute.Models.PSVirtualMachine] $VmObj
    )
    $ScriptPath = $ScriptPath = "$((get-module ORR_Checks).modulebase)\Private"
    [System.Collections.ArrayList]$Validation = @()

    Try {
        $Admins = Invoke-AzVMRunCommand -ResourceGroupName $VmObj.ResourceGroupName -VMName $VmObj.name -CommandId 'RunPowerShellScript' `
        -ScriptPath "$ScriptPath\Validate_ERPM_Admins_win.ps1" -ErrorAction Stop

        $checkadmins = $Admins.Value.message | ConvertFrom-Csv 
        
        # look at the groups and determine if they meet the criteria   
        if (($checkadmins.Name -notcontains 'your_AD_group') -or ($checkadmins.Name -notcontains 'your_AD_group'))
        {
            $Validation.Add([PSCustomObject]@{System = 'ERPM'
            Step = 'ERPMCheck'
            SubStep = 'ERPM Admins'
            Status = 'Failed'
            FriendlyError = 'This server does not have the configured admins'
            PsError = $PSItem.Exception}) > $null
        } else {
            $Validation.Add([PSCustomObject]@{System = 'ERPM'
            Step = 'ERPMCheck'
            SubStep = 'ERPM Admins'
            Status = 'Passed'
            FriendlyError = ''
            PsError = ''}) > $null 
        }
    } Catch {
        $validation.Add([PSCustomObject]@{System = 'VM'
        Step = 'ERPMCheck'
        SubStep = 'ERPM Admins'
        Status = 'Failed'
        FriendlyError = 'Failed to run ERPM Checks on the server'
        PsError = $PSItem.Exception}) > $null

        return $validation
    }

    return ($validation, $checkadmins.Name)
}
