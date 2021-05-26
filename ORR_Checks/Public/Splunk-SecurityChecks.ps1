<#
    .SYNOPSIS
        Validate security controls in Splunk such as Tenable data and EPO
    .DESCRIPTION
        This function authenticates into Splunk and validates that a server is put into the correct Tenable groups, is online
        and that EPO is configured properly
    .PARAMETER Environment
        The $VmName variable which pulls in metadata from the server 
    .EXAMPLE
        get-AzureCheck -VmName 'TXBMMLINKGCCT02' `
        -Environment AzureCloud `
        -Subscription Enterprise `
        -ResourceGroup 308-Utility `
        -Credential $credential
            

    .NOTES
        FunctionName    : Splunk-SecurityChecks
        Created by      : Cody Parker
        Date Coded      : 05/21/2021
        Modified by     : 
        Date Modified   : 

#>
Function Splunk-Login
{
    #setting all variables for authentication
    $token = "5950e283ba8a3306a2468b7952dfb3a61393698dac6eec65fdd9a736397eec7f"
    $url = "https://splunk.textron.com:8089"
    $query = 'index=win* machine=TXAINFAZU901'
    $headers = @{Authentication= "Bearer $token"}
    $startdate = [Int64]((((get-date).addhours(-1).ToUniversalTime()) - (get-date "1/1/1970")).TotalSeconds)
    $enddate = [Int64](((get-date).ToUniversalTime()) - (get-date "1/1/1970")).TotalSeconds
    $Loginurl = $url + "/services/auth/login/users/cparke06"
    [regex]$sessionkey = "(?<=<sessionKey>)(.*)(?=<\/sessionKey>)"

    try 
    {
        $Content = (Invoke-WebRequest -Uri $Loginurl -Method Post -Body ($headers) -ContentType "application/json" -SkipCertificateCheck -UseBasicParsing -ErrorAction Stop).content
    }
    catch 
    {
        return $Error[0].Exception
    }

    if ($Content)
    {
        $Key = "Splunk " + $sessionkey.Match($Content).Value
    }

    if (!$Content -or !$Key)
    {
        return "No valid key returned by" + $Loginurl
    }
    return $Key
}