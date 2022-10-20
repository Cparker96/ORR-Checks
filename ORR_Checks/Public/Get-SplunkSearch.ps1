<#
    .SYNOPSIS
        Validate that a server is configured for logs in Splunk
    .DESCRIPTION
        This function authenticates into Splunk and retrieves one log within the last hour of the server reporting
    .PARAMETER Environment
        The $URL, $Key, and $Sid variables to be used to authenticate and perform a search 
    .EXAMPLE

    .NOTES
        FunctionName    : Get-SplunkCheck
        Created by      : Cody Parker
        Date Coded      : 09/07/2021
        Modified by     : Cody Parker
        Date Modified   : 10/18/2022

#>

function Get-SplunkSearch 
{      
    [CmdletBinding()]
    Param
    (
        [Parameter(Mandatory=$true)]$VmObj,
        [Parameter(Mandatory=$true)] $SplunkCredential,
        [Parameter(Mandatory=$true)][ValidateNotNull()][string]$Key
    )

    # declare endpoint and variables
    $SearchUrl = "https://textron.splunkcloud.com:8089/services/search/jobs"
    $username = $SplunkCredential.UserName
    $password = $SplunkCredential.GetNetworkCredential().Password
    [System.Collections.ArrayList]$Validation = @()

    Write-Host "Querying Splunk for server logs"
    if ($VmObj.Name -like "*IDC*") # if a domain controller - will always be windows
    {
        $Searchstring = "search index=win_event_dc* host=$($VmObj.Name) earliest=-60m | head 1"
    }

    #change the search string based on the OS type
    If($vmobj.StorageProfile.OsDisk.OsType -eq 'Windows') # if a windows server
    {
        $Searchstring = "search index=win_event* host=$($VmObj.Name) earliest=-60m | head 1"
    }
    elseif($vmobj.StorageProfile.OsDisk.OsType -eq 'Linux') # if a Linux server
    {
        $Searchstring = "search index=syslog* host=$($VmObj.Name) earliest=-60m | head 1"
    }
    else{
        Write-Error "Can not determine OS image on Azure VM object" -ErrorAction Stop
    }

    $usercreds = "${username}:${password}"

    # need to regex to get the sid
    [regex]$Jobsid = "(?<=<sid>)(.*)(?=<\/sid>)"

    #### THE OLD WAY OF DOING THINGS - WHEN SPLUNK WAS ON PREM AND USING POWERSHELL ####
    # $onehourago = (Get-Date).AddHours(-1)
    # $rightnow = Get-Date
    # $startdate = [int64](($onehourago.ToUniversalTime()) - (get-date "1/1/1970")).TotalSeconds
    # $enddate = [int64](($rightnow.ToUniversalTime()) - (get-date "1/1/1970")).TotalSeconds

    # $Auth = @{'Authorization'=$Key}
    # $Body = @{
    #     'search' = $Searchstring
    #     'earliest_time' = $startdate
    #     'latest_time' = $enddate

    $SearchContent = (curl -u $usercreds -k $SearchUrl -d search=$searchstring)

    if($SearchContent) 
    {
        $Sid = $Jobsid.Match($SearchContent).Value.ToString()
        
        $validation.Add([PSCustomObject]@{System = 'Splunk'
        Step = 'SplunkCheck'
        SubStep = 'Validate Splunk search'
        Status = 'Passed'
        FriendlyError = ''
        PsError = ''}) > $null
    } 
    elseif (!$SearchContent -OR !$Sid) 
    {
        $validation.Add([PSCustomObject]@{System = 'Splunk'
        Step = 'SplunkCheck'
        SubStep = 'Validate Splunk search'
        Status = 'Failed'
        FriendlyError = 'Could not retrieve Splunk search'
        PsError = $PSItem.Exception}) > $null
    }

    Start-Sleep -Seconds 20
    
    return $validation, $Sid
}

