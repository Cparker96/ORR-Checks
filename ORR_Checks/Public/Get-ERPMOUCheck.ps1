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

    $erpm = Invoke-AzVMRunCommand -ResourceGroupName $VmObj.ResourceGroupName -VMName $VmObj.Name -CommandId 'RunPowerShellScript' `
    -ScriptPath ".\ORR_Checks\ORR_Checks\Private\Validate_ERPM_OU.ps1"

    $validateerpm = $erpm.Value.message

    if ($null -eq $validateerpm)
    {
        Write-Host "This server does not have an associated OU path in AD" -ErrorAction Stop -ForegroundColor Red
    } else {
        Write-Host "This server is configured for its OU in ERPM" -ForegroundColor Green
    }
}