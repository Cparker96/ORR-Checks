$token = ""

#$Credential= New-Object -TypeName System.Management.Automation.PSCredential `
#-ArgumentList 'username',('password' | ConvertTo-SecureString -AsPlainText -Force)

$url = "https://splunk.textron.com:8089"

$search = 'index=win_event* TXBMMLINKGCCT01 and sourcetype=XmlWinEventLog'
$Startdtunix = [int64]((((get-date).addhours(-1)).ToUniversalTime()) - (get-date "1/1/1970")).TotalSeconds
$Enddtunix = [int64](((get-date).ToUniversalTime()) - (get-date "1/1/1970")).TotalSeconds

$Headers = @{Authorization= "Bearer $token"}
$Loginurl = $url + "/services/auth/login/users/clarvin"
$Content = (Invoke-WebRequest -uri $Loginurl -Method Post -Body ($Headers) -ContentType "application/json" -SkipCertificateCheck -UseBasicParsing -ErrorAction stop).content

$Search = 'search ' + $Search
$Searchurl = $url + "/services/search/jobs"
$Body = @{'search'= $Search
'earliest_time' = $Startdtunix
'latest_time' = $Enddtunix }
(Invoke-WebRequest -uri $Searchurl -Method Post -Headers $Headers -Body $Body -ContentType "application/json" -UseBasicParsing -SkipCertificateCheck -ErrorAction Stop).content



$Joburl = $url + "/services/search/jobs/" + $Sid

   
   try {
    $Content = (Invoke-WebRequest -uri $Joburl -Method Get -Headers $Headers -SkipCertificateCheck -UseBasicParsing -ErrorAction Stop).content
   }
   catch {
    return $Error[0].Exception
   }
   
   if($Content) {
        $State =  (([xml]$Content).entry.content.dict.key | ? {$_.name -eq 'isdone'}).innertext
    if ($State) {
    if ($State -eq 1){return "DONE"}
    else {
        return ((([xml]$Content).entry.content.dict.key | ? {$_.name -eq 'dispatchState'}).innertext + " - " + [math]::Round([float]((([xml]$Content).entry.content.dict.key | ? {$_.name -eq 'doneProgress'}).innertext) * 100))
    }
    }
   }
   
   if (!$Content -OR !$State) {
   return "Error. No valid jobstate returned by $Joburl"
   }







#job results
$sid = '1620850842.456089'
$JobResultUrl = $url + ("/services/search/jobs/{0}/results?output_mode=json&count=0" -f $Sid)
(Invoke-WebRequest -uri $JobResultUrl -Method Get -Headers $Headers -UseBasicParsing -SkipCertificateCheck -ErrorAction Stop).content   





#functions not useful because they use a key
<#






function Splunk-Auth {
    [CmdletBinding()]
       
       Param
       (
           [Parameter(Mandatory=$true)]        
           [Uri]$Url,
           [ValidateNotNull()]
           [System.Management.Automation.PSCredential]
           [System.Management.Automation.Credential()]
           $Credential = [System.Management.Automation.PSCredential]::Empty
       )
   
   #$UserName = $Credential.UserName
   #$Password = $Credential.GetNetworkCredential().Password
   
   $Headers = @{"Authorization"= "Bearer <token>"}
   #'username'=$UserName
   #'password'=$Password}
   
   $Loginurl = $url.AbsoluteUri + "services/auth/login"
   [regex]$sessionKey = "(?<=<sessionKey>)(.*)(?=<\/sessionKey>)"
   
   try {
   $Content = (Invoke-WebRequest -uri $Loginurl -Method Post -Body ($Headers) -ContentType "application/json" -SkipCertificateCheck -UseBasicParsing -ErrorAction Stop).content
   }
   catch {
   return $Error[0].Exception
   }
   
   if($Content) {
   $Key = "Splunk " + $sessionKey.Match($content).Value
   }
   if (!$Content -OR !$Key) {
   return "Error. No valid key returned by $Loginurl"
   }
   return $Key
   }



   function Splunk-Search {
    [CmdletBinding()]
       
       Param
       (
           [Parameter(Mandatory=$true)]
           [Uri]$Url,
           [Parameter(Mandatory=$true)]
           [ValidateNotNull()]
           [string]$Key,
           [Parameter(Mandatory=$false)]
           [ValidateNotNull()]
           [string]$Search,        
           [Parameter(Mandatory=$false)]
           [ValidateNotNull()]
           [datetime]$Startdt=(get-date).addhours(-1),
           [Parameter(Mandatory=$false)]
           [ValidateNotNull()]
           [datetime]$Enddt=(get-date)
       )
   $Search = 'search ' + $Search
   $Searchurl = $url.AbsoluteUri + "services/search/jobs"
   [regex]$Jobsid = "(?<=<sid>)(.*)(?=<\/sid>)"
   
   $Startdtunix = [int64](($Startdt.ToUniversalTime()) - (get-date "1/1/1970")).TotalSeconds
   $Enddtunix = [int64](($Enddt.ToUniversalTime()) - (get-date "1/1/1970")).TotalSeconds
   
   $Auth = @{'Authorization'=$Key}
   $Body = @{'search'= $Search
             'earliest_time' = $Startdtunix
             'latest_time' = $Enddtunix          
             }
   
   try {
   $Content = (Invoke-WebRequest -uri $Searchurl -Method Post -Headers $Auth -Body $Body -ContentType "application/json" -UseBasicParsing -SkipCertificateCheck -ErrorAction Stop).content
   }
   catch {
   return $Error[0].Exception
   }
   
   if($Content) {
   $Sid = $Jobsid.Match($Content).Value.ToString()
   }
   if (!$Content -OR !$Sid) {
   return "Error. No valid sid returned by $Searchurl"
   }
   return $Sid
   }

   function Splunk-JobStatus {
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
   
   $Joburl = $url + "/services/search/jobs/" + $Sid

   
   try {
   $Content = (Invoke-WebRequest -uri $Joburl -Method Get -Headers $Auth -UseBasicParsing -ErrorAction Stop).content
   }
   catch {
   return $Error[0].Exception
   }
   
   if($Content) {
   $State =  (([xml]$Content).entry.content.dict.key | ? {$_.name -eq 'isdone'}).innertext
   if ($State) {
   if ($State -eq 1){return "DONE"}
   else {
   return ((([xml]$Content).entry.content.dict.key | ? {$_.name -eq 'dispatchState'}).innertext + " - " + [math]::Round([float]((([xml]$Content).entry.content.dict.key | ? {$_.name -eq 'doneProgress'}).innertext) * 100))
   }
   }
   }
   
   if (!$Content -OR !$State) {
   return "Error. No valid jobstate returned by $Joburl"
   }
   }


   function Splunk-JobResult {
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
   
   $JobResultUrl = $url + ("/services/search/jobs/{0}/results?output_mode=json&count=0" -f $Sid)
   
   
   try {
   $Content = (Invoke-WebRequest -uri $JobResultUrl -Method Get -Headers $Auth -UseBasicParsing -ErrorAction Stop).content
   }
   catch {
   return $Error[0].Exception
   }
   
   if($Content) {
   return ($Content | ConvertFrom-Json).results
   }
   else {
   "Error. No valid jobstate returned by $JobResultUrl"
   }
   }

   #>