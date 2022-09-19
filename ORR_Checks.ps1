
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
catch{ write-error "Could not load VM_Request_Fields.json `r`n $($_.Exception)" -erroraction stop }

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
	$gccappid = Get-AzKeyVaultSecret -VaultName 'kv-308' -Name 'Decom-GCC-App-ID' -AsPlainText
    $gccappsecret = Get-AzKeyVaultSecret -VaultName 'kv-308' -Name 'Decom-GCC-Client-Secret' -AsPlainText
    $SqlCredential = New-Object System.Management.Automation.PSCredential ('ORRCheckSql', ((Get-AzKeyVaultSecret -vaultName "kv-308" -name 'ORRChecks-Sql').SecretValue))
	$SplunkCredential = New-Object System.Management.Automation.PSCredential ('svc_tis_midrange', ((Get-AzKeyVaultSecret -vaultName 'kv-308' -name 'ORRChecks-Splunk').SecretValue)) 
	#$GovAccount = New-Object System.Management.Automation.PSCredential ('768ca4de-5c94-4879-9c74-be8d0217ff01',((Get-AzKeyVaultSecret -vaultName 'kv-308' -name 'ORRChecks-GCCHAccess').SecretValue))
	$prodpass = Get-AzKeyVaultSecret -vaultName 'kv-308' -name 'SNOW-API-Password' -AsPlainText 
}
Catch{
	Write-Error "could not get keys from key vault" -ErrorAction Stop
}

Write-Host "Running ORR on Server $($VmRF.Hostname)" -ForegroundColor Yellow

# logging out for now, the Get-AzureCheck function will determine which cloud to login to
disconnect-azaccount > $null
disconnect-azaccount > $null
disconnect-azaccount > $null

