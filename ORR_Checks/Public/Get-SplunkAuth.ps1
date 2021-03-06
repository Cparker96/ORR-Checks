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
        Created by      : 'creator'
        Date Coded      : 09/7/2021
        Modified by     : ...
        Date Modified   : ...

#>
function Get-SplunkAuth
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
