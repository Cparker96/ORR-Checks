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
Function Get-McAfeeCheck_win
{
    Param
    (
        [parameter(Position = 0, Mandatory=$true)] [Microsoft.Azure.Commands.Compute.Models.PSVirtualMachine] $VmObj
    )

    $ScriptPath = $ScriptPath = "$((get-module ORR_Checks).modulebase)\Private"
    [System.Collections.ArrayList]$Validation = @()

    <#==================================================
    Validate agent is installed
    #===================================================#>
    Try{
        # need to validate that not only the agent is installed, need Endpoint Security, Firewall, etc.
        $programs = Invoke-AzVMRunCommand -ResourceGroupName $VmObj.ResourceGroupName -VMName $VmObj.Name -CommandId 'RunPowerShellScript' `
        -ScriptPath "$ScriptPath\Validate_McAfee_ProgramCount_win.ps1"

        $mcafeeprograms = $programs.value.message | ConvertFrom-Csv

        if ($mcafeeprograms.Name -ne "Trellix Agent") {
            $validation.Add([PSCustomObject]@{System = 'Server'
            Step = 'McAfeeCheck'
            SubStep = 'Agent Configuration'
            Status = 'Failed'
            FriendlyError = "McAfee Agent is not configured for this server. Please install it"
            PsError = $PSItem.Exception}) > $null
        }else{
            $validation.Add([PSCustomObject]@{System = 'Server'
            Step = 'McAfeeCheck'
            SubStep = 'Agent Configuration'
            Status = 'Passed'
            FriendlyError = ""
            PsError = ''}) > $null
        }
    }Catch{
        $Validation.add([PSCustomObject]@{System = 'Server'
        Step = 'McAfeeCheck'
        SubStep = "Agent Configuration"
        Status = 'Failed'
        FriendlyError = 'Check to make sure you have the package installed.'
        PsError = $PSItem.Exception}) > $null 

        return $Validation
    }

    Try{
        $mcafee = Invoke-AzVMRunCommand -ResourceGroupName $VmObj.ResourceGroupName -VMName $VmObj.Name -CommandId 'RunPowerShellScript' `
        -ScriptPath "$ScriptPath\Validate_McAfee_win.ps1"

        $validatemcafee = $mcafee.Value.message | ConvertFrom-Csv

        # get the date of the last reported date in McAfee - convert to datetime, subtract 6 hrs - then convert back to string
        $lastreportdate = $validatemcafee[11].'Component: McAfee Agent '.Trim('LastASCTime: ')
        $cutofftime = [datetime]::ParseExact($lastreportdate, "yyyyMMddHHmmss", $null).AddHours(-6).ToString("yyyyMMddHHmmss")
        
        $convertedbackdate = [datetime]::ParseExact($lastreportdate, "yyyyMMddHHmmss", $null).ToString("yyyy-MM-dd HH:mm:ss")

        # check to see if last reported in date is greater than 6 hrs - if so, we got a problem
        if ($lastreportdate -lt $cutofftime)
        {
            $validation.Add([PSCustomObject]@{System = 'Server'
            Step = 'McAfeeCheck'
            SubStep = 'Check in Time'
            Status = 'Failed'
            FriendlyError = "This server is reporting but the last reported in date was longer than 6 hrs. Please reconfigure or contact Security"
            PsError = $PSItem.Exception}) > $null
        }else {
            $validation.Add([PSCustomObject]@{System = 'Server'
            Step = 'McAfeeCheck'
            SubStep = 'Check in Time'
            Status = 'Passed'
            FriendlyError = ""
            PsError = ''}) > $null
        }
    }catch{
        $Validation.add([PSCustomObject]@{System = 'Server'
        Step = 'McAfeeCheck'
        SubStep = "Check in Time"
        Status = 'Failed'
        FriendlyError = 'Failed to Report in Please reconfigure or contact Security.'
        PsError = $PSItem.Exception}) > $null 

        return $Validation
    }

    return ($Validation, $mcafeeprograms.name, $convertedbackdate)
}