<#============================================
Check VM in Azure
============================================#>
	$AzCheck = @()

	write-host "Validating Azure Object matches standards" -ForegroundColor Yellow

	# will log you into Azure and set context to where the VM is
	#returns 2 objects, a Validation checks object and an Azure VM object
	
	if ($VmRF.Environment -eq 'AzureCloud')
	{
		$AzCheck = get-AzureCheck -VmName $VmRf.Hostname `
		-Environment $VmRF.Environment `
		-Subscription $VmRF.Subscription `
		-ResourceGroup $VmRF.'Resource Group' `
		-VmRF $VmRF `
		-prodpass $prodpass
	} elseif ($VmRF.Environment -eq 'AzureUSGovernment_Old') {
		$AzCheck = get-AzureCheck -VmName $VmRf.Hostname `
		-Environment $VmRF.Environment `
		-Subscription $VmRF.Subscription `
		-ResourceGroup $VmRF.'Resource Group' `
		-VmRF $VmRF `
		-prodpass $prodpass
	} else {
		$gccappsecretsecure = ConvertTo-SecureString $gccappsecret -AsPlainText -Force
		$GovAccount = New-Object -TypeName System.Management.Automation.PSCredential -ArgumentList $gccappid, $gccappsecretsecure

		$AzCheck = get-AzureCheck -VmName $VmRf.Hostname `
		-Environment $VmRF.Environment `
		-Subscription $VmRF.Subscription `
		-ResourceGroup $VmRF.'Resource Group' `
		-VmRF $VmRF `
		-prodpass $prodpass `
		-GovAccount $GovAccount
	}

	#-prodpass $prodpass

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

	write-host "Validating $($Vmobj.Name) is set up for Domain Checks" -ForegroundColor Yellow

	If($vmobj.StorageProfile.OsDisk.OsType -eq 'Windows')
	{
		$VmCheck = Get-VMCheck_win -VmObj $VmObj -SqlCredential $SqlCredential -SqlInstance $sqlInstance -SqlDatabase $sqlDatabase
		$VmRF.'Operating System' = 'Windows'

		# validate ERPM (windows only)
		write-host "Validating ERPM for $($Vmobj.Name)"
		$validateErpmOU = Get-ERPMOUCheck_win -vmobj $VmObj
		$validateErpmAdmins = Get-ERPMAdminsCheck_win -vmobj $VmObj 

		# validate McAfee (windows only)
		write-host "Validating McAfee for $($Vmobj.Name)"
		$validateMcafee = Get-McAfeeCheck_winhj -vmobj $VmObj 

		# validating hostname entry status in SQL
		$validatehostname = Get-HostNameSQL -VmObj $VmObj -SqlCredential $SqlCredential -sqlInstance $sqlInstance -sqlDatabase $sqlDatabase

	} elseif ($vmobj.StorageProfile.OsDisk.OsType -eq 'Linux') {
		$VmRF.'Operating System' = 'Linux'

		# validate services are running on linux machines, not in the 3rd party tool just yet
		Write-Host "Validating services running on $($Vmobj.Name)"
		$validatesplunkstatus = Get-SplunkStatus_lnx -VmObj $VMobj
		$validatetenablestatus = Get-TenableStatus_lnx -VmObj $VMobj
		$validateMMA = Get-MMACheck_lnx -Vmobj $VMobj

		# validate updates (VM will be rebooted here before realm join)
		Write-Host "Validating updates and realm join for $($Vmobj.Name). Server will be rebooted"
		$validateupdates = Get-Updates_lnx -VmObj $VMobj
		$validaterealmjoin = Get-RealmJoin_lnx -VmObj $VMobj

		# validating hostname entry status in SQL
		$validatehostname = Get-HostNameSQL -VmObj $VmObj -SqlCredential $SqlCredential -sqlInstance $sqlInstance -sqlDatabase $sqlDatabase
	} else {
		Write-Error "Can not determine OS image on Azure VM object" -ErrorAction Stop
	}

	Write-Host "Validating Splunk for $($Vmobj.Name)" -ForegroundColor Yellow
	# splunk needs to be reformatted
	write-host "Validating Splunk Authentication"

	$splunkauth = Get-SplunkAuth -url $Url -SplunkCredential $SplunkCredential
	Start-Sleep -Seconds 30

	write-host "Validating Splunk Search"

	$splunksearch = Get-SplunkSearch -VmObj $VmObj -Url $url -Key $splunkauth[1]
	Start-Sleep -Seconds 30

	write-host "Validating Splunk Result"

	$splunkcheck = Get-SplunkResult -url $Url -Key $splunkauth[1] -Sid $splunksearch[1]
	Start-Sleep -Seconds 30

	<#============
	Tenable
	#=============#>
	$validateTenable = @()

	write-host "Validating Tenable for $($Vmobj.Name)" -ForegroundColor Yellow
	$validateTenable = Get-TenableCheck -vmobj $VmObj -TenableAccessKey $TenableAccessKey -TenableSecretKey $TenableSecretKey

	$agentinfo = @()
	$agentinfo = $validateTenable[1]

	[System.Collections.ArrayList]$tennableVulnerabilities = @()
	if ($VMRF.RunTenableScan -eq 'Yes')
	{
		$tennableVulnerabilities = Scan-Tenable -Vmobj $VmObj -TenableAccessKey $TenableAccessKey -TenableSecretKey $TenableSecretKey -agentInfo $agentinfo -Erroraction Stop
	} else {
		$tennableVulnerabilities.add([PSCustomObject]@{System = 'Tenable'
        Step = 'TenableCheck'
        SubStep = 'Tenable Scan'
        Status = 'Skipped'
        FriendlyError = ""
        PsError = ''}) > $null

		$tennableVulnerabilities.add($null) > $null
	}

