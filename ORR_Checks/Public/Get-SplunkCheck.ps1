$Url = "https://splk.textron.com:8089"
function Splunk-Auth
{
    [CmdletBinding()]

    Param
    (
        [Parameter(Mandatory=$true)]        
        [Uri]$Url
    )

    $Headers = @{
        'username'='svc_tis_midrange'
        'password'='slope-VARIES-apparent-DENMARK-cafe-14225'
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
