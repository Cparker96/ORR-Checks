# <#
#     .SYNOPSIS
#         Validates that the linux VM is configured for LDS
#     .DESCRIPTION
#         This function logs into the linux VM and validates that the server is configured for LDS
#     .PARAMETER Environment
#         The $VmObj variable which pulls in metadata from the server 
#     .EXAMPLE
#         Get-Sudoers -VmObj $VmObj
            

#     .NOTES
#         FunctionName    : Get-LDSConfig
#         Created by      : Cody Parker
#         Date Coded      : 09/16/2021
#         Modified by     : 
#         Date Modified   : 

# #>

# THIS IS A LEGACY FUNCTION THAT WAS NEEDED FOR ADLDS JOINING OF SERVERS, PROBABLY DON'T NEED THIS ANYMORE BUT I'LL KEEP IT FOR NOW...

# function Get-LDSConfig
# {
#     Param
#     (
#         [parameter(Position = 0, Mandatory=$true)] [Microsoft.Azure.Commands.Compute.Models.PSVirtualMachine] $VmObj
#     )
#     $ScriptPath = "$((get-module ORR_Checks).modulebase)\Private"
#     [System.Collections.ArrayList]$Validation = @()

#     try 
#     {
#         $checklds = Invoke-AzVMRunCommand -ResourceGroupName $VmObj.ResourceGroupName -VMName $VmObj.Name -CommandId 'RunShellScript' `
#         -ScriptPath "$ScriptPath\Check_LDS_Config.sh" -ErrorAction Stop

#         $ldsfile = $checklds.Value.message
#         # the output var splits the sudofile var by the hidden whitespace, this took me forever to find
#         # the result in the output var is $output[0] = "a string in one line" - previously I would get a single letter for the result
#         # this is the only way I found that gets the output that I am looking for
#         # $ldscontent = $ldsfile.Split('
#         # ')
        
#     }
#     catch 
#     {
#         $PSItem.Exception
#     }
# }