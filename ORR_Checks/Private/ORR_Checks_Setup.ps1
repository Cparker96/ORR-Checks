if($PSVersionTable.PSVersion.tostring() -lt "7.1.0")
{
    Write-Error "please update to Powershell 7"
}

if((get-module PackageManagement).version.tostring() -lt '1.4.0')
{
    try{
        install-Module PackageManagement -force
    }
    catch{
        Write-Error "You need to update PackageManagement to minimum version '1.4.0'"
    }
}

if((get-module PowerShellGet).version.tostring() -lt '2.2.0')
{
    try{
        install-Module PowerShellGet -Force
    }
    catch{
        Write-Error "You need to update PackageManagement to minimum version '1.4.0'"
    }
}



Install-PackageProvider -Name NuGet -Force

Get-Module PowerShellGet

#make sure tls 1.2 is set
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12


