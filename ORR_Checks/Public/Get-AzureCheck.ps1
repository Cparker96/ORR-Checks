
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
        connect-AzAccount -ServicePrincipal -Environment $Environment -Credential $Credential -tenant $tenant -ErrorAction Stop  > $null  
    
        $Validation.add([PSCustomObject]@{System = 'Azure'
                        Step = 'Authentication'
                        SubStep = 'Login'
                        Status = 'Passed'
                        FriendlyError = ''
                        PsError = ''}) > $null 
    }
    Catch{
        $Validation.add([PSCustomObject]@{System = 'Azure'
                        Step = 'Authentication'
                        SubStep = 'Login'
                        Status = 'Failed'
                        FriendlyError = "Could not log in with App registration"
                        PsError = $PSItem.Exception.Message}) > $null

        # re throw the error
        throw

        # return the $validation object
        return $Validation
    }

    <#============================================
    Get VM object from Azure
    #============================================#>

    #set context (will error silently if subscription isn't a valid field)
    Set-AzContext -Subscription $Subscription > $null

    if(((Get-AzContext -ErrorAction Stop).subscription.name ) -ne $Subscription)
    {
        $Validation.add([PSCustomObject]@{System = 'Azure'
                        Step = 'Authentication'
                        SubStep = 'Context'
                        Status = 'Failed'
                        FriendlyError = "Your context did not change to the Subscription $Subscription. Please validate the Subscription Name is valid"
                        PsError = $PSItem.Exception.Message}) > $null
        
        # re throw a terminating error
        write-error "Your context did not change to the Subscription $Subscription. Please validate the Subscription Name is valid" -ErrorAction Stop

        # return the $validation object
        return $Validation
    }
    else {
        $Validation.add([PSCustomObject]@{System = 'Azure'
                    Step = 'Authentication'
                    SubStep = 'Context'
                    Status = 'Passed'
                    FriendlyError = ''
                    PsError = ''}) > $null
    }


    #get the VM object from Azure
    try{
        $VM = Get-AzVM -name $VmName  -ResourceGroupName $ResourceGroup -erroraction Stop

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
                        PsError = $PSItem.Exception.Message})  > $null
        # re throw the error
        throw

        # return the $validation object
        return $Validation
    }

    <#============================================
    Validate Tags
    #============================================#>

    #$Validation = @()
    
    $tags = ''

    $tags = $VM.Tags | convertto-json 

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
                        PsError = $PSItem.Exception.Message}) > $null
    }
    catch
    {
        $Validation.add([PSCustomObject]@{System = 'Azure'
                        Step = 'Validation'
                        SubStep = 'TagsSyntax'
                        Status = 'Failed'
                        FriendlyError = "Tags do not meet Validation"
                        PsError = $PSItem.Exception.Message}) > $null
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



