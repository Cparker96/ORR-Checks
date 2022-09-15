Get-service | Where-Object {$_.DisplayName -in 
    ('Tenable Nessus Agent', 'Microsoft Monitoring Agent', 'Trellix Agent Service', 'SplunkForwarder Service')} -ErrorAction Stop | convertto-CSV

