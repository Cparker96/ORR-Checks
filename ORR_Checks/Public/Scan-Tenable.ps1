<#
    .SYNOPSIS
        Scan Tenable
    .DESCRIPTION
        This Function Starts a tenable scan in the tenable application
    .PARAMETER Environment
        the access key and the secret key for Tenable API
    .EXAMPLE

    .NOTES
        FunctionName    : Scan-Tenable
        Created by      : Cody Parker
        Date Coded      : 07/7/2021
        Modified by     : ...
        Date Modified   : ...

#>
Function Scan-Tenable
{
    Param
    (
        [parameter(Position = 0, Mandatory=$true)] [Microsoft.Azure.Commands.Compute.Models.PSVirtualMachine] $VMobj,
        [parameter(Position = 1, Mandatory=$true)] [String] $TenableAccessKey,
        [parameter(Position = 2, Mandatory=$true)] [String] $TenableSecretKey,
        [parameter(Position = 3, Mandatory=$true)] $agentinfo
    )
    [System.Collections.ArrayList]$Validation = @()
    $targetip = (Get-AzNetworkInterface -ResourceId $VMobj.NetworkProfile.NetworkInterfaces.Id).IpConfigurations.PrivateIpAddress
    
    # if agent info isn't populated then fail the scan
    if ($null -eq $agentinfo){
        $validation.Add([PSCustomObject]@{System = 'Tenable'
        Step = 'TenableCheck'
        SubStep = 'Validate Agent Info'
        Status = 'Failed'
        FriendlyError = "Failed to find agent in Tenable"
        PsError = $PSItem.Exception}) > $null
    } else {
        $validation.Add([PSCustomObject]@{System = 'Tenable'
        Step = 'TenableCheck'
        SubStep = 'Validate Agent Info'
        Status = 'Passed'
        FriendlyError = ""
        PsError = ''}) > $null
    }

    try 
    {
        # get scanner info
        $headers = $null
        $headers = New-Object "System.Collections.Generic.Dictionary[[String],[String]]"
        $resource = "your_tenable_endpoint"
        $headers.Add("X-ApiKeys", "accessKey=$TenableAccessKey; secretKey=$TenableSecretKey")
        $useastcloudscanner = (Invoke-RestMethod -Uri $resource -Method Get -Headers $headers).scanners | where {$_.name -eq 'your_scan_group'}

        # get scanner info
        $headers = $null
        $headers = New-Object "System.Collections.Generic.Dictionary[[String],[String]]"
        $headers.Add('Accept', 'application/json')
        $resource = "your_tenable_endpoint"
        $headers.Add("X-ApiKeys", "accessKey=$TenableAccessKey; secretKey=$TenableSecretKey")
        $txtonpremscanner = (Invoke-RestMethod -Uri $resource -Method Get -Headers $headers).scanners | where {$_.name -eq 'your_scan_group'}

        # list all scan info
        $headers = $null
        $headers = New-Object "System.Collections.Generic.Dictionary[[String],[String]]"
        $resource = "your_tenable_endpoint"
        $headers.Add("X-ApiKeys", "accessKey=$TenableAccessKey; secretKey=$TenableSecretKey")
        $azureonboardingscans = (Invoke-RestMethod -Uri $resource -Method Get -Headers $headers).scans | where {$_.name -like "*your_scan"} | sort name

        if (($null -eq $useastcloudscanner) -or ($null -eq $txtonpremscanner) -or ($null -eq $azureonboardingscans))
        {
            $Validation.Add([PSCustomObject]@{System = 'Tenable' 
            Step = 'TenableCheck'
            Substep = 'Scan info'
            Status = 'Failed'
            FriendlyError = "Failed to gather scan and scanner information"
            PsError = $PSItem.Exception}) > $null
        } else {
            $Validation.Add([PSCustomObject]@{System = 'Tenable' 
            Step = 'TenableCheck'
            Substep = 'Scan info'
            Status = 'Passed'
            FriendlyError = ""
            PsError = ''}) > $null  
        }
    } catch {
        $Validation.Add([PSCustomObject]@{System = 'Tenable' 
        Step = 'TenableCheck'
        Substep = 'Scan info'
        Status = 'Failed'
        FriendlyError = "Failed to authenticate and gather scan metadata"
        PsError = $PSItem.Exception}) > $null

        return $Validation
    }

    foreach ($scan in $azureonboardingscans)
    {
        try 
        {
            # get the latest scan status
            Write-Host "Getting the status for $($scan.name)" -ForegroundColor Yellow
            $headers = $null
            $headers = New-Object "System.Collections.Generic.Dictionary[[String],[String]]"
            $resource = "your_tenable_endpoint"
            $headers.Add("X-ApiKeys", "accessKey=$TenableAccessKey; secretKey=$TenableSecretKey")
            $prescanstatus = (Invoke-RestMethod -Uri $resource -Method Get -Headers $headers).status

            if (($prescanstatus -eq 'pending') -or ($prescanstatus -eq 'running') -or ($prescanstatus -eq 'stopping'))
            {
                Write-Host "$($scan.name) is not ready to scan yet. Checking the next one..." -ForegroundColor Yellow 
                continue

            } else {
                $Validation.Add([PSCustomObject]@{System = 'Tenable' 
                Step = 'TenableCheck'
                Substep = 'Pre-Scan status'
                Status = 'Passed'
                FriendlyError = ""
                PsError = ''}) > $null 
            }
        } catch {
            $Validation.Add([PSCustomObject]@{System = 'Tenable' 
            Step = 'TenableCheck'
            Substep = 'Pre-Scan status'
            Status = 'Failed'
            FriendlyError = "Failed to gather pre-scan status for $($scan.name)"
            PsError = $PSItem.Exception}) > $null

            return $Validation
        }

        try 
        {
            # change target ip of the scan to the machine
            $headers = $null
            $headers = New-Object "System.Collections.Generic.Dictionary[[String],[String]]"
            $resource = "your_tenable_endpoint"
            $headers.Add("X-ApiKeys", "accessKey=$TenableAccessKey; secretKey=$TenableSecretKey")
            $body = @{
                "settings" = @{
                    "scanner_id" = "$($txtonpremscanner.id)"
                    "text_targets" = "$($targetip)"
                }  
            } | ConvertTo-Json
            $changetarget = Invoke-RestMethod -Uri $resource -ContentType "application/json" -Method Put -Headers $headers -Body $body

            # giving the API time to visually update for confirmation
            Start-Sleep -Seconds 60

            if ($changetarget.custom_targets -eq $targetip)
            {
                $Validation.Add([PSCustomObject]@{System = 'Tenable' 
                Step = 'TenableCheck'
                Substep = 'Change Target IP'
                Status = 'Passed'
                FriendlyError = ""
                PsError = ''}) > $null 
            } else {
                $Validation.Add([PSCustomObject]@{System = 'Tenable' 
                Step = 'TenableCheck'
                Substep = 'Change Target IP'
                Status = 'Failed'
                FriendlyError = "Could not change target IP field to match server IP"
                PsError = $PSItem.Exception}) > $null 
            }
        }
        catch {
            $Validation.Add([PSCustomObject]@{System = 'Tenable' 
            Step = 'TenableCheck'
            Substep = 'Change Target IP'
            Status = 'Failed'
            FriendlyError = "Failed to change target IP. Please try again"
            PsError = $PSItem.Exception}) > $null 

            return $Validation
        }

        try 
        {
            # launch the scan
            $headers = $null
            $headers = New-Object "System.Collections.Generic.Dictionary[[String],[String]]"
            $resource = "your_tenable_endpoint"
            $headers.Add("X-ApiKeys", "accessKey=$TenableAccessKey; secretKey=$TenableSecretKey")
            $launchscan = Invoke-RestMethod -Uri $resource -Method Post -Headers $headers

            # giving the API time to visually update for confirmation
            Start-Sleep -Seconds 20

            if ($null -ne $launchscan.scan_uuid)
            {
                $Validation.Add([PSCustomObject]@{System = 'Tenable' 
                Step = 'TenableCheck'
                Substep = 'Launch Scan'
                Status = 'Passed'
                FriendlyError = ''
                PsError = ''}) > $null 

                Write-Host "$($scan.name) was successfully launched" -ForegroundColor Green
            } else {
                $Validation.Add([PSCustomObject]@{System = 'Tenable' 
                Step = 'TenableCheck'
                Substep = 'Launch Scan'
                Status = 'Failed'
                FriendlyError = "Could not launch scan for $($VMobj.Name)"
                PsError = $PSItem.Exception}) > $null 
            }
        } catch {
            $Validation.Add([PSCustomObject]@{System = 'Tenable' 
            Step = 'TenableCheck'
            Substep = 'Launch Scan'
            Status = 'Failed'
            FriendlyError = "Failed to launch Tenable scan"
            PsError = $PSItem.Exception}) > $null 

            return $Validation
        }

        # check initial scan status
        $headers = $null
        $headers = New-Object "System.Collections.Generic.Dictionary[[String],[String]]"
        $resource = "your_tenable_endpoint"
        $headers.Add("X-ApiKeys", "accessKey=$TenableAccessKey; secretKey=$TenableSecretKey")
        $scanstatus = Invoke-RestMethod -Uri $resource -Method Get -Headers $headers 

        start-sleep -Seconds 10

        # check every 10 mins to see if the scan is completed
        while (($scanstatus.status -eq 'pending') -or ($scanstatus.status -eq 'running')) {
        Write-Host  $scan.name "scan is still running" -ForegroundColor Blue
        Start-Sleep -Seconds 600
        $headers = $null
        $headers = New-Object "System.Collections.Generic.Dictionary[[String],[String]]"
        $resource = "your_tenable_endpoint"
        $headers.Add("X-ApiKeys", "accessKey=$TenableAccessKey; secretKey=$TenableSecretKey")
        $scanstatus = Invoke-RestMethod -Uri $resource -Method Get -Headers $headers  
        }

        try 
        {
            # get the latest scan status
            $headers = $null
            $headers = New-Object "System.Collections.Generic.Dictionary[[String],[String]]"
            $resource = "your_tenable_endpoint"
            $headers.Add("X-ApiKeys", "accessKey=$TenableAccessKey; secretKey=$TenableSecretKey")
            $postscanstatus = (Invoke-RestMethod -Uri $resource -Method Get -Headers $headers).status

            if ($postscanstatus -eq 'completed')
            {
                Write-Host "$($scan.Name) has successfully completed" -ForegroundColor Green
                # get all vulns from scan results
                $headers = $null
                $headers = New-Object "System.Collections.Generic.Dictionary[[String],[String]]"
                $resource = "your_tenable_endpoint"
                $headers.Add("X-ApiKeys", "accessKey=$TenableAccessKey; secretKey=$TenableSecretKey")       
                $vulns = (Invoke-RestMethod -Uri $resource -Method Get -Headers $headers).vulnerabilities | where {($_.severity -ge 2) -and ($_.plugin_name -notlike "*McAfee*")}
            } else {
                Write-Host "$($scan.Name) was interruped by someone or another operation" -ForegroundColor Red

                $Validation.Add([PSCustomObject]@{System = 'Tenable' 
                Step = 'TenableCheck'
                Substep = 'Scan Status'
                Status = 'Failed'
                FriendlyError = "$($scan.name) was interrupted by someone or other operation. Please try again"
                PsError = $PSItem.Exception}) > $null 
            }

            if ($vulns.count -eq 0)
            {
                $Validation.Add([PSCustomObject]@{System = 'Tenable' 
                Step = 'TenableCheck'
                Substep = 'Check Vulns'
                Status = 'Passed'
                FriendlyError = ''
                PsError = ''}) > $null 

                break
            } else {
                $Validation.Add([PSCustomObject]@{System = 'Tenable' 
                Step = 'TenableCheck'
                Substep = 'Check vulns'
                Status = 'Failed'
                FriendlyError = 'There were multiple vulnerabilities found on the scan'
                PsError = $PSItem.Exception}) > $null 

                break
            }
        }
        catch {
            $Validation.Add([PSCustomObject]@{System = 'Tenable' 
            Step = 'TenableCheck'
            Substep = 'Check Vulns'
            Status = 'Failed'
            FriendlyError = 'Failed to get post scan status. Please try again'
            PsError = $PSItem.Exception}) > $null 

            break

            return $Validation
        }
    }
    return $Validation, $vulns
}