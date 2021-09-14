<#
    .SYNOPSIS
        Validate that a server is configured for logs in Splunk
    .DESCRIPTION
        This function authenticates into Splunk and retrieves one log within the last hour of the server reporting
    .PARAMETER Environment
        The $URL, $Key, and $Sid variables to be used to authenticate and perform a search 
        $Url = "https://splk.textron.com:8089"
        $username = 'svc_tis_midrange'
        $password = (Get-AzKeyVaultSecret -VaultName 'kv-308' -Name 'ORRChecks-Splunk').SecretValue | ConvertFrom-SecureString -AsPlainText
    .EXAMPLE
    Splunk-Auth $Url $SplunkCredential
    Splunk-Result $Url [string]$Key [string]$Sid
    Splunk-Search $Url, [string]$Key

    .NOTES
        FunctionName    : Get-SplunkCheck
        Created by      : Cody Parker
        Date Coded      : 09/7/2021
        Modified by     : 
        Date Modified   : 

#>
function Splunk-Auth
{
    [CmdletBinding()]
    Param
    (
        [Parameter(Mandatory=$true)][Uri]$Url,
        [Parameter(Mandatory=$true)] $SplunkCredential
    )
    $username = $SplunkCredential.UserName
    $password = $SplunkCredential.GetNetworkCredential().Password
    
    $Headers = @{
        'username'=$username
        'password'=$password
    }

    $Loginurl = $url.AbsoluteUri + "services/auth/login"
    [regex]$sessionKey = "(?<=<sessionKey>)(.*)(?=<\/sessionKey>)"

    $Content = (Invoke-WebRequest -uri $Loginurl -Method Post -Body ($Headers) -ContentType "application/json" -UseBasicParsing -ErrorAction Stop).content

    if($Content) {
    #the purpose of "$script:Key" is to make the $Key variable available to be used dynamically with other functions
    $script:Key = "Splunk " + $sessionKey.Match($content).Value
    }
    elseif (!$Content -OR !$Key) {
    write-error "Error. No valid key returned by $Loginurl" -ErrorAction Stop
    }
    return $Key
}


function Splunk-Result 
{
    [CmdletBinding()]
    Param
    (
        [Parameter(Mandatory=$true)][Uri]$Url,
        [Parameter(Mandatory=$true)][ValidateNotNull()][string]$Key,
        [Parameter(Mandatory=$true)][ValidateNotNull()][string]$Sid
    )

    $JobResultUrl = $Url.AbsoluteUri + ("services/search/jobs/{0}/results?output_mode=json&count=0" -f $Sid)

    $Auth = @{'Authorization'=$Key}

    do{
        try {
        $Content = (Invoke-WebRequest -uri $JobResultUrl -Method Get -Headers $Auth -UseBasicParsing -ErrorAction Stop).content
        
        if($Content) {
            return ($Content | ConvertFrom-Json).results
            }
        }
        catch {
            throw $Error[0].Exception
        }
    }while($null -eq $content)

    <#if($Content) {
    return ($Content | ConvertFrom-Json).results
    }
    else {
    write-error "Error. No valid jobstate returned by $($JobResultUrl)" -ErrorAction Stop
    }#>
}


function Get-SplunkCheck
{      
    [CmdletBinding()]
    Param
    (
        [Parameter(Mandatory=$true)]$VMobj,
        [Parameter(Mandatory=$true)] [Uri] $Url,
        [Parameter(Mandatory=$true)][ValidateNotNull()]$SplunkCredential
    )
    [System.Collections.ArrayList]$Validation = @()
    $splunkresults = @()

    #call the Splunk-Auth function to get the keys for authentication
    try{
        $key = @()
        $key = Splunk-Auth -Url $url -SplunkCredential $SplunkCredential
    }catch{
        $validation.Add([PSCustomObject]@{System = 'Splunk'
        Step = 'SplunkCheck'
        SubStep = 'Validate Log Forwarding'
        Status = 'Failed'
        FriendlyError = 'Could not Authenticate to splunk'
        PsError = $PSItem.Exception}) > $null

        return $validation
    }

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
    
    try 
    {
        $Content = (Invoke-WebRequest -uri $Searchurl -Method Post -Headers $Auth -Body $Body -ContentType "application/json" -UseBasicParsing -ErrorAction Stop).content
    }
    catch 
    {
        $validation.Add([PSCustomObject]@{System = 'Splunk'
        Step = 'SplunkCheck'
        SubStep = 'Validate Log Forwarding'
        Status = 'Failed'
        FriendlyError = 'Splunk did not accept the search'
        PsError = $PSItem.Exception}) > $null

        return $validation
    }
        
    if($Content) {
    $script:Sid = $Jobsid.Match($Content).Value.ToString()
    }elseif (!$Content -OR !$Sid) {
    write-error "Error. No valid sid returned by $Searchurl"
    }

    # get the result of the search
    do{
        TRY{
            Start-Sleep -Seconds 2
            $splunkresults = Splunk-Result -Url $url -Key $key -Sid $sid
        }Catch{
            $validation.Add([PSCustomObject]@{System = 'Splunk'
            Step = 'SplunkCheck'
            SubStep = 'Validate Log Forwarding'
            Status = 'Failed'
            FriendlyError = 'Could not find Search Result'
            PsError = $PSItem.Exception}) > $null

            return $validation
        }
    }While($null -eq $splunkresults)

    #check the results and make sure you get results
    if($splunkresults.host -eq $($VmObj.Name)){
        $Validation.Add([PSCustomObject]@{System = 'Splunk'
        Step = 'SplunkCheck'
        SubStep = 'Validate Log Forwarding'
        Status = 'Passed'
        FriendlyError = ''
        PsError = ''}) > $null
    }else {
        $Validation.Add([PSCustomObject]@{System = 'Splunk'
        Step = 'SplunkCheck'
        SubStep = 'Validate Log Forwarding'
        Status = 'Failed'
        FriendlyError = "Could not find Logs in Splunk for $($VmObj.Name)"
        PsError = ''}) > $null
    } 

    return $Validation, $splunkresults
}

