get-wmiobject -class Win32_Product | where {$_.Name -like "*Trellix Agent*"} | ConvertTo-Csv