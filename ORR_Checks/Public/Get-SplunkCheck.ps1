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
        Date Coded      : 09/7/2021
        Modified by     : 
        Date Modified   : 

#>
function get-SplunkAuth
{
    [CmdletBinding()]
    Param
    (
        [Parameter(Mandatory=$true)][Uri]$Url, 
        [Parameter(Mandatory=$true)] $SplunkCredential
    )
    $username = $SplunkCredential.UserName
    $password = $SplunkCredential.GetNetworkCredential().Password
    [System.Collections.ArrayList]$Validation = @()

    $Headers = @{
        'username'=$username
        'password'=$password
    }

    $Loginurl = $url.AbsoluteUri + "services/auth/login"
    [regex]$sessionKey = "(?<=<sessionKey>)(.*)(?=<\/sessionKey>)"

    $Content = (Invoke-WebRequest -uri $Loginurl -Method Post -Body $Headers -ContentType "application/json" -UseBasicParsing -ErrorAction Stop).content   

    if($Content) {
    $Key = "Splunk " + $sessionKey.Match($content).Value

    $validation.Add([PSCustomObject]@{System = 'Splunk'
    Step = 'SplunkCheck'
    SubStep = 'Validate Authentication'
    Status = 'Passed'
    FriendlyError = ''
    PsError = ''}) > $null
    } 
    elseif (!$Content -OR !$Key) {
    $validation.Add([PSCustomObject]@{System = 'Splunk'
    Step = 'SplunkCheck'
    SubStep = 'Validate Authentication'
    Status = 'Failed'
    FriendlyError = 'Could not authenticate to Splunk'
    PsError = $PSItem.Exception}) > $null
    }
    return $validation, $Key
}

function get-SplunkSearch 
{      
    [CmdletBinding()]
    Param
    (
        [Parameter(Mandatory=$true)]$VmObj,
        [Parameter(Mandatory=$true)][Uri]$Url,
        [Parameter(Mandatory=$true)][ValidateNotNull()][string]$Key
    )
    [System.Collections.ArrayList]$Validation = @()

    #change the search string based on the OS type
    If($vmobj.StorageProfile.OsDisk.OsType -eq 'Windows') #if a windows server
    {
        $Searchstring = "search index=win_event* host=$($VmObj.Name) earliest=-60m | head 1"
    }
    elseif($vmobj.StorageProfile.OsDisk.OsType -eq 'Linux') #if a Linux server
    {
        $Searchstring = "search index=syslog* host=$($VmObj.Name) earliest=-60m | head 1"
    }
    else{
        Write-Error "Can not determine OS image on Azure VM object" -ErrorAction Stop
    }

    $Searchurl = $url.AbsoluteUri + "services/search/jobs"
    [regex]$Jobsid = "(?<=<sid>)(.*)(?=<\/sid>)"

    $onehourago = (Get-Date).AddHours(-1)
    $rightnow = Get-Date
    $startdate = [int64](($onehourago.ToUniversalTime()) - (get-date "1/1/1970")).TotalSeconds
    $enddate = [int64](($rightnow.ToUniversalTime()) - (get-date "1/1/1970")).TotalSeconds

    $Auth = @{'Authorization'=$Key}
    $Body = @{
        'search' = $Searchstring
        'earliest_time' = $startdate
        'latest_time' = $enddate
    }

    $Content = (Invoke-WebRequest -uri $Searchurl -Method Post -Headers $Auth -Body $Body -ContentType "application/json" -UseBasicParsing -ErrorAction Stop).content

    if($Content) {
    $Sid = $Jobsid.Match($Content).Value.ToString()
    
    $validation.Add([PSCustomObject]@{System = 'Splunk'
    Step = 'SplunkCheck'
    SubStep = 'Validate Splunk search'
    Status = 'Passed'
    FriendlyError = ''
    PsError = ''}) > $null
    } 
    elseif (!$Content -OR !$Sid) {
    $validation.Add([PSCustomObject]@{System = 'Splunk'
    Step = 'SplunkCheck'
    SubStep = 'Validate Splunk search'
    Status = 'Failed'
    FriendlyError = 'Could not retrieve Splunk search'
    PsError = $PSItem.Exception}) > $null
    }
    return $validation, $Sid
}

function Get-SplunkResult 
{
    [CmdletBinding()]
    Param
    (
        [Parameter(Mandatory=$true)][Uri]$Url,
        [Parameter(Mandatory=$true)][ValidateNotNull()][string]$Key,
        [Parameter(Mandatory=$true)][ValidateNotNull()][string]$Sid
    )
    [System.Collections.ArrayList]$Validation = @()

    $JobResultUrl = $Url.AbsoluteUri + ("services/search/jobs/{0}/results?output_mode=json&count=0" -f $Sid)

    $Auth = @{'Authorization'=$Key}

    $Content = (Invoke-WebRequest -uri $JobResultUrl -Method Get -Headers $Auth -ContentType "application/json" -UseBasicParsing  -ErrorAction Stop).content

    Start-Sleep -Seconds 5

    if($Content) {

    $validation.Add([PSCustomObject]@{System = 'Splunk'
    Step = 'SplunkCheck'
    SubStep = 'Validate Splunk Log'
    Status = 'Passed'
    FriendlyError = ''
    PsError = ''}) > $null
    } 
    else {
    $validation.Add([PSCustomObject]@{System = 'Splunk'
    Step = 'SplunkCheck'
    SubStep = 'Validate Splunk Log'
    Status = 'Failed'
    FriendlyError = 'Could not retrieve logs for Splunk'
    PsError = $PSItem.Exception}) > $null
    }
    return $validation, $Content
}
