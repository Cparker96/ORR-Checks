<#
    .SYNOPSIS
        Validates the existence of the server in Log Analytics
    .DESCRIPTION
        This function validates that the MMA agent is configured in Log Analytics
    .PARAMETER Environment
        The $VmObj variable which pulls in metadata from the server 
    .EXAMPLE
        Get-MMACheck_lnx -VmObj $VmObj
            

    .NOTES
        FunctionName    : Get-MMACheck_lnx
        Created by      : Cody Parker
        Date Coded      : 09/12/2022
        Modified by     : 
        Date Modified   : 

#>

Function Get-MMACheck_lnx
{
    Param
    (
        [parameter(Position = 0, Mandatory=$true)] [Microsoft.Azure.Commands.Compute.Models.PSVirtualMachine] $VmObj
    )

    [System.Collections.ArrayList]$Validation = @()

    $workspace = 'e0225178-cc8b-4aa2-9422-0df2fa85cff9'  
    $Query
}