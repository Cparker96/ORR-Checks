<#
    .SYNOPSIS
        Validates that the SQL record for the hostname's 'Status' column is updated to 'In Use'
    .DESCRIPTION
        This function validates that the SQL record for the hostname's 'Status' column is updated to 'In Use'
    .PARAMETER Environment
        SQL credentials that are used to authenticate to SSMS
    .EXAMPLE
        Get-HostNameSQL
            

    .NOTES
        FunctionName    : Get-HostNameSQL
        Created by      : Cody Parker
        Date Coded      : 09/15/2022
        Modified by     : 
        Date Modified   : 

#>

function Get-HostNameSQL 
{
    param 
    (
        [parameter(Position = 0, Mandatory=$true)] [Microsoft.Azure.Commands.Compute.Models.PSVirtualMachine] $VmObj,
        [parameter(Position = 1, Mandatory=$true)] $SqlCredential,
        [parameter(Position = 2, Mandatory=$true)] $sqlInstance,
        [parameter(Position = 3, Mandatory=$true)] $sqlDatabase
    )
    
    [System.Collections.ArrayList]$Validation = @()

    # check that the status field of the record is set to 'InUse'
    try 
    {        
        $connection = Invoke-DbaQuery -SqlInstance $sqlInstance -Database $sqlDatabase -SqlCredential $SqlCredential `
            -Query "(select * from dbo.AzureAvailableServers where [servername] = @Name)" -SqlParameters @{Name = $VmObj.Name} -EnableException
 
        if ($null -eq $connection)
        {
            $Validation.add([PSCustomObject]@{System = 'SQL'
            Step = 'VmCheck'
            SubStep = 'Server Name'
            Status = 'Failed'
            FriendlyError = "Server $($VmObj.Name) is not in the SQL DB"
            PsError = $PSItem.Exception}) > $null 
        }
        elseif('InUse' -ne $connection.status) 
        {
            $Validation.add([PSCustomObject]@{System = 'SQL'
            Step = 'VmCheck'
            SubStep = 'Server Name'
            Status = 'Failed'
            FriendlyError = "Please update the status of server $($VmObj.Name) in the SQL DB"
            PsError = $PSItem.Exception}) > $null 
        }
        else{
            $Validation.add([PSCustomObject]@{System = 'SQL'
            Step = 'VmCheck'
            SubStep = 'Server Name'
            Status = 'Passed'
            FriendlyError = ''
            PsError = ''}) > $null 
        }
    }
    catch 
    {
        $Validation.add([PSCustomObject]@{System = 'SQL'
        Step = 'VmCheck'
        SubStep = 'Server Name'
        Status = 'Failed'
        FriendlyError = "Could not login to $($sqlInstance). Please troubleshoot"
        PsError = $PSItem.Exception}) > $null 

        return $Validation
    }

    return $Validation, $connection
}