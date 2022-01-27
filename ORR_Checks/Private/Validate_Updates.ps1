Install-PackageProvider -Name NuGet -MinimumVersion 2.8.5.201 -Force -Scope AllUsers > $null
Install-Module PSWindowsUpdate -Force -Scope AllUsers > $null

Get-WindowsUpdate -ErrorAction Stop 