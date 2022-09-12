<#
    .SYNOPSIS
        Validates the existence of sudoers via Realm Join
    .DESCRIPTION
        This function validates that the correct groups are configured through the Realm Join process
    .PARAMETER Environment
        The $VmObj variable which pulls in metadata from the server 
    .EXAMPLE
        Get-Sudoers -VmObj $VmObj
            

    .NOTES
        FunctionName    : Get-RealmJoin
        Created by      : Cody Parker
        Date Coded      : 09/08/2022
        Modified by     : 
        Date Modified   : 

#>

function Get-RealmJoin_lnx
{
    Param
    (
        [parameter(Position = 0, Mandatory=$true)] [Microsoft.Azure.Commands.Compute.Models.PSVirtualMachine] $VmObj
    )

    $ScriptPath = "$((get-module ORR_Checks).modulebase)\Private"
    [System.Collections.ArrayList]$Validation = @()

    try
    {
        $checkrealmjoin = Invoke-AzVMRunCommand -ResourceGroupName $VmObj.ResourceGroupName -VMName $VmObj.Name -CommandId 'RunShellScript' `
        -ScriptPath "$ScriptPath\Check_RealmJoin_lnx.sh" -ErrorAction Stop

        $realmjoin = $checkrealmjoin.Value.message

        # I don't really like this way of checking whether the service is running - it works for now, but would
        # ideally like to learn how to split the entire $realmjoin var into something easy to work with
        # its hard doing it in linux vs. doing it in windows
        # if you have a good way to parse this ugly output of a file a better way, by all means...

        # checking for the two groups that must be in the /etc/sudoers file assuming a successful realm join
        if (($realmjoin -like "*ADM_SRV_AZU*") -and ($realmjoin -like "*SA_$($vmobj.Name)*"))
        {
            $Validation.add([PSCustomObject]@{System = 'Server'
            Step = 'Realm Join'
            SubStep = "Realm Join"
            Status = 'Passed'
            FriendlyError = ""
            PsError = ''}) > $null 
        } else {
            $Validation.add([PSCustomObject]@{System = 'Server'
            Step = 'Realm Join'
            SubStep = "Realm Join"
            Status = 'Failed'
            FriendlyError = "Failed to identify the correct groups/sudoers from the realm join process. Please troubleshoot"
            PsError = $PSItem.Exception}) > $null 
        } 
    }

    catch {
        $Validation.add([PSCustomObject]@{System = 'Server'
        Step = 'Realm Join'
        SubStep = "Realm Join"
        Status = 'Failed'
        FriendlyError = "Failed to determine whether realm join was successful. Please troubleshoot"
        PsError = $PSItem.Exception}) > $null 

        return $Validation
    }
}
