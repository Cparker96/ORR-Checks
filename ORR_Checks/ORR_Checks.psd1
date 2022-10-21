@{
RootModule = 'ORR_Checks.psm1'
ModuleVersion = '1.4'
Author = 'Cody Parker'
CompanyName = 'Textron Inc.'
RequiredModules = @("az", @{ModuleName = "az"; ModuleVersion= "5.5.0"}; "dbatools", @{ModuleName = "dbatools"; ModuleVersion= "1.0.148"})
Description = "A module for Textron specific server provisioning"
PowerShellVersion = '7.1.2'
DotNetFrameworkVersion = '4.0'
CLRVersion = '4.0'
AliasesToExport = @()
FunctionsToExport = @('Get-AzureCheck', 'Get-VMCheck_win','Get-ERPMAdminsCheck_win','Get-ERPMOUCheck_win','Get-McAfeeCheck_win','Get-TenableCheck','Scan-Tenable', 'Get-SplunkSearch', 'Get-SplunkAuth', 'Get-SplunkResult', 'Get-MMACheck_lnx', 'Get-RealmJoin_lnx', 'Get-SplunkStatus_lnx', 'Get-TenableStatus_lnx', 'Get-Updates_lnx', 'Get-HostNameSQL')
}

