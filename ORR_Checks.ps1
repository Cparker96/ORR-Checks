
<#============================================
Manual process notes
	1) Get list of server builds from excel sheet
	2) Azure
		a. Check tags (sniff test)
			i. Backups 60
			ii. BU - correct
			iii. Instance matches naming standard
			iv. Service level
			v. Patch group if _Automation_ - 10M is on the hook
		b. Naming standard (in powerDMS)
			i. PROD 000-799
			ii. Dev 800-899
			iii. Test 900-999
		c. Server Config
			i. Check disks are associated
			ii. VM running
	3) Remote in
		a. Not domain joined - use IP to remote in
			i. Use IP/10MOnboarding password
		b. Are Services running
			i. Tennable
			ii. Microsoft monitoring agent
			iii. Splunk
			iv. Mcafee
		c. Domain Join in AD
			i. Create AD object first in right OU
				1) (OU in ticket
					a) If TXA Textron>corportate>USA>FEINsharedacrossTextron>servers>Azure (or AzureUSGov)
				2) New object >select user as _a
				3) Properties > member of  wsus_gpo_azure_universal (applies group policy)
		d. System info> advanced > computername >change to txt.textron.com
			i. Restart later
		e. Check for updates
			i. If errror then open admin powershell session > sconfig >6) download and upload updates> all updates
		f. Run script in devops TIS-0RR-Server-builds>window build scripts>provisionin scripts>Post_Domain_Join_configs.ps1 (must already be domain joined and run as admin)
			i. ADM_SRV_AZU - TIS Cloudops access
			ii. Svc_hq_erpm_svc - ERMP has access
			iii. Add admins from ticket as well (_a)
		g. Check that disks are mounted on the server
		h. Restart server
	4) Fill out ORR packet ( no order)
		a. fills out server information based on Server Tags - not from original ticket
			i. Approver can be infered from admin access - approver is their boss?
			ii. Save on sharepoint > cloud Ops > Azure > delivery packets
		b. Splunk.textron.com
			i. Index=win* host=SERVERNAME
		c. Mcafee/EPO (slow system)
			i. Systemtree>This group and all subgroups : SERVERNAME 
				1) 1 record
					a) SERVERNAME and green banner
		d. Tenable
			i. Classic interface >scans>agents> SERVERNAME
				1) Online
				2) In AzureOnboarding group
				3) In BU group
				4) (run scan) Play the AzureVMProvisioning group - will run a scan against all servers (will take 1-1.5 hours to complete so wait till you have done all the ORR's for the day)
					1) Check it is completed > assests> SERVERNAME
					2) Resolve veunrabilities
						a) Mcafee Agent 5.6 and Mcafeww endpoint security for windows is ok - WE are behind on Mcafee version
		e. ERPM
			i. RDP into server as admin 
				1) Provising script ERPM_varification.ps1
					a) OU path in AD
					b) AD groups on server
						i. ADM_SRV_AZU - TIS Cloudops access
						ii. Svc_hq_erpm_svc - ERMP has access
						iii. Add admins from ticket as well (_a)

Links:
	Nuget powershell module 
		https://docs.microsoft.com/en-us/azure/devops/artifacts/tutorials/private-powershell-library?view=azure-devops
#============================================#>



