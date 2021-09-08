<#
    .SYNOPSIS
        Validate that a server is configured for sending logs to splunk
    .DESCRIPTION
        This function authenticates into Splunk and validates that a server outputting logs to the splunk forwarders and indexes
    .PARAMETER Environment
        The $VmObj variable which pulls in metadata from the server 
    .EXAMPLE

    .NOTES
        FunctionName    : Get-SplunkCheck
        Created by      : Cody Parker
        Date Coded      : 05/21/2021
        Modified by     : 
        Date Modified   : 

#>

function New-SplunkSearch
{
    $cred = Get-Credential
    param(
            [PSCredential] $cred,
            $search,
            $searchMode = 'Fast',
            $splunkBaseUrl = 'https://splk.textron.com:8089'
    )

    $url = $splunkBaseUrl +"/services/search/jobs"

    

    $parameters = @{
                    'rf' = '*'
                    'search' = $search
                    'adhoc_search_level' = 'fast'
               }

    $result = Invoke-RestMethod -Uri $url -Credential $cred -Body $parameters -Method POST

    return $result.response.sid
}

function Get-SplunkSearchIsDone
{
    param(
            [PSCredential] $cred,
            $sid,
            $splunkBaseUrl = "https://splk.textron.com:8089"
        )

    $url = $splunkBaseUrl +"/services/search/jobs/$sid"

    $result = Invoke-RestMethod -Uri $url -Credential $cred

    $isDone = $result.entry.content.dict.key | where {$_.name -eq "isDone"}

    if($isDone.'#text' -eq '1')
    {
        return $true;
    }
    else
    {
        $false;
    }
}

function Get-SplunkSearchStatus
{
    param(
            [PSCredential] $cred,
            $sid,
            $splunkBaseUrl = "https://splk.textron.com:8089"
        )

    $keys = @('eventCount', 'diskUsage', 'doneProgress', 'dispatchState', 'isDone','isFailed', 'isFinalized', 'resultCount')

    $url = $splunkBaseUrl +"/services/search/jobs/$sid"

    $parameters = @{
                    'output_mode' = 'json'
                    }

    $result = Invoke-RestMethod -Uri $url -Credential $cred -Method Get -Body $parameters

    return $result.entry.content | select $keys
}

function Get-SplunkSearchResults
{
    param(
            [PSCredential] $cred,
            $sid,
            $outputMode = 'json', #JSON CSV XML
            $pageSize = (Get-Setting 'splunkPageSize'),
            $splunkBaseUrl = "https://splk.textron.com:8089"
        )

    $url = $splunkBaseUrl +"/services/search/jobs/$sid/results/"


    $status = Get-SplunkSearchStatus -Credential $cred -sid $sid -splunkBaseUrl $splunkBaseURL
    $totalResults = $status.resultCount

    $results = @()

    for($offset = 0; $offset -lt $totalResults; $offset += $pageSize)
    {
        write-host ("Getting {0} of {1}" -f $offset, $totalResults)

        $parameters = @{
                    'output_mode' = $outputMode
                    'count' = $pageSize
                    'offset' = $offset
                    #'count' = 1000
               }

        $result = Invoke-RestMethod -Uri $url -Credential $cred -Body $parameters -Method GET
        $results += $result.results
    }

    return $results
}


function Disable-CertCheck
{
    #something is wrong with the https cert..... should look into that
    #The cert is missing the a san for the host name splunk.textron.com
    if ($PSVersionTable.PSEdition -eq 'Core')
    {
    [System.Net.ServicePointManager]::ServerCertificateValidationCallback = {$true}
    } else {
            add-type @"
        using System.Net;
        using System.Security.Cryptography.X509Certificates;
        public class TrustAllCertsPolicy : ICertificatePolicy {
            public bool CheckValidationResult(
                ServicePoint srvPoint, X509Certificate certificate,
                WebRequest request, int certificateProblem) {
                return true;
            }
        }
"@
    [System.Net.ServicePointManager]::CertificatePolicy = New-Object TrustAllCertsPolicy 
    }
}

Function Get-SplunkCheck
{
    Disable-CertCheck

    try {
        $searchsid = New-SplunkSearch -Credential $cred -search "search index=win* host=TXAINFAZU901 | head 1" 
    }
    catch {
        $e = $_.Exception
    }

    $results = Get-SplunkSearchResults -Credential $cred -sid $searchsid -pageSize 100

    if (($results.host -ne 'TXAINFAZU901') -and ($results.index -ne 'win_event'))
    {
        Write-Host "Invalid log entry. Please check again" -ErrorAction Stop -ForegroundColor Red
    } else {
        Write-Host "This server is configured for Splunk logging" -ForegroundColor Green 
    }
}
#>