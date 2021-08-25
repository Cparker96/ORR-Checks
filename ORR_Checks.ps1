
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
$VmRF = @()
$AzCheck = @()
$VMobj = @()
$validateErpm = @()
$validateErpmAdmins = @()
$validateMcafee = @()
$validateTenable = @()
$tennableVulnerabilities = @()
$Cred = @()

#get Server Build variables from VM_Request_Fields.json
Try
{
	$VmRF = Get-Content .\ORR_Checks\VM_Request_Fields.json | convertfrom-json -AsHashtable
}
catch{ write-error "Could not load VM_Reques_Fields.json `r`n $($_.Exception)"}

<#============================================
Get Credentials
#============================================#>
Try{
	#connect to Public azure and make sure the context is Enterprise where the keyvault exists
	Connect-AzAccount -Environment AzureCloud -Tenant '2d5b202c-8c07-4168-a551-66f570d429b3' > $null
	Set-AzContext -Subscription 'Enterprise' > $null

	$TenableAccessKey = Get-AzKeyVaultSecret -vaultName 'kv-308' -name 'TenableAccessKey' -AsPlainText > $null
	$TenableSecretKey = Get-AzKeyVaultSecret -vaultName 'kv-308' -name 'TenableSecretKey' -AsPlainText > $null
    $SqlCredential = New-Object System.Management.Automation.PSCredential ('testuser', ((Get-AzKeyVaultSecret -vaultName "tisutility" -name 'testuser').SecretValue))
}
Catch{

}

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
	try{
		$VmObj = $AzCheck | where {$_.gettype().name -eq 'PSVirtualMachine'}
		foreach($step in $azcheck.PsError)
		{
			if($step -ne ''){	throw $step.PsError}
		}
	}
	catch{
		Write-error "Azure Checks Failed to Authenticate `r`n$($AzCheck.FriendlyError)" -erroraction Stop
	}


<#============================================
Log into VM and do pre domain join checks
#============================================#>
	$VmCheck = @()

	write-host "Validating VM is set up for Domain Checks"

	if($null -ne $vmobj.OSProfile.WindowsConfiguration) #if a windows server
	{
		$VmCheck = Get-VMCheck -VmObj $VmObj -SqlCredential $SqlCredential
	}
	elseif($null -ne $vmobj.OSProfile.LinuxConfiguration) #if a Linux server
	{
		# $VmCheck = Get-VMCheck_Linux -VmObj $VmObj
	}


	try{
		foreach($step in $VmCheck.PsError)
		{
			if($step -ne ''){ throw $step.PsError}
		}
	}
	catch
	{
		Write-error "VM Checks Failed to Authenticate `r`n$($VmCheck.FriendlyError)" 
	}

<#============================================
#
#
#  Assumes Server is Joined to the domain if windows
#
#
#============================================#>
	if($null -ne $vmobj.OSProfile.WindowsConfiguration) #if a windows server
	{
		
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
	<#
	$SplunkCheck = @()

	write-host "Validating Splunk"

	$SplunkCheck = get-SplunkCheck -Credential $Credential `
	-Search $search

	#seperate the VM object from the azCheck object
	try{
		$AzCheck | ft
		$VmObj = $AzCheck | where {$_.gettype().name -eq 'PSVirtualMachine'}
		foreach($step in $azcheck.PsError)
		{
			if($step -ne '')
			{
				throw $step.PsError
			}
		}
	}
	catch{
		Write-error "Azure Checks Failed to Authenticate `r`n$($AzCheck.FriendlyError)" -erroraction Stop
	}
	#>


	<#============================================
	Tenable
	#============================================#>
	$validateTenable = @()

	write-host "Validating Tenable"
	$validateTenable = Get-TenableCheck -vmobj $VmObj -AccessKey $TenableAccessKey -SecretKey $TenableSecretKey

	#$tennableVulnerabilities = Scan-Tenable -AccessKey $TenableAccessKey -SecretKey $TenableSecretKey

<#============================================
Formulate Output
#============================================#>
	$output = ($VmRF | select Hostname,
	@{n='Business Unit'; e={$VmObj.Tags.BU}}, 
	Subscription,
	'Resource Group',
	@{n='Region'; e={$VmObj.Location}},
	@{n='Instance'; e={$VmObj.Tags.Instance}},
	@{n='Owner'; e={$VmObj.Tags.Owner}},
	@{n='Patch Group'; e={$VmObj.Tags."Patch Group"}},
	@{n='Purpose'; e={$VmObj.Tags.Purpose}},
	@{n='Service Level'; e={$VmObj.Tags."Service Level"}},
	@{n='Virtual Network'; e={((get-aznetworkInterface -resourceid  $VmObj.NetworkProfile.NetworkInterfaces.id).ipconfigurations.subnet.id).split('/')[8]}},
	'Operating System', # $vmobj.StorageProfile.osdisk.OsType
	@{n='Physical or Virtual Server'; e={'Virtual'}},
	'Datavail Support',
	@{n='Date Created'; e={get-date -format 'MM/dd/yyyy'}},
	Requestor,
	@{n='Approver'; e={(get-aduser $($env:UserName)).name}},
	"Created By",
	'Ticket Number' | fl) + 
	(($AzCheck | where {$_.gettype().name -eq 'ArrayList'}) + 
	($VmCheck | ft) + $validateErpm[0] + 
	$validateErpmAdmins[0] + 
	$validateMcafee[0] + 
	$SplunkCheck[0] + 
	$validateMcafee[0] + 
	$validateTenable[0])


	$filename = "$($vmRF.Hostname)_$(get-date -Format 'MM-dd-yyyy.hh.mm')"
	$output | Out-File "c:\temp\$filename.txt"

