@{
RootModule = 'ORR_Checks.psm1'
ModuleVersion = '1.00'
Author = 'Claire Larvin'
CompanyName = 'Textron Inc.'
RequiredModules = @("az", @{ModuleName = "az"; ModuleVersion= "5.5.0"})
Description = "A module for Textron specific environment management"
PowerShellVersion = '7.1.2'
DotNetFrameworkVersion = '4.0'
CLRVersion = '4.0'
AliasesToExport = @()
FunctionsToExport = @('get-AzureCheck', 'Get-VMCheck')
}