<#============================================
Get variables
#============================================#>
[Uri]$Url = "https://splk.textron.com:8089"
$VmRF = @()
$AzCheck = @()
$VMobj = @()
$validateErpm = @()
$validateErpmAdmins = @()
$validateMcafee = @()
$SplunkCheck = @()
$validateTenable = @()
$tennableVulnerabilities = @()
$SqlCredential = @()

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
	Connect-AzAccount -Environment AzureCloud -Tenant '2d5b202c-8c07-4168-a551-66f570d429b3' > $null
	Set-AzContext -Subscription 'Enterprise' > $null

	$TenableAccessKey = Get-AzKeyVaultSecret -vaultName 'kv-308' -name 'ORRChecks-TenableAccessKey' -AsPlainText 
	$TenableSecretKey = Get-AzKeyVaultSecret -vaultName 'kv-308' -name 'ORRChecks-TenableSecretKey' -AsPlainText 
    $SqlCredential = New-Object System.Management.Automation.PSCredential ('ORRCheckSql', ((Get-AzKeyVaultSecret -vaultName "kv-308" -name 'ORRChecks-Sql').SecretValue))
	$SplunkCredential = New-Object System.Management.Automation.PSCredential ('svc_tis_midrange', ((Get-AzKeyVaultSecret -vaultName 'kv-308' -name 'ORRChecks-Splunk').SecretValue)) 
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
	-ResourceGroup $VmRF.'Resource Group' 

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
	}elseif($vmobj.StorageProfile.OsDisk.OsType -eq 'Linux') #if a Linux server
	{
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

	$validateErpm = Get-ERPMOUCheck -vmobj $VmObj

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
	
	$splunkauth = Splunk-Auth -url $Url -SplunkCredential $SplunkCredential
	Start-Sleep -Seconds 5

	write-host "Validating Splunk Search"

	$splunksearch = Splunk-Search -url $Url -Key $splunkauth[1] -VmObj $VmObj
	Start-Sleep -Seconds 5

	write-host "Validating Splunk Result"

	$splunkcheck = Splunk-Result -url $Url -Key $splunkauth[1] -Sid $splunksearch[1]
	Start-Sleep -Seconds 5

	<#============================================
	Tenable
	#============================================#>
	$validateTenable = @()

	write-host "Validating Tenable"
	$validateTenable = Get-TenableCheck -vmobj $VmObj -AccessKey $TenableAccessKey -SecretKey $TenableSecretKey

	$agentinfo = @()
	$agentinfo = $validateTenable[1]
	
	$agentinfo = @()
	#$tennableVulnerabilities = Scan-Tenable -AccessKey $TenableAccessKey -SecretKey $TenableSecretKey -agentInfo $agentinfo

<#============================================
Formulate Output
#============================================#>

try{
	[System.Collections.ArrayList]$output = @()
	$output += "Host Information :"
	$output += "============================"
	$output += ($VmRF | select Hostname,
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
	'Ticket Number' | fl) 

	$output += "Environment Specific Information :"
	$output += "============================"
	$output += ($VmRF | select Subscription, 
	'Resource Group', 
	@{n='Instance'; e={$VmObj.Tags.Instance}} | fl)

	#Validation Steps and Status
	$output += "Validation Steps and Status :"
	$output += "============================"
	$Validation = [PSCustomObject](($AzCheck | where {$_.gettype().name -eq 'ArrayList'}) + 
	($VmCheck | where {$_.gettype().name -eq 'ArrayList'}) + 
	$validateErpm[0] + 
	$validateErpmAdmins[0] + 
	$validateMcafee[0] + 
	$SplunkCheck[0] +
	$validateTenable[0] +
	$tennableVulnerabilities[0]) 

	$output += $Validation | Select System, Step, SubStep, Status, FriendlyError | ft
	#+ $tennableVulnerabilities
	# $SplunkCheck[0] + 

	if($null -ne ($validation | where PsError -ne '' | select step, PsError | fl)){
		$output += "Errors :"
		$output += "============================"
		$output += $validation | where PsError -ne '' | select step, PsError | fl
	}

	$output += "Validation Step Output :"
	$output += "============================"

	[System.Collections.ArrayList]$rawData  = @()
	$rawData += $AzCheck[0] | select -unique System, Step
	$rawData += ($AzCheck | where {$_.gettype().name -ne 'ArrayList'} | fl)
	$rawData += "___________"
	$rawData += $VmCheck[0][0..3] | select -unique System, Step, SubStep 
	$rawData += (($VmCheck | where {$_.gettype().name -ne 'ArrayList'} )[0] | ft)  
	$rawData += "___________"
	$rawData += $VmCheck[0][4] | select -unique System, Step, SubStep 
	$rawData += ($VmCheck | where {$_.gettype().name -ne 'ArrayList'})[1] 
	$rawData += "___________"
	$rawData += $VmCheck[0][5] | select -unique System, Step, SubStep  
	$rawData += (($VmCheck | where {$_.gettype().name -ne 'ArrayList'})[2]) | ft
	$rawData += "___________"
	$rawData += $validateErpm[0] | select -unique System, Step, SubStep 
	$rawData += $validateErpm[1] 
	$rawData += "___________"
	$rawData += $validateErpmAdmins[0] | select -unique System, Step, SubStep 
	$rawData += $validateErpmAdmins[1] 
	$rawData += "___________"
	$rawData += $validateMcafee[0][0] | select -unique System, Step, SubStep 
	$rawData += $validateMcafee[1] 
	$rawData += "___________"
	$rawData += $validateMcafee[0][1] | select -unique System, Step, SubStep 
	$rawData += $validateMcafee[2] 
	$rawData += "___________"
	$rawData += $SplunkCheck[0] | select -unique System, Step, SubStep 
	$rawData += $SplunkCheck[1] 
	$rawData += "___________"
	$rawData += $validateTenable[0] | select -unique System, Step, SubStep
	$rawData += $validateTenable[1] 
	$rawData += "___________"
	$rawData += $tennableVulnerabilities[0] | select -unique System, Step, SubStep
	$rawData += $tennableVulnerabilities[1] #>

	$output += $rawData


	$filename = "$($vmRF.Hostname)_$(get-date -Format 'MM-dd-yyyy.hh.mm')"
	$output | Out-File "c:\temp\$filename.txt"
}catch{
	$filename = "$($vmRF.Hostname)_$(get-date -Format 'MM-dd-yyyy.hh.mm')"
	$output | Out-File "c:\temp\$filename.txt"
}


