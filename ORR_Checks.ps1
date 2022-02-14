
<#
    .SYNOPSIS
        The main file to run the Server Operational Readdiness Review (ORR) process
    .DESCRIPTION
        the Ps1 that actually runs the ORR workflow and outputs the validation steps
	.PARAMETER Hostname
		The Server name of the Server being ORR'd
    .PARAMETER Environment
		Specifies the Cloud platform and tennant to connect to
			Public Cloud - "AzureCloud" 
			Azure Gov - "AzureUSGovernment_Old"
			Azure Gov GCC High - "AzureUSGovernment" 
    .PARAMETER Subscription
		The friendly name of the subscription where the VM was built
    .PARAMETER Resource Group
		The Resource group name where the VM was built
    .PARAMETER Operating System
		Can be left null but a simple Windows or Linux is prefered
    .PARAMETER Requestor
		The name of the VM requestor
    .PARAMETER Created By
		The name of the IT professional who did the build
    .PARAMETER Ticket Number
		The Snow ticket that stared the build process and where the requirements and approvals are sourced 
    .PARAMETER RunTenableScan
		A quick way to not run the tennable scan (aprox 1 hour) for testing purposes. 
		Approved Values
			"Yes"
			"No"

    .EXAMPLE
		{
			"Hostname" : "TXAINFAZU021",
			"Environment" : "AzureCloud",
			"Subscription" : "Enterprise",
			"Resource Group" : "308-Utility",
			"Operating System" : "",
			"Requestor" : "Christopher Reilly",
			"Created By" : "Ricky Barbour",
			"Ticket Number" : "SCTASK0014780", 
			"RunTenableScan" : "Yes"
		}       

    .NOTES
        Created by      : Cody Parker and Claire Larvin
        Date Coded      : 04/16/2021
        Modified by     : Claire Larvin
        Date Modified   : 1/26/2022

Links:
	Nuget powershell module 
		https://docs.microsoft.com/en-us/azure/devops/artifacts/tutorials/private-powershell-library?view=azure-devops
#>


#============================================#>


<#============================================
import-module if the version in this folder isn't the one that you have
#============================================#>
<#if(($null -eq (get-module ORR_Checks).version) -and 
((get-module ORR_Checks).version -ne (test-modulemanifest .\ORR_Checks\ORR_Checks.psd1).Version)){
	Import-Module .\ORR_Checks -Force -WarningAction SilentlyContinue -ErrorAction Stop
}#>

<#============================================
Get variables
#============================================#>
Set-StrictMode -version 3 
set-strictMode -Off
[Uri]$Url = "https://splk.textron.com:8089"
$VmRF = @()
$AzCheck = @()
$VMobj = @()
$validateErpmOU = @()
$validateErpmAdmins = @()
$validateMcafee = @()
$SplunkCheck = @()
$validateTenable = @()
$tennableVulnerabilities = @()
$SqlCredential = @()
$sqlInstance = 'txadbsazu001.database.windows.net'
$sqlDatabase = 'TIS_CMDB'

#get Server Build variables from VM_Request_Fields.json
Try
{
	$VmRF = Get-Content .\VM_Request_Fields.json | convertfrom-json -AsHashtable
}
catch{ write-error "Could not load VM_Reques_Fields.json `r`n $($_.Exception)" -erroraction stop }



<#============================================
Get Credentials
#============================================#>
Try{
	#connect to Public azure and make sure the context is Enterprise where the keyvault exists
	disconnect-azaccount > $null
	Connect-AzAccount -Environment AzureCloud -Tenant '2d5b202c-8c07-4168-a551-66f570d429b3' -WarningAction ignore > $null
	Set-AzContext -Subscription 'Enterprise' > $null

	$TenableAccessKey = Get-AzKeyVaultSecret -vaultName 'kv-308' -name 'ORRChecks-TenableAccessKey-10m' -AsPlainText 
	$TenableSecretKey = Get-AzKeyVaultSecret -vaultName 'kv-308' -name 'ORRChecks-TenableSecretKey-10m' -AsPlainText 
    $SqlCredential = New-Object System.Management.Automation.PSCredential ('ORRCheckSql', ((Get-AzKeyVaultSecret -vaultName "kv-308" -name 'ORRChecks-Sql').SecretValue))
	$SplunkCredential = New-Object System.Management.Automation.PSCredential ('svc_tis_midrange', ((Get-AzKeyVaultSecret -vaultName 'kv-308' -name 'ORRChecks-Splunk').SecretValue)) 
	$GovAccount = New-Object System.Management.Automation.PSCredential ('768ca4de-5c94-4879-9c74-be8d0217ff01',((Get-AzKeyVaultSecret -vaultName 'kv-308' -name 'ORRChecks-GCCHAccess').SecretValue))
}
Catch{
	Write-Error "could not get keys from key vault" -ErrorAction Stop
}

