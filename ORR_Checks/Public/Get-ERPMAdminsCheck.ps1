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

    $Admins = Invoke-AzVMRunCommand -ResourceGroupName $VmObj.ResourceGroupName -VMName $VmObj.Name -CommandId 'RunPowerShellScript' `
    -ScriptPath ".\ORR_Checks\ORR_Checks\Private\Validate_ERPM_Admins.ps1"

    $checkadmins = $Admins.Value.message | ConvertFrom-Csv

    if (($checkadmins.Name -notcontains 'TXT\ADM_SRV_AZU') -or ($checkadmins.Name -notcontains 'TXT\svc_hq_erpm_svc'))
    {
        Write-Host "This server does not have the configured admins" -ErrorAction Stop -ForegroundColor Red
    } else {
        Write-Host "This server is configured for the ERPM Admins" -ForegroundColor Green
    }
}
