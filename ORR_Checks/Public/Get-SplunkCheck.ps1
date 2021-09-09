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

$Url = "https://splk.textron.com:8089"
$username = (Get-AzKeyVaultSecret -VaultName 'kv-308' -Name 'ORRChecks-Splunk').ContentType
$password = (Get-AzKeyVaultSecret -VaultName 'kv-308' -Name 'ORRChecks-Splunk').SecretValue | ConvertFrom-SecureString -AsPlainText
function Splunk-Auth
{
    [CmdletBinding()]

    Param
    (
        [Parameter(Mandatory=$true)]        
        [Uri]$Url
    )

    $Headers = @{
        'username'=$username
        'password'=$password
    }

    $Loginurl = $url.AbsoluteUri + "services/auth/login"
    [regex]$sessionKey = "(?<=<sessionKey>)(.*)(?=<\/sessionKey>)"

    try {
    $Content = (Invoke-WebRequest -uri $Loginurl -Method Post -Body ($Headers) -ContentType "application/json" -UseBasicParsing -ErrorAction Stop).content
    }
    catch {
    return $Error[0].Exception
    }

    if($Content) {
    #the purpose of "$script:Key" is to make the $Key variable available to be used dynamically with other functions
    $script:Key = "Splunk " + $sessionKey.Match($content).Value
    }
    if (!$Content -OR !$Key) {
    return "Error. No valid key returned by $Loginurl"
    }
    return $Key
}
function Splunk-Search 
{      
    [CmdletBinding()]

    Param
    (
        [Parameter(Mandatory=$true)]
        [Uri]$Url,
        [Parameter(Mandatory=$true)]
        [ValidateNotNull()]
        [string]$Key
    )

    $Searchstring = "search index=win_event* host=txainfazu901 earliest=-60m | head 1"
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
        return $Error[0].Exception
    }
        
    if($Content) {
    $script:Sid = $Jobsid.Match($Content).Value.ToString()
    }
    if (!$Content -OR !$Sid) {
    return "Error. No valid sid returned by $Searchurl"
    }
    return $Sid
}

function Splunk-Result 
{
    [CmdletBinding()]

    Param
    (
        [Parameter(Mandatory=$true)]
        [Uri]$Url,
        [Parameter(Mandatory=$true)]
        [ValidateNotNull()]
        [string]$Key,
        [Parameter(Mandatory=$true)]
        [ValidateNotNull()]
        [string]$Sid
    )

    $JobResultUrl = $Url.AbsoluteUri + ("services/search/jobs/{0}/results?output_mode=json&count=0" -f $Sid)

    $Auth = @{'Authorization'=$Key}

    try {
    $Content = (Invoke-WebRequest -uri $JobResultUrl -Method Get -Headers $Auth -UseBasicParsing -ErrorAction Stop).content
    }
    catch {
    return $Error[0].Exception
    }

    if($Content) {
    return ($Content | ConvertFrom-Json).results
    } else {
    "Error. No valid jobstate returned by $($JobResultUrl)"
    }
}