Write-Host "Running ORR on Server $($VmRF.Hostname)"

<#============================================
Check VM in Azure
============================================#>
	$AzCheck = @()

	write-host "Validating Azure Object matches standards"

	# will log you into Azure and set context to where the VM is
	#returns 2 objects, a Validation checks object and an Azure VM object (if )
	$AzCheck = get-AzureCheck -VmName $VmRf.Hostname `
	-Environment $VmRF.Environment `
	-Subscription $VmRF.Subscription `
	-ResourceGroup $VmRF.'Resource Group' `
	-GovAccount $GovAccount

	#seperate the VM object from the azCheck object
	if($null -eq ($AzCheck | where {$_.gettype().name -eq 'PSVirtualMachine'})){
		Write-Error "$($AzCheck.FriendlyError)" -ErrorAction Stop
	}else{
		$VmObj = ($AzCheck | where {$_.gettype().name -eq 'PSVirtualMachine'})
	}

	#if the contributor role isn't checked out then fail the script
	if(($AzCheck| where {$_.gettype().name -eq 'ArrayList'})[3].status -eq 'failed'){
		Write-Error ($AzCheck| where {$_.gettype().name -eq 'ArrayList'})[3].FriendlyError -ErrorAction Stop
	}




<#============================================
Log into VM and do pre domain join checks
#============================================#>
	$VmCheck = @()

	write-host "Validating VM is set up for Domain Checks"

	If($vmobj.StorageProfile.OsDisk.OsType -eq 'Windows') #if a windows server
	{
		$VmCheck = Get-VMCheck -VmObj $VmObj -SqlCredential $SqlCredential
		$VmRF.'Operating System' = 'Windows'
	}elseif($vmobj.StorageProfile.OsDisk.OsType -eq 'Linux') { #if a Linux server
		# $VmCheck = Get-VMCheck_Linux -VmObj $VmObj
		$VmRF.'Operating System' = 'Linux'
	}else{
		Write-Error "Can not determine OS image on Azure VM object" -ErrorAction Stop
	}


<#============================================
Check Security controls
	Windows
		ERPM
		Mcafee
		Splunk
		Tenable
	Linux
		Splunk
		Tenable
#============================================#>
	<#============================================
	ERPM (Windows Only)
	#============================================#>
	write-host "Validating ERPM"

	$validateErpmOU = Get-ERPMOUCheck -vmobj $VmObj

	$validateErpmAdmins = Get-ERPMAdminsCheck -vmobj $VmObj 

	<#============================================
	McAfee (Windows Only)
	#============================================#>
	write-host "Validating McAfee"

	$validateMcafee = Get-McAfeeCheck -vmobj $VmObj 

	<#============================================
	Splunk
	#============================================#>
	# splunk needs to be reformatted
	write-host "Validating Splunk Authentication"

	$splunkauth = Get-SplunkAuth -url $Url -SplunkCredential $SplunkCredential
	Start-Sleep -Seconds 5

	write-host "Validating Splunk Search"

	$splunksearch = Get-SplunkSearch -VmObj $VmObj -Url $url -Key $splunkauth[1]
	Start-Sleep -Seconds 5

	write-host "Validating Splunk Result"

	$splunkcheck = Get-SplunkResult -url $Url -Key $splunkauth[1] -Sid $splunksearch[1]
	Start-Sleep -Seconds 5

	<#============================================
	Tenable
	#============================================#>
	$validateTenable = @()

	write-host "Validating Tenable"
	$validateTenable = Get-TenableCheck -vmobj $VmObj -TenableAccessKey $TenableAccessKey -TenableSecretKey $TenableSecretKey

	$agentinfo = @()
	$agentinfo = $validateTenable[1]

	[System.Collections.ArrayList]$tennableVulnerabilities = @()
	if($VMRF.RunTenableScan -ne 'No'){
		$tennableVulnerabilities += Scan-Tenable -TenableAccessKey $TenableAccessKey -TenableSecretKey $TenableSecretKey -agentInfo $agentinfo
	} else{
		$tennableVulnerabilities.add([PSCustomObject]@{System = 'Tenable'
        Step = 'TenableCheck'
        SubStep = 'Tenable Scan'
        Status = 'Skipped'
        FriendlyError = ""
        PsError = ''}) > $null

		$tennableVulnerabilities.add($null) > $null

	}

