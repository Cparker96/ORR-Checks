<#
    .SYNOPSIS
        Validates the existence of sudoers (admins)
    .DESCRIPTION
        This function logs into the linux VM and searches in the /etc/sudoers file for the list of sudoers
    .PARAMETER Environment
        The $VmObj variable which pulls in metadata from the server 
    .EXAMPLE
        Get-Sudoers -VmObj $VmObj
            

    .NOTES
        FunctionName    : Get-Sudoers
        Created by      : Cody Parker
        Date Coded      : 09/16/2021
        Modified by     : 
        Date Modified   : 

#>

function Get-Sudoers 
{
    Param
    (
        [parameter(Position = 0, Mandatory=$true)] [Microsoft.Azure.Commands.Compute.Models.PSVirtualMachine] $VmObj
    )

    [System.Collections.ArrayList]$Validation = @()

    try{
        $check =  Invoke-AzVMRunCommand -ResourceGroupName $VmObj.ResourceGroupName -VMName $VmObj.Name -CommandId 'RunShellScript' `
        -ScriptPath ".\Private\Service_Checks_Linux.sh" -ErrorAction Stop
    
        $sudofile = $check.Value.message
        # the output var splits the sudofile var by the hidden whitespace, this took me forever to find
        # the result in the output var is $output[0] = "a string in one line" - previously I would get a single letter for the result
        # this is the only way I found that gets the output that I am looking for
        $output = $sudofile.Split('
        ')
    
        $sudoers = @()
        foreach ($line in $output)
        {
            if ($line -like "*ALL=(ALL)*")
            {
                $sudoers += $line
            }
    
            # filtering out the extra lines in /etc/sudoers that don't involve the admins
            $finalsudoers = $sudoers | where {$_ -notlike "*%*"}
    
            if ($finalsudoers.Count -le 1)
            {
                $Validation.add([PSCustomObject]@{System = 'Server'
                Step = 'Validation'
                SubStep = "Sudoers"
                Status = 'Failed'
                FriendlyError = 'The file /etc/sudoers does not have any sudoers associated besides root. Please add the necessary accounts'
                PsError = $PSItem.Exception}) > $null 
            }
            else 
            {
                $Validation.add([PSCustomObject]@{System = 'Server'
                Step = 'Validation'
                SubStep = "Sudoers"
                Status = 'Passed'
                FriendlyError = ''
                PsError = ''}) > $null                
            }
        }
    }
    catch
    {
        $Validation.add([PSCustomObject]@{System = 'Server'
        Step = 'Validation'
        SubStep = 'Sudoers'
        Status = 'Failed'
        FriendlyError = 'Could not authenticate into server. Please try again.'
        PsError = $PSItem.Exception}) > $null 

        return $Validation 
    }
}
