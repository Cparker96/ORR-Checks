<#
    .SYNOPSIS
        Validate that a server is configured in ERPM for Admins
    .DESCRIPTION
        This function authenticates into the server and validates that ERPM is configured properly for Admins
    .PARAMETER Environment
        The $VmObj variable which pulls in metadata from the server 
    .EXAMPLE

    .NOTES
        FunctionName    : Get-ERPMAdminsCheck
        Created by      : Cody Parker
        Date Coded      : 07/9/2021
        Modified by     : 
        Date Modified   : 

#>
Function Get-ERPMAdminsCheck_win
{
    Param
    (
        [parameter(Position = 0, Mandatory=$true)] [Microsoft.Azure.Commands.Compute.Models.PSVirtualMachine] $VmObj
        #[parameter(Position = 1, Mandatory=$true)] $VmRF
       #[parameter(Position=2, Mandatory=$false)] $prodpass
    )
    $ScriptPath = $ScriptPath = "$((get-module ORR_Checks).modulebase)\Private"
    [System.Collections.ArrayList]$Validation = @()
    # $user = "sn.datacenter.integration.user"
	# $pass = $prodpass

	# # Build auth header
	# $base64AuthInfo = [Convert]::ToBase64String([Text.Encoding]::ASCII.GetBytes(("{0}:{1}" -f $user, $pass)))

	# # Set proper headers
	# $headers = New-Object "System.Collections.Generic.Dictionary[[String],[String]]"
	# $headers.Add('Authorization',('Basic {0}' -f $base64AuthInfo))
	# $headers.Add('Accept','application/json')
	# $headers.Add('Content-Type','application/json')

	# $sctaskmeta = "https://textronprod.servicenowservices.com/api/now/table/sc_task?sysparm_query=number%3D$($VmRF.'Ticket Number')&sysparm_fields=variables.server_admin_group"

    # $getsctask = Invoke-RestMethod -Headers $headers -Method Get -Uri $sctaskmeta

    Try {
        $Admins = Invoke-AzVMRunCommand -ResourceGroupName $VmObj.ResourceGroupName -VMName $VmObj.name -CommandId 'RunPowerShellScript' `
        -ScriptPath "$ScriptPath\Validate_ERPM_Admins_win.ps1" -ErrorAction Stop

        $checkadmins = $Admins.Value.message | ConvertFrom-Csv 
        
        #look at the groups and determine if they meet the criteria   
        if (($checkadmins.Name -notcontains 'TXT\ADM_SRV_AZU') -or ($checkadmins.Name -notcontains 'TXT\svc_hq_erpm_svc'))
        {
            $Validation.Add([PSCustomObject]@{System = 'ERPM'
            Step = 'ERPMCheck'
            SubStep = 'ERPM Admins'
            Status = 'Failed'
            FriendlyError = 'This server does not have the configured admins'
            PsError = $PSItem.Exception}) > $null
        } else {
            $Validation.Add([PSCustomObject]@{System = 'ERPM'
            Step = 'ERPMCheck'
            SubStep = 'ERPM Admins'
            Status = 'Passed'
            FriendlyError = ''
            PsError = ''}) > $null 
        }
    } Catch {
        $validation.Add([PSCustomObject]@{System = 'VM'
        Step = 'ERPMCheck'
        SubStep = 'ERPM Admins'
        Status = 'Failed'
        FriendlyError = 'Failed to run ERPM Checks on the server'
        PsError = $PSItem.Exception}) > $null

        return $validation
    }
    
    # validate the admins that were requested
    # try
    # {
    #     $Admins = Invoke-AzVMRunCommand -ResourceGroupName $VmObj.ResourceGroupName -VMName $VmObj.name -CommandId 'RunPowerShellScript' `
    #     -ScriptPath "$((get-module ORR_Checks).modulebase)\Private\Validate_ERPM_Admins.ps1" -ErrorAction Stop

    #     $checkadmins = $Admins.Value.message | ConvertFrom-Csv 

    #     $requestedadmins = $getsctask.result.'variables.server_admin_group'
    #     $admincounter = 0

    #     foreach ($admin in $requestedadmins)
    #     {
    #         if ($admin -in $checkAdmins)
    #         {
    #             Write-host "This admin group is in the local admins file. Checking the next one..." -ForegroundColor Yellow
    #             continue
    #         } else {
    #             Write-Host "This admin group is not in the local admins file" -ForegroundColor Red
    #             $admincounter++
    #             continue
    #         }
    #     }

    #     if ($admincounter -eq 0)
    #     {
    #         $validation.Add([PSCustomObject]@{System = 'VM'
    #         Step = 'ERPMCheck'
    #         SubStep = 'Check SNOW Requested Admins'
    #         Status = 'Passed'
    #         FriendlyError = ''
    #         PsError = ''}) > $null 
    #     } else {
    #         $validation.Add([PSCustomObject]@{System = 'VM'
    #         Step = 'ERPMCheck'
    #         SubStep = 'Check SNOW Requested Admins'
    #         Status = 'Failed'
    #         FriendlyError = 'One or more admin groups are missing in the local admins file'
    #         PsError = $PSItem.Exception}) > $null
    #     }
    # } catch {
    #     $validation.Add([PSCustomObject]@{System = 'VM'
    #     Step = 'ERPMCheck'
    #     SubStep = 'Check SNOW Requested Admins'
    #     Status = 'Failed'
    #     FriendlyError = 'Failed to check whether the admin groups are in the local admins file'
    #     PsError = $PSItem.Exception}) > $null
    # }

    return ($validation, $checkadmins.Name)
}
