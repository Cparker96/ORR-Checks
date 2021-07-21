
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
$Credential = @()
$VM = @()


$VmRF = Get-Content .\VM_Request_Fields.json | convertfrom-json -AsHashtable

if(!$VmRF)
{
	Write-Error "Please cd to the directory where the VM_Request_Fields.json file is" -ErrorAction Stop
}

<#============================================
Check VM in Azure
============================================#>
$AzCheck = @()

# will log you into Azure
#returns 2 objects, a Validation checks object and an Azure VM object (if )
$AzCheck = get-AzureCheck -VmName $VmRf.Hostname `
-Environment $VmRF.Environment `
-Subscription $VmRF.Subscription `
-ResourceGroup $VmRF.'Resource Group' 

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


<#============================================
Log into VM and do pre domain join checks
#============================================#>
$VmCheck = @()

$VmCheck = Get-VMCheck -VmObj $VmObj

try{
	$VmCheck | ft
	foreach($step in $VmCheck.PsError)
	{
		if($step -ne '')
		{
			throw $step.PsError
		}
	}
}
catch
{
	Write-error "VM Checks Failed to Authenticate `r`n$($VmCheck.FriendlyError)" 
}

<#============================================
Check McAfee
#============================================#>

Get-McAfeeCheck



<#============================================

#============================================#>
$Solution = ($AzCheck | where {$_.gettype().name -eq 'ArrayList'}) + $VmCheck



$filename = "$($vmRF.Hostname)_$(get-date -Format 'MM-dd-yyyy.hh.mm')"
$Solution | export-csv "$filename.csv"