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
        Modified by     : ...
        Date Modified   : ...

#>

Function Get-TenableCheck
{
    Param
    (
        [parameter(Position = 0, Mandatory=$true)] [Microsoft.Azure.Commands.Compute.Models.PSVirtualMachine] $VmObj,
        [parameter(Position = 1, Mandatory=$true)] [String] $TenableAccessKey,
        [parameter(Position = 2, Mandatory=$true)] [String] $TenableSecretKey
    )
    [System.Collections.ArrayList]$Validation = @()

    try 
    {
        # get scanner info
        $headers = $null
        $headers = New-Object "System.Collections.Generic.Dictionary[[String],[String]]"
        $resource = "your_tenable_endpoint"
        $headers.Add("X-ApiKeys", "accessKey=$TenableAccessKey; secretKey=$TenableSecretKey")
        $useastcloudscanner = (Invoke-RestMethod -Uri $resource -Method Get -Headers $headers).scanners | where {$_.name -eq 'your_scanner_group'}
    }
    catch {
        $validation.Add([PSCustomObject]@{System = 'Tenable'
        Step = 'TenableCheck'
        SubStep = 'Get Scanner Info'
        Status = 'Failed'
        FriendlyError = "Failed to fetch scanner info"
        PsError = $PSItem.Exception}) > $null

        return $Validation
    }

    try 
    {
        # get scan ID
        $headers = $null
        $headers = New-Object "System.Collections.Generic.Dictionary[[String],[String]]"
        $resource = "your_tenable_endpoint"
        $headers.Add("X-ApiKeys", "accessKey=$TenableAccessKey; secretKey=$TenableSecretKey")
        $weeklyscansgroup = (Invoke-RestMethod -Uri $resource -Method Get -Headers $headers).groups | where {$_.name -eq 'your_scan_name'}
    }
    catch {
        $validation.Add([PSCustomObject]@{System = 'Tenable'
        Step = 'TenableCheck'
        SubStep = 'Get scan Info'
        Status = 'Failed'
        FriendlyError = "Failed to fetch agent group info"
        PsError = $PSItem.Exception}) > $null

        return $Validation
    }

    try{
        # grab the agents in the agent group details
        $headers = $null
        $headers = New-Object "System.Collections.Generic.Dictionary[[String],[String]]"
        $resource = "your_tenable_endpoint"
        $headers.Add("X-ApiKeys", "accessKey=$TenableAccessKey; secretKey=$TenableSecretKey")
        $agentinfo = (Invoke-RestMethod -Uri $resource -Method Get -Headers $headers).agents

        # if agent status is not online or initializing and not in scan group
        if (($agentinfo.status -ne 'on') -or ($agentinfo.status -ne 'init') -and ($agentinfo.groups.name -notcontains 'your_scan_name'))
        {
            Write-Host "Please check the agent for the server" -ForegroundColor Red
            # add a row to the validation object for incorrect configuration in tenable
            $validation.Add([PSCustomObject]@{System = 'Tenable'
            Step = 'TenableCheck'
            SubStep = 'Tenable Configuration'
            Status = 'Failed'
            FriendlyError = "Please check the agent for the server"
            PsError = $PSItem.Exception}) > $null
        } else {
            # add a row to the vailidation for correct configuration
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
