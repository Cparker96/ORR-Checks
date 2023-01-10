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
function Get-SplunkResult 
{
    [CmdletBinding()]
    Param
    (
        [Parameter(Mandatory=$true)]$VmObj,
        [Parameter(Mandatory=$true)]$SplunkCredential,
        [Parameter(Mandatory=$true)]$Sid
    )

    # declare endpoint and variables
    $JobResultUrl = "your_splunk_endpoint"
    $username = $SplunkCredential.UserName
    $password = $SplunkCredential.GetNetworkCredential().Password
    $usercreds = "${username}:${password}"
    [System.Collections.ArrayList]$Validation = @()

    Write-Host "Checking recent logs for validation"
    $Resultcontent = (curl -u $usercreds -k $JobResultUrl)

    # this will be handled a bit differently than the other two splunk functions
    # the output is in XML (previously JSON when splunk was on prem)
    # it will create a file in the same working directory, evaluate/validate the XML, then delete the file
    $Resultcontent | Out-File -FilePath .\Temp_Splunk_Log.xml
    [xml]$xml = Get-Content .\Temp_Splunk_Log.xml
    $xmlvalidation = $xml.results.result.field.value.text

    # the $xmlvalidation variable changes (the index of where the server name lives is in a different position each time, and I'm not sure why)
    Write-Host "Parsing XML output for Splunk result" -ForegroundColor Yellow
    # setting initial counters for each time it loops through the $var
    $logcorrect = 0
    $logincorrect = 0
    foreach ($log in $xmlvalidation)
    {
        if ($log -notlike $VmObj.Name)
        {
            $logincorrect++
            # go to the next index in the loop
            continue
        } else {
            Write-Host "Validated Splunk log" -ForegroundColor Green
            $logcorrect++

            $validation.Add([PSCustomObject]@{System = 'Splunk'
            Step = 'SplunkCheck'
            SubStep = 'Validate Splunk Log'
            Status = 'Passed'
            FriendlyError = ''
            PsError = ''}) > $null

            # break the loop
            break
        }
    }

    if ($logcorrect.count -eq 0)
    {
        $validation.Add([PSCustomObject]@{System = 'Splunk'
        Step = 'SplunkCheck'
        SubStep = 'Validate Splunk Log'
        Status = 'Failed'
        FriendlyError = 'Could not retrieve logs for Splunk'
        PsError = $PSItem.Exception}) > $null
    }

    # converting object to string to be able to write to SQL DB
    $convertxmlarray = Out-String -InputObject $Resultcontent

    # delete the temp XML file and check to see if its been removed in the current working directory
    Remove-Item -Path .\Temp_Splunk_Log.xml
    $isfileremoved = ls

    if ($isfileremoved.Name -contains "Temp_Splunk_Log.xml")
    {
        Write-Host "XML file was not deleted. Please remember to manually delete the XML file once the module has completed its run" -ForegroundColor Yellow
    } else {
        Write-Host "XML File has been deleted" -ForegroundColor Green
    }
    
    Start-Sleep -Seconds 20
    
    return $validation, $convertxmlarray
}
