Get-service | Where-Object {$_.DisplayName -in ('Tenable Nessus Agent', 'Microsoft Monitoring Agent', 'McAfee Agent Service', 'SplunkForwarder Service')} -ErrorAction Stop