<#=======================
Formulate Output
#========================#>
	
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

	if ($VMobj.StorageProfile.OsDisk.OsType -eq 'Windows')
	{
		$Validation += $validateErpmOU[0]
		$Validation += $validateErpmAdmins[0]  
		$Validation += $validateMcafee[0]
		$Validation += $validatehostname[0]
	} elseif ($VMobj.StorageProfile.OsDisk.OsType -eq 'Linux') {
		$Validation += $validatesplunkstatus[0]
		$Validation += $validatetenablestatus[0]
		$Validation += $validateupdates[0]
		$Validation += $validatehostname[0]
		# giving time for Heartbeat alerts to check in
		Start-Sleep -Seconds 60 
		$Validation += $validaterealmjoin[0]
		$Validation += $validateMMA[0]
	} else {
		Write-Error "Can not determine OS image on Azure VM object" -ErrorAction Stop
	}

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
	# Azure Check
	$rawData += "`r`n______Azure Check_____"
	$rawData +=  ($AzCheck | where {$_.gettype().name -ne 'ArrayList'}) | fl

	if ($VMobj.StorageProfile.OsDisk.OsType -eq 'Windows')
	{
		$rawData += "`r`n______VM Check - Services_____"
		$rawData += (($VmCheck | where {$_.gettype().name -ne 'ArrayList'} )[0] | ft)  
		# windows Updates
		$rawData += "`r`n_____VM Check - Updates______"
		$rawData += ($VmCheck | where {$_.gettype().name -ne 'ArrayList'})[1] 
		# ServerName
		$rawData += "`r`n_____VM Check - Server Name______"
		$rawData += $validatehostname[1]
		# ERPM OU
		$rawData += "`r`n_____ERPM Check - ActiveDirectory OU______"
		$rawData += $validateErpmOU[1] 
		# ERPM Admins
		$rawData += "`r`n_____ERPM Check - ERPM Admins______"
		$rawData += $validateErpmAdmins[1]
		# mcafee config
		$rawData += "`r`n_____McAfee Check - Agent Configuration______" 
		$rawData += $validateMcafee[1] 
		# mcafee check in
		$rawData += "`r`n_____McAfee Check - Check in Time______"
		$rawData += $validateMcafee[2] 
	} elseif ($VMobj.StorageProfile.OsDisk.OsType -eq 'Linux') {
		# splunk check on server
		$rawData += "`r`n_____VM Check - Splunk______"
		$rawData += $validatesplunkstatus[1]
		# tenable check on server
		$rawData += "`r`n_____VM Check - Tenable______"
		$rawData += $validatetenablestatus[1]
		# linux kernel updates
		$rawData += "`r`n_____Linux Updates______"
		$rawData += $validateupdates[1]
		# restart vm to apply updates
		$rawData += "`r`n_____Restart VM______"
		$rawData += $validateupdates[2]
		# realm join
		$rawData += "`r`n_____Realm Join______"
		$rawData += $validaterealmjoin[1]
		# MMA in Azure
		$rawData += "`r`n_____MMA Configuration______"
		$rawData += $validateMMA[1]
	} else {
		Write-Error "Can not determine OS image on Azure VM object" -ErrorAction Stop
	}

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
	# format output for SQL
	$sqloutput = @{}

	# if the VM is linux, need to change a few fields before it gets outputted to sql table
	if ($VMobj.StorageProfile.OsDisk.OsType -eq 'Windows')
	{
		$sqloutput = [PSCustomObject]@{HostInformation = "$($HostInformation | convertto-json)";
		EnvironmentSpecificInformation = "$($EnvironmentSpecificInformation | convertto-json)";
		Status = "$($Validation | convertto-json -WarningAction SilentlyContinue)"
		Output_AzureCheck = "$(($AzCheck | where {$_.gettype().name -ne 'ArrayList'}) | ConvertTo-Json -WarningAction SilentlyContinue)";
		Output_VmCheck_Services = "$((($VmCheck | where {$_.gettype().name -ne 'ArrayList'} )[0] | convertto-json -WarningAction SilentlyContinue))";
		Output_VmCheck_Updates = "$(($VmCheck | where {$_.gettype().name -ne 'ArrayList'})[1] | convertto-json -WarningAction SilentlyContinue)";
		Output_VmCheck_ServerName = "$($validatehostname[1] | convertto-json -WarningAction SilentlyContinue)";
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
	} elseif ($VMobj.StorageProfile.OsDisk.OsType -eq 'Linux') {
		$sqloutput = [PSCustomObject]@{HostInformation = "$($HostInformation | convertto-json)";
		EnvironmentSpecificInformation = "$($EnvironmentSpecificInformation | convertto-json)";
		Status = "$($Validation | convertto-json -WarningAction SilentlyContinue)"
		Output_AzureCheck = "$(($AzCheck | where {$_.gettype().name -ne 'ArrayList'}) | ConvertTo-Json -WarningAction SilentlyContinue)";
		Output_VmCheck_Services = "$(($validatesplunkstatus[1] + $validatetenablestatus[1] | convertto-json -WarningAction SilentlyContinue))";
		Output_VmCheck_Updates = "$(($validateupdates[1] | where {$_.gettype().name -ne 'ArrayList'})[1] | convertto-json -WarningAction SilentlyContinue)";
		Output_VmCheck_ServerName = "$($validatehostname[1] | convertto-json -WarningAction SilentlyContinue)";
		Output_ERPMCheck_OU = "$($validateErpmOU[1] | convertto-json -WarningAction SilentlyContinue)";
		Output_ERPMCheck_Admins = "$($validateErpmAdmins[1] | convertto-json -WarningAction SilentlyContinue)";
		Output_McafeeCheck_Configuration = "$($validateMcafee[1] | convertto-json -WarningAction SilentlyContinue)";
		Output_McafeeCheck_Checkin = "$($validateMcafee[2] | convertto-json -WarningAction SilentlyContinue)";
		Output_SplunkCheck = "$(($SplunkCheck[1] | convertfrom-json -ErrorAction SilentlyContinue).results | convertto-json -WarningAction SilentlyContinue)";
		Output_TenableCheck_Configuration = "$($validateTenable[1] | convertto-json -WarningAction SilentlyContinue)";
		Output_TenableCheck_Vulnerabilites = "$($tennableVulnerabilities[1] | convertto-json -WarningAction SilentlyContinue)";
		DateTime = [DateTime]::ParseExact($((get-date $date -format 'YYYY-MM-dd hh:mm:ss')), 'YYYY-MM-dd hh:mm:ss', [System.Globalization.CultureInfo]::InvariantCulture);
		TicketNumber = $($HostInformation."Ticket Number");
		Hostname = $($HostInformation.Hostname);
		Output_RealmJoinCheck = $($validaterealmjoin[1] | convertto-json -WarningAction SilentlyContinue);
		Output_MMACheck = $($validateMMA[1] | convertto-json -WarningAction SilentlyContinue)}
	}

<#==============================
Write Output to Text file 
#===============================#>	

$filename = "$($vmRF.Hostname)_$($date.ToString('yyyy-MM-dd.hh.mm'))" 
	
# have to change outputrendering variable because of encoding issues - it will change back to default
$prevRendering = $PSStyle.OutputRendering
$PSStyle.OutputRendering = 'PlainText'

try {
    $output | Out-File "C:\Temp\$($filename).txt"
}
catch {
    $PSItem.Exception
} 

$PSStyle.OutputRendering = $prevRendering

Write-Host "Wrote ORR output of $($Vmobj.Name) to a .txt file - Check the C:\Temp directory" -ForegroundColor Yellow

<#===============================
Write Output to database
#================================#>

$DataTable = $sqloutput | ConvertTo-DbaDataTable 

$DataTable | Write-DbaDbTableData -SqlInstance $sqlinstance `
-Database $sqlDatabase  `
-Table dbo.ORR_Checks `
-SqlCredential $SqlCredential 
