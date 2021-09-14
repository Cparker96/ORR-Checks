<#
    .SYNOPSIS
        Scan Tenable
    .DESCRIPTION
        This Function Starts a tenable scan in the tenable application
    .PARAMETER Environment
        the access key and the secret key for Tennable API
    .EXAMPLE

    .NOTES
        FunctionName    : Scan-Tenable
        Created by      : Cody Parker
        Date Coded      : 07/7/2021
        Modified by     : 
        Date Modified   : 

#>
Function Scan-Tenable
{
    Param
    (
        [parameter(Position = 0, Mandatory=$true)] [String] $AccessKey,
        [parameter(Position = 1, Mandatory=$true)] [String] $SecretKey
    )
    [System.Collections.ArrayList]$Validation = @()
    try{
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


                    #add a row to the vailidation for correct configuration
                    $validation.Add([PSCustomObject]@{System = 'Tenable'
                    Step = 'TenableCheck'
                    SubStep = 'Tenable Scan'
                    Status = 'Passed'
                    FriendlyError = "" 
                    PsError = ''}) > $null
                    
                    return ($validation, $vulns)
                    break
                } else {
                    $validation.Add([PSCustomObject]@{System = 'Tenable'
                    Step = 'TenableCheck'
                    SubStep = 'Tenable Scan'
                    Status = 'Failed'
                    FriendlyError = "scan did not finish correctly. Please troubleshoot"
                    PsError = $PSItem.Exception}) > $null

                    return $validation
                }
            } else {
                #check the next scan group

                #if all scan groups are busy fail
                if($onboardingscans[$onboardingscans.legnth -1])
                {
                    $validation.Add([PSCustomObject]@{System = 'Tenable'
                    Step = 'TenableCheck'
                    SubStep = 'Tenable Scan'
                    Status = 'Failed'
                    FriendlyError = "All Scan Groups are currently busy. Please wait for a Scan group to Complete"
                    PsError = ''}) > $null

                    return $validation
                }
                
                continue
            }
        }
    }catch{
        $validation.Add([PSCustomObject]@{System = 'Tenable'
        Step = 'TenableCheck'
        SubStep = 'Tenable Scan'
        Status = 'Failed'
        FriendlyError = "Failed to Authenticate with Tenable"
        PsError = $PSItem.Exception}) > $null

        return $validation
    }
}