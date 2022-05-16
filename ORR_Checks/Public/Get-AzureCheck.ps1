
<#
    .SYNOPSIS
        Validate VM in Azure
    .DESCRIPTION
        This function Logs into Azure and pulls the VM object to validate Tags, Naming Standard and Configuration
    .PARAMETER Environment
        The Microsft name for the Cloud you want to log into. For a full list run get-azenvironment
    .EXAMPLE
        get-AzureCheck -VmName 'TXBMMLINKGCCT02' `
        -Environment AzureCloud `
        -Subscription Enterprise `
        -ResourceGroup 308-Utility `
        -Credential $credential
            

    .NOTES
        FunctionName    : get-AzureCheck
        Created by      : Claire Larvin
        Date Coded      : 04/16/2021
        Modified by     : Claire Larvin
        Date Modified   : 1/26/2022

#>
Function Get-AzureCheck{
    Param(
        [parameter(Position = 0, Mandatory=$true)] [String] $VmName,
        [parameter(Position = 1, Mandatory=$true)] [ValidateSet('AzureUSGovernment', 'AzureUSGovernment_Old', 'AzureCloud')] [String] $Environment,
        [parameter(Position = 2, Mandatory=$true)] [String] $Subscription,
        [parameter(Position=3, Mandatory=$true)] [String] $ResourceGroup ,
        [parameter(Position=4, Mandatory=$false)] [String] $Region,
        [parameter(Position=5, Mandatory=$false)] [String] $Network,
        [parameter(Position=6, Mandatory=$false)] $GovAccount,
        [parameter(Position=7, Mandatory=$false)] $VmRF,
        [parameter(Position=8, Mandatory=$false)] $prodpass
        )

    [System.Collections.ArrayList]$Validation = @()
    $VM = @()
    $ScriptPath = "$((get-module ORR_Checks).modulebase)\Private"
    <#
    $VmRF = Get-Content "C:\Users\bh47391\Documents\_CodeRepos\ORR_Checks\VM_Request_Fields.json" | convertfrom-json -AsHashtable
    $VmName = $VmRF.Hostname
    $environment = $VmRF.Environment
    $subscription = $VmRF.Subscription
    $ResourceGroup = $VmRF.'Resource Group'
    #>

    <#============================================
    Login to Azure
    # Public Cloud - "AzureCloud" 
    # Azure Gov - "AzureUSGovernment_Old"
    # Azure Gov GCC High - "AzureUSGovernment" 
    #============================================#>

    # AD tenant is required when loggin in with an app registration


    #disconnect previous connections and log in with individual access
    Try{
        if((get-azcontext -erroraction stop).Environment.name -ne $Environment)
        {
            disconnect-AzAccount > $null

            if($Environment -eq 'AzureCloud'){
                $tenant = '2d5b202c-8c07-4168-a551-66f570d429b3'
                connect-AzAccount -Environment $Environment -tenant $tenant -ErrorAction Stop -WarningAction Ignore >$null
            }
            elseif($Environment -eq 'AzureUSGovernment_Old'){
                $tenant = '51ac4d1e-71ed-45d8-9b0e-edeab19c4f49'
                connect-AzAccount -Environment $Environment -tenant $tenant -ErrorAction Stop -WarningAction Ignore >$null
            }
            elseif($Environment -eq 'AzureUSGovernment'){
                $tenant = 'b347614d-8a51-4dfe-8bf7-16d51e6f6db8'
                connect-AzAccount -Credential $GovAccount -Environment $Environment -tenant $tenant -ServicePrincipal -ErrorAction Stop -WarningAction Ignore >$null
            }     
        }
    }
    Catch{
        $Validation.add([PSCustomObject]@{System = 'Azure'
                        Step = 'AzureCheck'
                        SubStep = 'Authentication'
                        Status = 'Failed'
                        FriendlyError = "Could not log in to Azure"
                        PsError = $PSItem.Exception}) > $null

        # return the $validation object
        return ($Validation)
    }

    <#============================================
    Get VM object from Azure
    #============================================#>

    #set context (will error silently if subscription isn't a valid field)
    try {
        Set-AzContext -Subscription $Subscription -ErrorAction Stop > $null
        $azContext = (Get-AzContext -ErrorAction Stop)
        if(($azContext.subscription.name ) -ne $Subscription)
        {
            throw ('Subscription does not match {0}, returned ' -f $Subscription, $azContext.subscription.name)
        }
    }
    catch {
        $Validation.add([PSCustomObject]@{System = 'Azure'
                        Step = 'AzureCheck'
                        SubStep = 'Authentication'
                        Status = 'Failed'
                        FriendlyError = "Your context did not change to the Subscription $Subscription. Please validate the Subscription Name is valid"
                        PsError = $PSItem.Exception}) > $null

        # return the $validation object
        return ($Validation)
    }
    #return validation object
    $Validation.add([PSCustomObject]@{System = 'Azure'
    Step = 'AzureCheck'
    SubStep = 'Authentication'
    Status = 'Passed'
    FriendlyError = ''
    PsError = ''}) > $null 
 
    #get the VM object from Azure
    try{
        $VM = Get-AzVM -name $VmName -ResourceGroupName $ResourceGroup -erroraction Stop

        $Validation.add([PSCustomObject]@{System = 'Azure'
                        Step = 'AzureCheck'
                        SubStep = 'VMObject'
                        Status = 'Passed'
                        FriendlyError = ''
                        PsError = ''}) > $null
    }
    catch{
        $Validation.add([PSCustomObject]@{System = 'Azure'
                        Step = 'AzureCheck'
                        SubStep = 'VMObject'
                        Status = 'Failed'
                        FriendlyError = "Could not validate that the Server $VmName exists in Azure.`r`nAzure Cloud : $environment`r`nSubscription : $Subscription `r`nAzure Cloud : $ResourceGroup"
                        PsError = $PSItem.Exception})  > $null

        # return the $validation object
        return ($Validation)
    }

    <#============================
    Validate VM Build Specs
    #=============================#>

    $user = "sn.datacenter.integration.user"
	$pass = $prodpass

	# Build auth header
	$base64AuthInfo = [Convert]::ToBase64String([Text.Encoding]::ASCII.GetBytes(("{0}:{1}" -f $user, $pass)))

	# Set proper headers
	$headers = New-Object "System.Collections.Generic.Dictionary[[String],[String]]"
	$headers.Add('Authorization',('Basic {0}' -f $base64AuthInfo))
	$headers.Add('Accept','application/json')
	$headers.Add('Content-Type','application/json')

	$sctaskmeta = "https://textrontest2.servicenowservices.com/api/now/table/sc_task?sysparm_query=number%3D$($VmRF.'Ticket Number')&sysparm_fields=variables.azure_datacenter, `
	variables.azure_subscription,variables.resource_group,variables.date_needed,variables.operating_system,variables.amount_of_memory,variables.number_of_cores, `
    variables.server_type,variables.instance,variables.service_level,variables.patch_day"

	$getsctask = Invoke-RestMethod -Headers $headers -Method Get -Uri $sctaskmeta

    # check that VM is in correct sub/RG
    $substringid = $VM.id.split('/')
    $subid = $substringid[2]

    try 
    {
        if ($subid -eq $getsctask.result.'variables.azure_subscription')
        {
            $Validation.add([PSCustomObject]@{System = 'Azure'
            Step = 'AzureCheck'
            SubStep = 'Server Sub'
            Status = 'Passed'
            FriendlyError = ''
            PsError = ''}) > $null
        } else {
            $Validation.add([PSCustomObject]@{System = 'Azure'
            Step = 'AzureCheck'
            SubStep = 'Server Sub'
            Status = 'Failed'
            FriendlyError = 'Subscriptions between server and requestor input do not match'
            PsError = $PSItem.Exception}) > $null
        }
    } catch {
        $Validation.add([PSCustomObject]@{System = 'Azure'
        Step = 'AzureCheck'
        SubStep = 'Server Sub'
        Status = 'Failed'
        FriendlyError = 'Could not verify subscription matched user input'
        PsError = $PSItem.Exception}) > $null

        return $Validation
    }

    try
    {
        if ($VM.ResourceGroupName -eq $getsctask.result.'variables.resource_group')
        {
            $Validation.add([PSCustomObject]@{System = 'Azure'
            Step = 'AzureCheck'
            SubStep = 'Server RG'
            Status = 'Passed'
            FriendlyError = ''
            PsError = ''}) > $null
        } else {
            $Validation.add([PSCustomObject]@{System = 'Azure'
            Step = 'AzureCheck'
            SubStep = 'Server RG'
            Status = 'Failed'
            FriendlyError = 'Resource Groups between server and requestor input do not match'
            PsError = $PSItem.Exception}) > $null
        }
    } catch {
        $Validation.add([PSCustomObject]@{System = 'Azure'
        Step = 'AzureCheck'
        SubStep = 'Server RG'
        Status = 'Failed'
        FriendlyError = 'Could not verify that RG matched user input'
        PsError = $PSItem.Exception}) > $null

        return $Validation
    }

    # check that datacenter matches location
    $vmlocation = $VM.Location
    $locationalias = Get-AzLocation | where {$_.Location -eq $vmlocation}

    try
    {
        if (($locationalias -eq $VM.location) -and ($locationalias -eq $getsctask.result.'variables.azure_datacenter'))
        {
            $Validation.add([PSCustomObject]@{System = 'Azure'
            Step = 'AzureCheck'
            SubStep = 'Server Location'
            Status = 'Passed'
            FriendlyError = ''
            PsError = ''}) > $null
        } else {
            $Validation.add([PSCustomObject]@{System = 'Azure'
            Step = 'AzureCheck'
            SubStep = 'Server Location'
            Status = 'Failed'
            FriendlyError = 'Azure region and requestor input do not match'
            PsError = $PSItem.Exception}) > $null
        }
    } catch {
        $Validation.add([PSCustomObject]@{System = 'Azure'
        Step = 'AzureCheck'
        SubStep = 'Server Location'
        Status = 'Failed'
        FriendlyError = 'Could not retrieve server location and match'
        PsError = $PSItem.Exception}) > $null

        return $Validation
    }

    # check number of cores/size
    $vmskuname = Get-AzVMSize -ResourceGroupName $VM.ResourceGroupName -VMName $VM.Name | where {$_.Name -eq $VM.HardwareProfile.VmSize}

    # doing math on the total memory requested (shown in MB - needs to be GB for validation)
    $memoryamountmath = $vmskuname.MemoryInMB / 1024

    try
    {
        if (($vmskuname.NumberOfCores -eq $getsctask.result.'variables.number_of_cores') -and ($memoryamountmath -eq $getsctask.result.'variables.amount_of_memory'))
        {
            $Validation.add([PSCustomObject]@{System = 'Azure'
            Step = 'AzureCheck'
            SubStep = 'Server Size'
            Status = 'Passed'
            FriendlyError = ''
            PsError = ''}) > $null
        } else {
            $Validation.add([PSCustomObject]@{System = 'Azure'
            Step = 'AzureCheck'
            SubStep = 'Server Size'
            Status = 'Failed'
            FriendlyError = 'Memory Size and requestor input do not match'
            PsError = $PSItem.Exception}) > $null
        }
    } catch {
        $Validation.add([PSCustomObject]@{System = 'Azure'
        Step = 'AzureCheck'
        SubStep = 'Server Size'
        Status = 'Failed'
        FriendlyError = 'Could not determine whether server size and requestor input match. Please try again'
        PsError = $PSItem.Exception}) > $null

        return $Validation
    }

    # check server instance
    try
    {
        $getvmtags = Get-AzTag -ResourceId $VM.Id

        if ($getvmtags.Properties.TagsProperty['Instance'] -eq $getsctask.result.'variables.instance'.ToUpper())
        {
            $Validation.add([PSCustomObject]@{System = 'Azure'
            Step = 'AzureCheck'
            SubStep = 'Server Instance'
            Status = 'Passed'
            FriendlyError = ''
            PsError = $PSItem.Exception}) > $null
        } else {
            $Validation.add([PSCustomObject]@{System = 'Azure'
            Step = 'AzureCheck'
            SubStep = 'Server Instance'
            Status = 'Failed'
            FriendlyError = 'Instance tag and requestor input do not match'
            PsError = $PSItem.Exception}) > $null
        }
    } catch {
        $Validation.add([PSCustomObject]@{System = 'Azure'
        Step = 'AzureCheck'
        SubStep = 'Server Instance'
        Status = 'Failed'
        FriendlyError = 'Could not determine whether instance and requestor input match. Please try again'
        PsError = $PSItem.Exception}) > $null

        return $Validation
    }

    # check service level
    try
    {
        if ($getvmtags.Properties.TagsProperty['Service Level'] -eq $getsctask.result.'variables.service_level')
        {
            $Validation.add([PSCustomObject]@{System = 'Azure'
            Step = 'AzureCheck'
            SubStep = 'Service Level'
            Status = 'Passed'
            FriendlyError = ''
            PsError = $PSItem.Exception}) > $null
        } else {
            $Validation.add([PSCustomObject]@{System = 'Azure'
            Step = 'AzureCheck'
            SubStep = 'Service Level'
            Status = 'Failed'
            FriendlyError = 'Service level tag and requestor input do not match'
            PsError = $PSItem.Exception}) > $null
        }
    } catch {
        $Validation.add([PSCustomObject]@{System = 'Azure'
        Step = 'AzureCheck'
        SubStep = 'Service Level'
        Status = 'Failed'
        FriendlyError = 'Could not determine whether service level and requestor input match. Please try again'
        PsError = $PSItem.Exception}) > $null

        return $Validation
    }
    
    <#============================================
    Validate Tags
    #============================================#>

    #$Validation = @()
    
    $tags = @()
    $tags = $VM.Tags | convertto-json 

    # Check All required tags are there and they meet the Tagging syntax standards
    Try
    {
        #Validate that all tags exist and meet syntax standards
        $tags | test-json -schemafile "$ScriptPath\Tags_Definition.json" -ErrorAction stop > $null
        
        #if an error is not thrown then provide the 
        $Validation.add([PSCustomObject]@{System = 'Azure'
                        Step = 'AzureCheck'
                        SubStep = 'TagsSyntax'
                        Status = 'Passed'
                        FriendlyError = ''
                        PsError = ''}) > $null
    }
    catch
    {
        $Validation.add([PSCustomObject]@{System = 'Azure'
                        Step = 'AzureCheck'
                        SubStep = 'TagsSyntax'
                        Status = 'Failed'
                        FriendlyError = "Tags do not meet Validation - $($PSItem.ErrorDetails)"
                        PsError = $PSItem.Exception}) > $null
    }

        
    <#============================================
    Check permissions
    #============================================#>
    If($Environment -ne 'AzureUSGovernment')
    {
    $role = @()
    $role = Get-AzRoleAssignment -RoleDefinitionName 'Contributor' -Scope $vm.Id 
    $role += Get-AzRoleAssignment -RoleDefinitionName 'Owner' -Scope $vm.Id

    $elevatedUsers = @()
    $elevatedUsers = $role.SignInName 
    $elevatedUsers += ($role | where objecttype -eq 'Group' | %{get-azadgroupmember -GroupObjectId $_.ObjectId} | select userPrincipalName).userPrincipalName
    $elevatedUsers += "768ca4de-5c94-4879-9c74-be8d0217ff01"
    #if the contributor role isn't checked out then fail
    if($azContext.Account.Id -notin $elevatedUsers){
        $Validation.add([PSCustomObject]@{System = 'Azure'
        Step = 'AzureCheck'
        SubStep = 'Access'
        Status = 'Failed'
        FriendlyError = "Please Check out your Contributor Role over scope $($vm.id)"
        PsError = ''}) > $null
    }
    else {
        $Validation.add([PSCustomObject]@{System = 'Azure'
        Step = 'AzureCheck'
        SubStep = 'Access'
        Status = 'Passed'
        FriendlyError = ""
        PsError = ''}) > $null
    }}
    else {
        $Validation.add([PSCustomObject]@{System = 'Azure'
        Step = 'AzureCheck'
        SubStep = 'Access'
        Status = 'Passed'
        FriendlyError = ""
        PsError = ''}) > $null
    }

    return ($Validation, $VM)
}



