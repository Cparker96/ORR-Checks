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

    $agents1 = [System.Collections.ArrayList]@()
    $agents2 = [System.Collections.ArrayList]@()
    $agentinfo = [System.Collections.ArrayList]@()

    # get my API keys from the key vault, need to use these in the headers var but don't know the syntax
    $accessKey = Get-AzKeyVaultSecret -vaultName 'kv-308' -name 'TenableAccessKey' -AsPlainText
    $secretKey = Get-AzKeyVaultSecret -vaultName 'kv-308' -name 'TenableSecretKey' -AsPlainText
    
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

    $agentinfo = $agents1 + $agents2 | where {$_.name -eq 'TXAINFAZU999'}

    # if agent status is not online or initializing and not in weekly scans group
    if (($agentinfo.status -ne 'on') -or ($agentinfo.status -ne 'init') -and ($agentinfo.groups.name -notcontains 'WeeklyScans'))
    {
        Write-Host "Please check the agent for the server" -ForegroundColor Red
    } else {
        Write-Host "Server is configured for Tenable" -ForegroundColor Green
    }
}

Function TenableScan
{
    # list all AzureOnBoarding scan info
    $headers = $null
    $headers = New-Object "System.Collections.Generic.Dictionary[[String],[String]]"
    $resource = "https://cloud.tenable.com/scans"
    $headers.Add("X-ApiKeys", "accessKey=$accessKey; secretKey=$secretKey")
    $onboardingscans = (Invoke-RestMethod -Uri $resource -Method Get -Headers $headers).scans | where {$_.name -like "*AzureOnBoarding*"} | sort name

    foreach ($scan in $onboardingscans)
    {
        # find the agent group associated with the scan name
        $headers = $null
        $headers = New-Object "System.Collections.Generic.Dictionary[[String],[String]]"
        $resource = "https://cloud.tenable.com/scanners/1/agent-groups"
        $headers.Add("X-ApiKeys", "accessKey=$accessKey; secretKey=$secretKey")
        $agentgroup = (Invoke-RestMethod -Uri $resource -Method Get -Headers $headers).groups | where {$_.name -eq $scan.name}

        # get the latest scan status
        $headers = $null
        $headers = New-Object "System.Collections.Generic.Dictionary[[String],[String]]"
        $resource = "https://cloud.tenable.com/scans/$($scan.id)/latest-status"
        $headers.Add("X-ApiKeys", "accessKey=$accessKey; secretKey=$secretKey")
        $status = (Invoke-RestMethod -Uri $resource -Method Get -Headers $headers).status

        if (($status -notin 'running','pending'))
        {
            $headers = $null
            $headers = New-Object "System.Collections.Generic.Dictionary[[String],[String]]"
            $resource = "https://cloud.tenable.com/scanners/1/agent-groups/$($agentgroup.id)/agents/$($agentinfo.id)"
            $headers.Add("X-ApiKeys", "accessKey=$accessKey; secretKey=$secretKey")
            $addagent = Invoke-RestMethod -Uri $resource -Method Put -Headers $headers

            # launch the scan
            $headers = $null
            $headers = New-Object "System.Collections.Generic.Dictionary[[String],[String]]"
            $resource = "https://cloud.tenable.com/scans/$($scan.id)/launch"
            $headers.Add("X-ApiKeys", "accessKey=$accessKey; secretKey=$secretKey")
            $launchscan = Invoke-RestMethod -Uri $resource -Method Post -Headers $headers 

            Write-Host $scan.name "scan launched..." -ForegroundColor Green

            # check every 10 mins to see if the scan is completed
            do {
            Write-Host  $scan.name "scan is still running" -ForegroundColor Blue
            Start-Sleep -Seconds 600
            $headers = $null
            $headers = New-Object "System.Collections.Generic.Dictionary[[String],[String]]"
            $resource = "https://cloud.tenable.com/scans/$($scan.id)/latest-status"
            $headers.Add("X-ApiKeys", "accessKey=$accessKey; secretKey=$secretKey")
            $scanstatus = Invoke-RestMethod -Uri $resource -Method Get -Headers $headers 
            } until ($scanstatus.status -notin ('pending', 'running'))

            # if status is complete, go get all vulns. if not complete, scan failed go troubleshoot
            if ($scanstatus.status -eq 'completed')
            {
                $headers = $null
                $headers = New-Object "System.Collections.Generic.Dictionary[[String],[String]]"
                $resource = "https://cloud.tenable.com/scans/$($scan.id)"
                $headers.Add("X-ApiKeys", "accessKey=$accessKey; secretKey=$secretKey")
                $vulns = (Invoke-RestMethod -Uri $resource -Method Get -Headers $headers).vulnerabilities | where {($_.severity -ge 2) -and ($_.plugin_name -notlike "*McAfee*")}
                
                # remove agent from agent group
                $headers = $null
                $headers = New-Object "System.Collections.Generic.Dictionary[[String],[String]]"
                $resource = "https://cloud.tenable.com/scanners/1/agent-groups/$($agentgroup.id)/agents/$($agentinfo.id)"
                $headers.Add("X-ApiKeys", "accessKey=$accessKey; secretKey=$secretKey")
                $removeagent = Invoke-RestMethod -Uri $resource -Method Delete -Headers $headers
                Write-Host $agentinfo.name "was removed from" $scan.name -ForegroundColor Green

                Write-Host "Here is the list of vulnerabilities:" -ForegroundColor Yellow
                return $vulns
                break
            } else {
                Write-Host $scan.name "scan did not finish correctly. Please troubleshoot" -ErrorAction Stop -ForegroundColor Red
            }
        } else {
            Write-Host $scan.name "is already running. Checking the next one..." -ForegroundColor Yellow
            continue
        }
    }
}