<#
    .SYNOPSIS
        Validate that a server is configured in McAfee
    .DESCRIPTION
        This function authenticates into the server and validates that McAfee is configured properly
    .PARAMETER Environment
        The $VmObj variable which pulls in metadata from the server 
    .EXAMPLE

    .NOTES
        FunctionName    : Get-McAfeeCheck
        Created by      : Cody Parker
        Date Coded      : 07/8/2021
        Modified by     : 
        Date Modified   : 

#>
Function Get-McAfeeCheck
{
    Param
    (
        [parameter(Position = 0, Mandatory=$true)] [Microsoft.Azure.Commands.Compute.Models.PSVirtualMachine] $VmObj
    )

    $mcafee = Invoke-AzVMRunCommand -ResourceGroupName $VmObj.ResourceGroupName -VMName $VmObj.Name -CommandId 'RunPowerShellScript' `
    -ScriptPath ".\ORR_Checks\ORR_Checks\Private\Validate_McAfee.ps1"

    $validatemcafee = $mcafee.Value.message | ConvertFrom-Csv

    # get the date of the last reported date in McAfee - convert to datetime, subtract 6 hrs - then convert back to string
    $lastreportdate = $validatemcafee[11].'Component: McAfee Agent '.Trim('LastASCTime: ')
    $cutofftime = [datetime]::ParseExact($lastreportdate, "yyyyMMddHHmmss", $null).AddHours(-6).ToString("yyyyMMddHHmmss")

    # need to validate that not only the agent is installed, need Endpoint Security, Firewall, etc.
    $programs = Invoke-AzVMRunCommand -ResourceGroupName $VmObj.ResourceGroupName -VMName $VmObj.Name -CommandId 'RunPowerShellScript' `
    -ScriptPath ".\ORR_Checks\ORR_Checks\Private\Validate_McAfee_ProgramCount.ps1"

    $mcafeeprograms = $programs.value.message | ConvertFrom-Csv

    # check to see if last reported in date is greater than 6 hrs - if so, we got a problem
    if ($lastreportdate -lt $cutofftime)
    {
        Write-Host "This server is reporting but the last reported in date was longer than 6 hrs. Please reconfigure or contact Security" -ErrorAction Stop -ForegroundColor Red
    } elseif ($mcafeeprograms.Count -lt 4) {
        Write-Host "One or more parts of McAfee are missing. Please install all parts" -ErrorAction Stop -ForegroundColor Red
    } else {
        Write-Host "This server is configured for McAfee" -ForegroundColor Green
        $convertedbackdate = [datetime]::ParseExact($lastreportdate, "yyyyMMddHHmmss", $null).ToString("yyyy-MM-dd HH:mm:ss")
    }

    return $mcafeeprograms, $convertedbackdate
}

