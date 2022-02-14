@{
RootModule = 'ORR_Checks.psm1'
ModuleVersion = '1.3'
Author = 'Claire Larvin'
CompanyName = 'Textron Inc.'
RequiredModules = @("az", @{ModuleName = "az"; ModuleVersion= "5.5.0"}; "dbatools", @{ModuleName = "dbatools"; ModuleVersion= "1.0.148"})
Description = "A module for Textron specific environment management"
PowerShellVersion = '7.1.2'
DotNetFrameworkVersion = '4.0'
CLRVersion = '4.0'
AliasesToExport = @()
FunctionsToExport = @('Get-AzureCheck', 'Get-VMCheck','Get-ERPMAdminsCheck','Get-ERPMOUCheck','Get-McAfeeCheck','Get-TenableCheck','Scan-Tenable', 'Get-SplunkSearch', 'Get-SplunkAuth', 'Get-SplunkResult')
}

