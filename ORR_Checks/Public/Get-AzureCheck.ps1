
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
        [parameter(Position=3, Mandatory=$true)] [String] $Region,
        [parameter(Position=3, Mandatory=$true)] [String] $Network,
        [parameter(Position=2, Mandatory=$true)] [PSCredential] $Credential
        )

    [System.Collections.ArrayList]$Validation = @()
    $VM = @()
    <#
    $VmRF = Get-Content "C:\Users\bh47391\Documents\_CodeRepo\TIS-Midrange\ORR_Checks\VM_Request_Fields.json" | convertfrom-json -AsHashtable
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
    
    #disconnect with individual access and log in with app registration
    Try{
        disconnect-AzAccount > $null
        connect-AzAccount -ServicePrincipal -Environment $Environment -Credential $Credential -tenant $tenant -ErrorAction Stop -WarningAction Ignore > $null  
    }
    Catch{
        $Validation.add([PSCustomObject]@{System = 'Azure'
                        Step = 'Authentication'
                        SubStep = 'Login'
                        Status = 'Failed'
                        FriendlyError = "Could not log in with App registration"
                        PsError = $PSItem.Exception}) > $null

        # return the $validation object
        return ($Validation, $VM)
    }

    $Validation.add([PSCustomObject]@{System = 'Azure'
                    Step = 'Authentication'
                    SubStep = 'Login'
                    Status = 'Passed'
                    FriendlyError = ''
                    PsError = ''}) > $null 

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
                        Step = 'Authentication'
                        SubStep = 'Context'
                        Status = 'Failed'
                        FriendlyError = "Your context did not change to the Subscription $Subscription. Please validate the Subscription Name is valid"
                        PsError = $PSItem.Exception}) > $null
        
        # re throw a terminating error
        #write-error "Your context did not change to the Subscription $Subscription. Please validate the Subscription Name is valid" -ErrorAction Stop

        # return the $validation object
        return ($Validation, $VM)
    }
   
    $Validation.add([PSCustomObject]@{System = 'Azure'
                Step = 'Authentication'
                SubStep = 'Context'
                Status = 'Passed'
                FriendlyError = ''
                PsError = ''}) > $null
    
    #get the VM object from Azure
    try{
        $VM = Get-AzVM -name $VmName -ResourceGroupName $ResourceGroup -erroraction Stop

        $Validation.add([PSCustomObject]@{System = 'Azure'
                        Step = 'Authentication'
                        SubStep = 'VM'
                        Status = 'Passed'
                        FriendlyError = ''
                        PsError = ''}) > $null
    }
    catch{
        $Validation.add([PSCustomObject]@{System = 'Azure'
                        Step = 'Authentication'
                        SubStep = 'VM'
                        Status = 'Failed'
                        FriendlyError = "Could not validate that the Server $VmName exists in Azure.`r`nAzure Cloud : $environment`r`nSubscription : $Subscription `r`nAzure Cloud : $ResourceGroup"
                        PsError = $PSItem.Exception})  > $null

        # return the $validation object
        return ($Validation, $VM)
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
        $tags | test-json -schemafile "$((get-module ORR_Checks).modulebase)\Private\Tags_Definition.json" -ErrorAction stop
        
        #if an error is not thrown then provide the 
        $Validation.add([PSCustomObject]@{System = 'Azure'
                        Step = 'Validation'
                        SubStep = 'TagsSyntax'
                        Status = 'Passed'
                        FriendlyError = ''
                        PsError = ''}) > $null
    }
    catch
    {
        $Validation.add([PSCustomObject]@{System = 'Azure'
                        Step = 'Validation'
                        SubStep = 'TagsSyntax'
                        Status = 'Failed'
                        FriendlyError = "Tags do not meet Validation - $($PSItem.ErrorDetails)"
                        PsError = $PSItem.Exception}) > $null
    }



    <#============================================
    Validate all steps were taken and passed
    Step              SubStep
    ----              -------
    Authentication    Login
    Authentication    Context
    Authentication    VM
    Validation        TagsSyntax
    Validation        TagsValue
    #============================================#>
    [System.Collections.ArrayList]$ValidationPassed = @()
    [void]$ValidationPassed.add([PSCustomObject]@{System = 'Azure'; Step = 'Authentication'; SubStep = 'Login'; Status = 'Passed'; FriendlyError = ''; PsError = ''})
    [void]$ValidationPassed.add([PSCustomObject]@{System = 'Azure'; Step = 'Authentication'; SubStep = 'Login'; Status = 'Passed'; FriendlyError = ''; PsError = ''})
    [void]$ValidationPassed.add([PSCustomObject]@{System = 'Azure'; Step = 'Authentication'; SubStep = 'Context'; Status = 'Passed'; FriendlyError = ''; PsError = ''})
    [void]$ValidationPassed.add([PSCustomObject]@{System = 'Azure'; Step = 'Authentication'; SubStep = 'VM'; Status = 'Passed'; FriendlyError = ''; PsError = ''})
    [void]$ValidationPassed.add([PSCustomObject]@{System = 'Azure'; Step = 'Validation'; SubStep = 'TagsSyntax'; Status = 'Passed'; FriendlyError = ''; PsError = ''})
    [void]$ValidationPassed.add([PSCustomObject]@{System = 'Azure'; Step = 'Validation'; SubStep = 'TagsValue'; Status = 'Passed'; FriendlyError = ''; PsError = ''})

    if(!(Compare-Object $Validation $ValidationPassed))
    {
        $Validation.add([PSCustomObject]@{System = 'Azure'
                        Step = 'Check'
                        SubStep = 'Passed'
                        Status = 'Passed'
                        FriendlyError = ''
                        PsError = ''}) > $null
    }
    else
    {
        $Validation.add([PSCustomObject]@{System = 'Azure'
                        Step = 'Check'
                        SubStep = 'Failed'
                        Status = 'Failed'
                        FriendlyError = ""
                        PsError = ''}) > $null
    }

    return ($Validation, $VM)
}