<#============================================
Formulate Output
#============================================#>
	
	$HostInformation = @()
	$HostInformation = ($VmRF | select Hostname,
	@{n='Business Unit'; e={$VmObj.Tags.BU}},
	@{n='Location'; e={$VmObj.Location}},
	@{n='Owner'; e={$VmObj.Tags.Owner}},
	@{n='Patch Group'; e={$VmObj.Tags."Patch Group"}},
	@{n='Application'; e={$VmObj.Tags.Purpose}},
	@{n='Service Level'; e={$VmObj.Tags."Service Level"}},
	'Operating System', # $vmobj.StorageProfile.osdisk.OsType
	@{n='Physical or Virtual Server'; e={'Virtual'}},
	@{n='Network Information'; e={((get-aznetworkInterface -resourceid  $VmObj.NetworkProfile.NetworkInterfaces.id).ipconfigurations.subnet.id).split('/')[8]}},
	"DNS record created (if any)",
	@{n='Disk Information'; e={$vmobj.StorageProfile.DataDisks | select name, disksizeGB}}, 
	@{n='Date Created'; e={get-date -format 'MM/dd/yyyy'}},
	Requestor,
	@{n='Approver'; e={(get-aduser $($env:UserName)).name}},
	"Created By",
	'Ticket Number') 


	#environment Specific Information
	$EnvironmentSpecificInformation = @()
	$EnvironmentSpecificInformation = ($VmRF | select Subscription, 
	'Resource Group', 
	@{n='Instance'; e={$VmObj.Tags.Instance}})

	#Validation Steps and Status
	[System.Collections.ArrayList]$Validation  = @()
	$Validation += ($AzCheck | where {$_.gettype().name -eq 'ArrayList'})  
	$Validation += ($VmCheck | where {$_.gettype().name -eq 'ArrayList'} -ErrorAction SilentlyContinue)  
	$Validation += $validateErpmOU[0]
	$Validation += $validateErpmAdmins[0]  
	$Validation += $validateMcafee[0]  
	$Validation += $SplunkAuth[0]
	$Validation += $SplunkSearch[0]  
	$Validation += $SplunkCheck[0] 
	$Validation += $validateTenable[0] 
	$Validation += $tennableVulnerabilities[0] 

	# only input Errors section if there are error objects
	[System.Collections.ArrayList]$Errors  = @()
	if($null -ne ($validation | where PsError -ne '' | select step, PsError | fl)){
		$Errors += "Errors :"
		$Errors += "============================"
		$Errors += $validation | where PsError -ne '' | select step, PsError | fl
	}

	[System.Collections.ArrayList]$rawData  = @()
	#Azure Check
	$rawData += "`r`n______Azure Check_____"
	$rawData +=  ($AzCheck | where {$_.gettype().name -ne 'ArrayList'}) | fl
	#VM Services
	$rawData += "`r`n______VM Check - Services_____"
	$rawData += (($VmCheck | where {$_.gettype().name -ne 'ArrayList'} )[0] | ft)  
	#VM Updates
	$rawData += "`r`n_____VM Check - Updates______"
	$rawData += ($VmCheck | where {$_.gettype().name -ne 'ArrayList'})[1] 
	#VM ServerName
	$rawData += "`r`n_____VM Check - Server Name______"
	$rawData += (($VmCheck | where {$_.gettype().name -ne 'ArrayList'})[2]) | ft
	#ERPM OU
	$rawData += "`r`n_____ERPM Check - ActiveDirectory OU______"
	$rawData += $validateErpmOU[1] 
	#ERPM Admins
	$rawData += "`r`n_____ERPM Check - ERPM Admins______"
	$rawData += $validateErpmAdmins[1]
	#mcafee configuration
	$rawData += "`r`n_____McAfee Check - Agent Configuration______" 
	$rawData += $validateMcafee[1] 
	#mcafee check in
	$rawData += "`r`n_____McAfee Check - Check in Time______"
	$rawData += $validateMcafee[2] 
	#splunk
	$rawData += "`r`n_____Splunk Check______" 
	$rawData += ($SplunkCheck[1] | convertfrom-json -ErrorAction SilentlyContinue).results | fl
	#tenable config
	$rawData += "`r`n_____Tenable Check - Configuration______"
	$rawData += $validateTenable[1] | fl
	#tenable vulnerabilities
	$rawData += "`r`n_____Tenable Check - Vulnerabilities______"
	$rawData += $tennableVulnerabilities[1] | ft 


	#format output for textfile
	[System.Collections.ArrayList]$output = @()
	$output += "Host Information :"
	$output += "============================"
	$output += $HostInformation | fl
	$output += "Environment Specific Information :"
	$output += "============================"
	$output += $EnvironmentSpecificInformation | fl
	$output += "Validation Steps and Status :"
	$output += "============================"
	$output += $Validation | Select System, Step, SubStep, Status, FriendlyError | ft
	$output += $Errors
	$output += "Validation Step Output :"
	$output += "============================"
	$output += $rawData

	$date = get-date 
	#format output for SQL
	$sqloutput = @{}
	$sqloutput = [PSCustomObject]@{HostInformation = "$($HostInformation | convertto-json)";
		EnvironmentSpecificInformation = "$($EnvironmentSpecificInformation | convertto-json)";
		Status = "$($Validation | convertto-json -WarningAction SilentlyContinue)"
		Output_AzureCheck = "$(($AzCheck | where {$_.gettype().name -ne 'ArrayList'}) | ConvertTo-Json -WarningAction SilentlyContinue)";
		Output_VmCheck_Services = "$((($VmCheck | where {$_.gettype().name -ne 'ArrayList'} )[0] | convertto-json -WarningAction SilentlyContinue))";
		Output_VmCheck_Updates = "$(($VmCheck | where {$_.gettype().name -ne 'ArrayList'})[1] | convertto-json -WarningAction SilentlyContinue)";
		Output_VmCheck_ServerName = "$((($VmCheck | where {$_.gettype().name -ne 'ArrayList'})[2]) | convertto-json -WarningAction SilentlyContinue)";
		Output_ERPMCheck_OU = "$($validateErpmOU[1] | convertto-json -WarningAction SilentlyContinue)";
		Output_ERPMCheck_Admins = "$($validateErpmAdmins[1] | convertto-json -WarningAction SilentlyContinue)";
		Output_McafeeCheck_Configuration = "$($validateMcafee[1] | convertto-json -WarningAction SilentlyContinue)";
		Output_McafeeCheck_Checkin = "$($validateMcafee[2] | convertto-json -WarningAction SilentlyContinue)";
		Output_SplunkCheck = "$(($SplunkCheck[1] | convertfrom-json -ErrorAction SilentlyContinue).results | convertto-json -WarningAction SilentlyContinue)";
		Output_TenableCheck_Configuration = "$($validateTenable[1] | convertto-json -WarningAction SilentlyContinue)";
		Output_TenableCheck_Vulnerabilites = "$($tennableVulnerabilities[1] | convertto-json -WarningAction SilentlyContinue)";
		DateTime = [DateTime]::ParseExact($((get-date $date -format 'YYYY-MM-dd hh:mm:ss')), 'YYYY-MM-dd hh:mm:ss', [System.Globalization.CultureInfo]::InvariantCulture);
		TicketNumber = $($HostInformation."Ticket Number");
		Hostname = $($HostInformation.Hostname)}

<#============================================
Write Output to Text file 
#============================================#>	
	$filename = "$($vmRF.Hostname)_$($date.ToString('yyyy-MM-dd.hh.mm'))" 
	$output | Out-File "c:\temp\$filename.txt"

<#============================================
Write Output to database
#============================================#>

$DataTable = $sqloutput | ConvertTo-DbaDataTable 



$DataTable | Write-DbaDbTableData -SqlInstance $sqlinstance `
-Database $sqlDatabase  `
-Table dbo.ORR_Checks `
-SqlCredential $SqlCredential 
