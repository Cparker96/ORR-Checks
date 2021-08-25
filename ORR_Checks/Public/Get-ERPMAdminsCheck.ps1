<#
    .SYNOPSIS
        Validate that a server is configured in ERPM for Admins
    .DESCRIPTION
        This function authenticates into the server and validates that ERPM is configured properly for Admins
    .PARAMETER Environment
        The $VmObj variable which pulls in metadata from the server 
    .EXAMPLE

    .NOTES
        FunctionName    : Get-ERPMAdminsCheck
        Created by      : Cody Parker
        Date Coded      : 07/9/2021
        Modified by     : 
        Date Modified   : 

#>
Function Get-ERPMAdminsCheck
{
    Param
    (
        [parameter(Position = 0, Mandatory=$true)] [Microsoft.Azure.Commands.Compute.Models.PSVirtualMachine] $VmObj
    )

    Try{
        $Admins = Invoke-AzVMRunCommand -ResourceGroupName $VmObj.ResourceGroupName -VMName $VmObj.name -CommandId 'RunPowerShellScript' `
        -ScriptPath .\ORR_Checks\Private\Validate_ERPM_Admins.ps1 -ErrorAction Stop
        #"$((get-module ORR_Checks).modulebase)\Private\Validate_ERPM_Admins.ps1"
        #.\ORR_Checks\Private\Validate_ERPM_Admins.ps1

        $checkadmins = $Admins.Value.message | ConvertFrom-Csv 
        
            #look at the groups and determine if they meet the criteria   
            if (($checkadmins.Name -notcontains 'TXT\ADM_SRV_AZU') -or ($checkadmins.Name -notcontains 'TXT\svc_hq_erpm_svc'))
            {
                $validation = [PSCustomObject]@{System = 'ERPM'
                Step = 'ERPMCheck'
                SubStep = 'ERPM Admins'
                Status = 'Failed'
                FriendlyError = 'This server does not have the configured admins'
                PsError = ''} 
            } else {
                $validation = [PSCustomObject]@{System = 'ERPM'
                Step = 'ERPMCheck'
                SubStep = 'ERPM Admins'
                Status = 'Passes'
                FriendlyError = 'This server is configured for the ERPM Admins'
                PsError = ''} 
            }
        
    
    }Catch{
        $validation = [PSCustomObject]@{System = 'VM'
        Step = 'ERPMCheck'
        SubStep = 'ERPM Admins'
        Status = 'Failed'
        FriendlyError = 'Failed to run ERPM Checks on the server'
        PsError = "$PSItem.Exception" } 

        return $validation
    }
    

    return ($validation, $checkadmins.Name)
}
