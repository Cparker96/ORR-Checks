
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
        Modified by     : 
        Date Modified   : 

#>
Function Get-AzureCheck{
    Param(
        [parameter(Position = 0, Mandatory=$true)] [String] $VmName,
        [parameter(Position = 1, Mandatory=$true)] [ValidateSet('AzureUSGovernment', 'AzureCloud')] [String] $Environment,
        [parameter(Position = 2, Mandatory=$true)] [String] $Subscription,
        [parameter(Position=3, Mandatory=$true)] [String] $ResourceGroup ,
        [parameter(Position=3, Mandatory=$false)] [String] $Region,
        [parameter(Position=3, Mandatory=$false)] [String] $Network
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
    #============================================#>

    # AD tenant is required when loggin in with an app registration
    if($Environment -eq 'AzureCloud'){$tenant = '2d5b202c-8c07-4168-a551-66f570d429b3'}
    else{$tenant = '51ac4d1e-71ed-45d8-9b0e-edeab19c4f49'}
    
    #disconnect previous connections and log in with individual access
    Try{
        if((get-azcontext -erroraction stop).Environment.name -ne $Environment)
        {
            disconnect-AzAccount > $null
            connect-AzAccount -Environment $Environment -tenant $tenant -ErrorAction Stop -WarningAction Ignore >$null
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

    <#============================================
    Validate VM
    #============================================
    $VM | gm

    #don't need to check that Environment, Subscription and Resource Group match 
    #because you wouldn't be able to get the $vm object and it would fail validation
    
    #check it was build in the correct location 
    $VM.location -eq $Region

    #check it was built on the right subnet
    $Nic = ''
    $Nic = (Get-AzNetworkInterface -ResourceId $vm.NetworkProfile.networkinterfaces.id).IpConfigurations.subnet.id
    $bla = [regex]::Matches($nic, "Microsoft.Network\/virtualNetworks\/(?:.*)\/subnets\/(?:.*)") 
    $network -eq 

    "Region" : "USGovVirginia",
    "Virtual Network" : "",
    "Operating System" : "Windows Server 2016 Datacenter"
    #>
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
    $role = @()
    $role = Get-AzRoleAssignment -RoleDefinitionName 'Contributor' -Scope $vm.Id 
    $role += Get-AzRoleAssignment -RoleDefinitionName 'Owner' -Scope $vm.Id

    $elevatedUsers = @()
    $elevatedUsers = $role.SignInName 
    $elevatedUsers += ($role | where objecttype -eq 'Group' | %{get-azadgroupmember -GroupObjectId $_.ObjectId} | select userPrincipalName).userPrincipalName

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
    }
    <#============================================
    Validate all steps were taken and passed
    Step              SubStep
    ----              -------
    AzureCheck      Authentication
    AzureCheck      TagsSyntax
    AzureCheck      VMObject
    AzureCheck      Access
    ============================================#>

    return ($Validation, $VM)
}



