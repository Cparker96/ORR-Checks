
Function Get-AzureCheck{
    Param(
        [parameter(Position = 0, Mandatory=$true)] [String] $VmName,
        [parameter(Position = 1, Mandatory=$true)] [ValidateSet('AzureUSGovernment', 'AzureUSGovernment_Old', 'AzureCloud')] [String] $Environment,
        [parameter(Position = 2, Mandatory=$true)] [String] $Subscription,
        [parameter(Position=3, Mandatory=$true)] [String] $ResourceGroup,
        [parameter(Position=4, Mandatory=$true)] $VmRF,
        [parameter(Position=5, Mandatory=$true)] $prodpass,
        [parameter(Position=6, Mandatory=$false)] $GovAccount
    )

    [System.Collections.ArrayList]$Validation = @()
    $VM = @()
    $ScriptPath = "$((get-module ORR_Checks).modulebase)\Private"

    <#============================================
    Login to Azure
    # Public Cloud - "AzureCloud" 
    # Azure Gov - "AzureUSGovernment_Old"
    # Azure Gov GCC High - "AzureUSGovernment" 
    #============================================#>

    # disconnect previous connections and log in with individual access
    Try{
        if((get-azcontext -erroraction stop).Environment.name -ne $Environment)
        {
            disconnect-AzAccount > $null

            if($Environment -eq 'AzureCloud'){
                $tenant = 'your_tenant_id'
                Write-Host "Logging into Azure Commercial"
                connect-AzAccount -Environment $Environment -tenant $tenant -ErrorAction Stop -WarningAction Ignore >$null
            }
            elseif($Environment -eq 'AzureUSGovernment_Old'){
                $tenant = 'your_tenant_id'
                Write-Host "Logging into Old Gov"
                connect-AzAccount -Environment 'AzureUSGovernment' -tenant $tenant -ErrorAction Stop -WarningAction Ignore >$null
            }
            elseif($Environment -eq 'AzureUSGovernment'){
                $tenant = 'your_tenant_id'
                Write-Host "Logging into GCC"
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

    # set context (will error silently if subscription isn't a valid field)
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
                        FriendlyError = "Your context did not change to the subscription $($Subscription). Please validate the Subscription Name is valid"
                        PsError = $PSItem.Exception}) > $null

        return ($Validation)
    }
    # return validation object
    $Validation.add([PSCustomObject]@{System = 'Azure'
    Step = 'AzureCheck'
    SubStep = 'Authentication'
    Status = 'Passed'
    FriendlyError = ''
    PsError = ''}) > $null 
 
    # get the VM object from Azure
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
                        FriendlyError = "Could not validate that the server $($VmName) exists in Azure.`r`nAzure Cloud : $($environment)`r`nSubscription : $($Subscription) `r`nAzure Cloud : $($ResourceGroup)"
                        PsError = $PSItem.Exception})  > $null

        # return the $validation object
        return ($Validation)
    }
    
    <#============================================
    Validate Tags
    #============================================#>
    
    $tags = @()
    $tags = $VM.Tags | convertto-json 

    # Check All required tags are there and they meet the Tagging syntax standards
    Try
    {
        #Validate that all tags exist and meet syntax standards
        $tags | test-json -schemafile "$ScriptPath\Tags_Definition_win.json" -ErrorAction stop > $null
        
        # if an error is not thrown then provide the 
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
    $elevatedUsers += "your_user_id"
    # if the contributor role isn't checked out then fail
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



