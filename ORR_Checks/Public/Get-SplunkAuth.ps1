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
        Modified by     : ...
        Date Modified   : ...

#>
function Get-SplunkAuth
{
    [CmdletBinding()]
    Param
    ( 
        [Parameter(Mandatory=$true)] $SplunkCredential
    )
    
    # declare endpoint and credentials
    $AuthUrl = "your_splunk_endpoint"
    $username = $SplunkCredential.UserName
    $password = $SplunkCredential.GetNetworkCredential().Password
    [System.Collections.ArrayList]$Validation = @()

    # need to regex for session key matching
    [regex]$sessionKey = "(?<=<sessionKey>)(.*)(?=<\/sessionKey>)"

    # need to loop through multiple attempts for authentication - avoids blips in the radar if splunk is down for a minute or two then back online
    $authcounter = 0
    do {
    Write-Host 'Authenticating to Splunk'
    $AuthContent = (curl -k $AuthUrl --data-urlencode username=$username --data-urlencode password=$password)
    $authcounter++
    Start-Sleep -Seconds 10
    } until ($null -ne $AuthContent)

    # this will be handled a bit differently than the other two splunk functions
    # the output is in XML (previously JSON when splunk was on prem)
    # it will create a file in the same working directory, evaluate/validate the XML, then delete the file
    $Authcontent | Out-File -FilePath .\Temp_Splunk_Log_Auth.xml
    [xml]$authxml = Get-Content .\Temp_Splunk_Log_Auth.xml
    $authxmlvalidationsessionkey = $authxml.response.sessionKey

    # this will validate whether the session key is an appropriate length and that there are no error messages displayed in the XML
    # Splunk could theoretically change their session key length, but I figured this was an appropriate check...for now
    if ($authxmlvalidationsessionkey.Length -gt 30) 
    {
        $Key = "Splunk " + $sessionKey.Match($AuthContent).Value

        $validation.Add([PSCustomObject]@{System = 'Splunk'
        Step = 'SplunkCheck'
        SubStep = 'Validate Authentication'
        Status = 'Passed'
        FriendlyError = ''
        PsError = ''}) > $null
    } elseif (!$AuthContent -OR !$Key) {
        $validation.Add([PSCustomObject]@{System = 'Splunk'
        Step = 'SplunkCheck'
        SubStep = 'Validate Authentication'
        Status = 'Failed'
        FriendlyError = 'Could not authenticate to Splunk'
        PsError = $PSItem.Exception}) > $null
    }

    # delete the temp XML file and check to see if its been removed in the current working directory
    Remove-Item -Path .\Temp_Splunk_Log_Auth.xml
    $isfileremoved = ls

    if ($isfileremoved.Name -contains "Temp_Splunk_Log_Auth.xml")
    {
        Write-Host "XML file was not deleted. Please remember to manually delete the XML file once the module has completed its run" -ForegroundColor Yellow
    } else {
        Write-Host "XML File has been deleted" -ForegroundColor Green
    }

    Start-Sleep -Seconds 20
    
    return $validation, $Key
}