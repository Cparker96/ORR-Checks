<#
    .SYNOPSIS
        Validate that a linux server has the necessary updates installed
    .DESCRIPTION
        This function authenticates into the server and validates that all OS updates are installed
    .PARAMETER Environment
        The $VmObj variable which pulls in metadata from the server 
    .EXAMPLE

    .NOTES
        FunctionName    : Get-Updates_lnx
        Created by      : Cody Parker
        Date Coded      : 09/09/2022
        Modified by     : 
        Date Modified   : 
#>

function Get-Updates_lnx
{
    Param
    (
        [parameter(Position = 0, Mandatory=$true)] [Microsoft.Azure.Commands.Compute.Models.PSVirtualMachine] $VmObj
    )

    $ScriptPath = "$((get-module ORR_Checks).modulebase)\Private"
    [System.Collections.ArrayList]$Validation = @()

    # put this in a loop because sometimes the kernel doesn't install/update all packages at once
    do {
        try
        {
            $checkupdates = Invoke-AzVMRunCommand -ResourceGroupName $VmObj.ResourceGroupName -VMName $VmObj.Name -CommandId 'RunShellScript' `
            -ScriptPath "$ScriptPath\Validate_Updates_lnx.sh" -ErrorAction Stop

            $updatelist = $checkupdates.Value.message
        }

        catch {
            $Validation.add([PSCustomObject]@{System = 'Server'
            Step = 'Updates'
            SubStep = "Updates"
            Status = 'Failed'
            FriendlyError = "Failed to install/update all kernel packages. Please troubleshoot"
            PsError = $PSItem.Exception}) > $null 

            return $Validation
        }
    } until (($updatelist -like "*Complete!*") -or ($updatelist -like "*Nothing to do*"))

    if (($updatelist -like "*Complete!*") -or ($updatelist -like "*Nothing to do*")) 
    {
        $Validation.add([PSCustomObject]@{System = 'Server'
        Step = 'Updates'
        SubStep = "Updates"
        Status = 'Passed'
        FriendlyError = ""
        PsError = ''}) > $null 
    } else {
        $Validation.add([PSCustomObject]@{System = 'Server'
        Step = 'Updates'
        SubStep = "Updates"
        Status = 'Failed'
        FriendlyError = "Failed to install/update all kernel packages. Please troubleshoot"
        PsError = $PSItem.Exception}) > $null 
    }

    # now reboot the machine
    try {
        $restartvm = Restart-Azvm -ResourceGroupName $Vmobj.ResourceGroupName -Name $VmObj.Name

        if ($restartvm.Status -eq "Succeeded")
        {
            $Validation.add([PSCustomObject]@{System = 'Server'
            Step = 'Updates'
            SubStep = "Restart VM"
            Status = 'Passed'
            FriendlyError = ""
            PsError = ''}) > $null 
        } else {
            $Validation.add([PSCustomObject]@{System = 'Server'
            Step = 'Updates'
            SubStep = "Restart VM"
            Status = 'Failed'
            FriendlyError = "The server $($Vmobj.Name) did not restart successfully. Please troubleshoot"
            PsError = $PSItem.Exception}) > $null 
        } 
    }
    catch {
        $Validation.add([PSCustomObject]@{System = 'Server'
        Step = 'Updates'
        SubStep = "Restart VM"
        Status = 'Failed'
        FriendlyError = "Failed to attempt to restart $($VmObj.Name). Please troubleshoot"
        PsError = $PSItem.Exception}) > $null 

        return $Validation
    }

# this is the old way of doing the operation above ^^^
<#
    # Start-Sleep -Seconds 10
    
    # Write-Host "Rebooting $($VmObj.Name) to apply all kernel updates" -ForegroundColor Yellow

    # # get the nic info for test ping
    # $nicId = $VmObj.NetworkProfile.NetworkInterfaces.Id
    # $nicname = $nicId.split('/')
    # $serverIp = Get-AzNetworkInterface -Name $nicname[8]

    # $targetstatus = ("Success", "Success", "Success", "Success")
    # do 
    # {
    #     $ping = Test-Connection -TargetName $serverIp.IpConfigurations.PrivateIpAddress
    #     Start-Sleep -Seconds 3
    # } until ($ping.status[0..3] -eq $targetstatus)
#> 
    return $Validation, $updatelist, $restartvm
}