<#
    .SYNOPSIS
        Validate that Tenable is configured correctly on a server
    .DESCRIPTION
        This function authenticates into Tenable and validates that the Nessus Agent on a server is configured and 
        reporting into Tenable correctly.
    .PARAMETER Environment
        The $VmName variable which pulls in metadata from the server 
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
    # Param
    # (
    #     [parameter(Position = 0, Mandatory=$true)] [Microsoft.Azure.Commands.Compute.Models.PSVirtualMachine] $VmObj
    # )
    Connect-AzAccount -Environment AzureCloud
    Set-AzContext -Subscription Enterprise

    # get my API keys from the key vault, need to use these in the headers var but don't know the syntax
    $accessKey = Get-AzKeyVaultSecret -vaultName 'kv-308' -name 'TenableAccessKey' -AsPlainText
    $secretKey = Get-AzKeyVaultSecret -vaultName 'kv-308' -name 'TenableSecretKey' -AsPlainText
    
    # grab the agents in the agent group 'WeeklyScans' details
    $headers = $null
    $headers = New-Object "System.Collections.Generic.Dictionary[[String],[String]]"
    $resource = "https://cloud.tenable.com/scanners/1/agent-groups/102143/agents?offset=0&limit=5000"
    $headers.Add("X-ApiKeys", "accessKey=$accessKey; secretKey=$secretKey")
    $agent = (Invoke-RestMethod -Uri $resource -Method Get -Headers $headers).agents | where {$_.name -eq 'TXAINFAZU027'}

    # if agent status is not online
    if (($agent.status -ne 'on') -and ($agent.groups.name -notcontains 'WeeklyScans'))
    {
        Write-Host "Please check the agent for the server" -ForegroundColor Red
    } else {
        Write-Host "Server is configured for Tenable" -ForegroundColor Green
    }
}

Function TenableScan
{
    # launch the scan
    $headers = $null
    $headers = New-Object "System.Collections.Generic.Dictionary[[String],[String]]"
    $resource = "https://cloud.tenable.com/scans/319/launch"
    $headers.Add("X-ApiKeys", "accessKey=$accessKey; secretKey=$secretKey")
    $scan = Invoke-RestMethod -Uri $resource -Method Post -Headers $headers 

    # check every 10 mins to see if the scan is completed
    do {
    Write-Host "Scan is running" -ForegroundColor Blue
    Start-Sleep -Seconds 600
    $headers = $null
    $headers = New-Object "System.Collections.Generic.Dictionary[[String],[String]]"
    $resource = "https://cloud.tenable.com/scans/319/latest-status"
    $headers.Add("X-ApiKeys", "accessKey=$accessKey; secretKey=$secretKey")
    $status = Invoke-RestMethod -Uri $resource -Method Get -Headers $headers 
    } until ($status.status -notin ('pending', 'running'))

    # if status is complete, go get all vulns. if not complete, scan failed go troubleshoot
    if ($status.status -eq 'completed')
    {
       # get all hosts in the scan first
       $headers = $null
       $headers = New-Object "System.Collections.Generic.Dictionary[[String],[String]]"
       $resource = "https://cloud.tenable.com/scans/319/"
       $headers.Add("X-ApiKeys", "accessKey=$accessKey; secretKey=$secretKey")
       $machines = (Invoke-RestMethod -Uri $resource -Method Get -Headers $headers).hosts | select hostname, uuid

       # after scan is done, show vulns by asset
       foreach ($thing in $machines)
       {
           if ($thing.hostname = $VmObj.Name)
           {
               Write-Host "Showing vulnerabilities for" $thing.hostname -ForegroundColor Yellow
               $assetid = $thing.uuid
               $headers = $null
               $headers = New-Object "System.Collections.Generic.Dictionary[[String],[String]]"
               $resource = "https://cloud.tenable.com/workbenches/assets/${assetid}/vulnerabilities"
               $headers.Add("X-ApiKeys", "accessKey=$accessKey; secretKey=$secretKey")
               $vulns = (Invoke-RestMethod -Uri $resource -Method Get -Headers $headers).vulnerabilities | where {($_.severity -ge 2) -and ($_.plugin_name -notlike "*McAfee*")}
               return $vulns 
           }
       }
    } else {
        Write-Host "Scan did not finish correctly. Please troubleshoot" -ErrorAction Stop -ForegroundColor Red
    }
    
    # take the agent out of the AzureOnBoarding group, signaling that all vulns have been remediated
}


