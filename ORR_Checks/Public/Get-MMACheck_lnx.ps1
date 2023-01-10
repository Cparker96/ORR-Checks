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
        Modified by     : ...
        Date Modified   : ...

#>

Function Get-MMACheck_lnx
{
    Param
    (
        [parameter(Position = 0, Mandatory=$true)] [Microsoft.Azure.Commands.Compute.Models.PSVirtualMachine] $VmObj
    )

    [System.Collections.ArrayList]$Validation = @()

    # set LAW values
    $workspace = 'your_workspace_id'  
    $searchquery = "Heartbeat
    | where OSType == 'Linux'
    | summarize arg_max(TimeGenerated, *) by SourceComputerId
    | sort by Version asc
    | render table
    | project Computer, Version
    | where Computer == '$($VmObj.Name)'"

    # go search Textron LAW for MMA check in
    try 
    {
        $LAWquery = Invoke-AzOperationalInsightsQuery -WorkspaceId $workspace -Query $searchquery 

        if (($null -ne $LAWquery.Results) -and ($LAWquery.Results.Computer -eq $VmObj.Name))
        {
            $Validation.add([PSCustomObject]@{System = 'Server'
            Step = 'MMA'
            SubStep = "MMA"
            Status = 'Passed'
            FriendlyError = ""
            PsError = ''}) > $null 
        } else {
            $Validation.add([PSCustomObject]@{System = 'Server'
            Step = 'MMA'
            SubStep = "MMA"
            Status = 'Failed'
            FriendlyError = "There doesn't seem to be a heartbeat check in for $($Vmobj.Name). Please troubleshoot"
            PsError = $PSItem.Exception}) > $null 
        }
    } catch {
        $Validation.add([PSCustomObject]@{System = 'Server'
        Step = 'MMA'
        SubStep = "MMA"
        Status = 'Failed'
        FriendlyError = "Failed to query Textron's LAW for MMA checkin for $($Vmobj.Name). Please troubleshoot"
        PsError = $PSItem.Exception}) > $null 
    }

    return $Validation, $LAWquery.Results
}