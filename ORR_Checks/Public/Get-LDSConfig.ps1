<#
    .SYNOPSIS
        Validates that the linux VM is configured for LDS
    .DESCRIPTION
        This function logs into the linux VM and validates that the server is configured for LDS
    .PARAMETER Environment
        The $VmObj variable which pulls in metadata from the server 
    .EXAMPLE
        Get-Sudoers -VmObj $VmObj
            

    .NOTES
        FunctionName    : Get-LDSConfig
        Created by      : Cody Parker
        Date Coded      : 09/16/2021
        Modified by     : 
        Date Modified   : 

#>

function Get-LDSConfig
{
    Param
    (
        [parameter(Position = 0, Mandatory=$true)] [Microsoft.Azure.Commands.Compute.Models.PSVirtualMachine] $VmObj
    )

    [System.Collections.ArrayList]$Validation = @()

    try 
    {
        $checklds = Invoke-AzVMRunCommand -ResourceGroupName 'ENG-PLM-DEVTEST' -VMName TXKAPPAZU809 -CommandId 'RunShellScript' `
        -ScriptPath ".\Private\Check_LDS_Config.sh" -ErrorAction Stop

        $ldsfile = $checklds.Value.message
        # the output var splits the sudofile var by the hidden whitespace, this took me forever to find
        # the result in the output var is $output[0] = "a string in one line" - previously I would get a single letter for the result
        # this is the only way I found that gets the output that I am looking for
        $ldscontent = $ldsfile.Split('
        ')
    }
    catch 
    {

    }
}