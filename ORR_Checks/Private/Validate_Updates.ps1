Install-PackageProvider -Name NuGet -MinimumVersion 2.8.5.201 -Force -Scope AllUsers
Install-Module PSWindowsUpdate -Force -Scope AllUsers

Get-WindowsUpdate -ErrorAction Stop | ConvertTo-Csv