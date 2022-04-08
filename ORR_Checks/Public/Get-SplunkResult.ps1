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

    Start-Sleep -Seconds 20

    if($Content) 
    {
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
    
    Start-Sleep -Seconds 20

    return $validation, $Content
}
