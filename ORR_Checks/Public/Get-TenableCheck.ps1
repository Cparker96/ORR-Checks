<#
    .SYNOPSIS
        Validate that Tenable is configured correctly on a server
    .DESCRIPTION
        This function authenticates into Tenable and validates that the Nessus Agent on a server is configured and 
        reporting into Tenable correctly.
    .PARAMETER Environment
        The $VmObj variable which pulls in metadata from the server 
    .EXAMPLE

    .NOTES
        FunctionName    : Get-TenableCheck
        Created by      : Cody Parker
        Date Coded      : 07/7/2021
        Modified by     : 
        Date Modified   : 

#>

Function Get-TenableCheck
{
    Param
    (
        [parameter(Position = 0, Mandatory=$true)] [Microsoft.Azure.Commands.Compute.Models.PSVirtualMachine] $VmObj,
        [parameter(Position = 1, Mandatory=$true)] [String] $AccessKey,
        [parameter(Position = 2, Mandatory=$true)] [String] $SecretKey
    )
    [System.Collections.ArrayList]$Validation = @()
    $agents1 = [System.Collections.ArrayList]@()
    $agents2 = [System.Collections.ArrayList]@()
    $agentinfo = [System.Collections.ArrayList]@()


    try{
        # grab the agents in the agent group 'WeeklyScans' details
        $headers = $null
        $headers = New-Object "System.Collections.Generic.Dictionary[[String],[String]]"
        $resource = "https://cloud.tenable.com/scanners/1/agent-groups/101288/agents?offset=0&limit=5000"
        $headers.Add("X-ApiKeys", "accessKey=$accessKey; secretKey=$secretKey")
        $agents1 = (Invoke-RestMethod -Uri $resource -Method Get -Headers $headers).agents

        # grab the agents in the agent group 'WeeklyScans' details
        $headers = $null
        $headers = New-Object "System.Collections.Generic.Dictionary[[String],[String]]"
        $resource = "https://cloud.tenable.com/scanners/1/agent-groups/101288/agents?offset=5001&limit=5000"
        $headers.Add("X-ApiKeys", "accessKey=$accessKey; secretKey=$secretKey")
        $agents2 = (Invoke-RestMethod -Uri $resource -Method Get -Headers $headers).agents

        $agentinfo = $agents1 + $agents2 | where {$_.name -eq $VmObj.Name}

        # if agent status is not online or initializing and not in weekly scans group
        if (($agentinfo.status -ne 'on') -or ($agentinfo.status -ne 'init') -and ($agentinfo.groups.name -notcontains 'WeeklyScans'))
        {
            Write-Host "Please check the agent for the server" -ForegroundColor Red
            #add a row to the vailidation object for incorrect configuration in tenable
            $validation.Add([PSCustomObject]@{System = 'Tenable'
            Step = 'TenableCheck'
            SubStep = 'Tenable Configuration'
            Status = 'Failed'
            FriendlyError = "Please check the agent for the server"
            PsError = ""}) > $null
        } else {
            #add a row to the vailidation for correct configuration
            $validation.Add([PSCustomObject]@{System = 'Tenable'
            Step = 'TenableCheck'
            SubStep = 'Tenable Configuration'
            Status = 'Passed'
            FriendlyError = ""
            PsError = ''}) > $null
        }
    }catch{
        $validation.Add([PSCustomObject]@{System = 'Tenable'
        Step = 'TenableCheck'
        SubStep = 'Tenable Configuration'
        Status = 'Failed'
        FriendlyError = "Please check the agent for the server"
        PsError = $PSItem.Exception}) > $null

        return $validation
    }

    return ($validation, $agentinfo)
}
