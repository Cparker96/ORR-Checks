
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

    [pscustomobject]$Validation = @()

    <#============================================
    Login to Azure
    #============================================#>

    # AD tenant is required when loggin in with an app registration
    if($Environment -eq 'AzureCloud')
    {
        $tenant = '2d5b202c-8c07-4168-a551-66f570d429b3'
    }
    else
    {
        $tenant = '51ac4d1e-71ed-45d8-9b0e-edeab19c4f49'
    }
    
    #disconnect with individual access and log in with app registration
    disconnect-AzAccount
    connect-AzAccount -ServicePrincipal -Environment $env.Environment -Credential $Credential -tenant $tenant

    <#============================================
    Get VM object from Azure
    #============================================#>

    #set context
    Set-AzContext -Subscription $Subscription.Subscription

    if(((Get-AzContext -ErrorAction Stop).subscription.name ) -ne $Subscription)
        {
            $Validation += [pscustomobject]@{ValidationStep = 'Authentication'
                            FriendlyError = "Your context did not change to the Subscription $Subscription. Please validate the Subscription Name is valid"
                            PsError = $error[0]}
        }


    #get the VM object from Azure
    try{
        $VM = Get-AzVM -name $VmName  -ResourceGroupName $ResourceGroup -erroraction Stop
    }
    catch{
        $Validation += [pscustomobject]@{ValidationStep = 'Authentication'
        FriendlyError = "Could not validate that the Server $VmName exists in Azure.`r`nAzure Cloud : $environment`r`nSubscription : $Subscription `r`nAzure Cloud : $ResourceGroup"
        PsError = $error[0]}
    }

    <#============================================
    Validate Tags
    #============================================#>
    $tags = ''


    $tags = $VM.Tags | convertto-json 

    Try
    {
        $tags | test-json -schemafile .\ORR_Checks\Private\Tags_Definition.json -ErrorAction Stop
    }
    catch
    {

        $Validation += [pscustomobject]@{ValidationStep = 'Validation - Tags'
        FriendlyError = "Tags do not meet Validation"
        PsError = $error[0]}
    }

    return $Validation
}



