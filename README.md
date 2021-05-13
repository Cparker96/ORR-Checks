# Introduction 
An Automation of VM Operational Readiness Review found here:
https://ontextron.sharepoint.com/:w:/r/sites/TISMidrange/_layouts/15/Doc.aspx?sourcedoc=%7BF83F80DE-EC6B-40D4-8994-309E7A6F6FC6%7D&file=Azure%20Server%20Delivery%20Packet.dotx&action=default&mobileredirect=true

# Module Requirements
 Powershell -  Version Min "7.1.2"
 Azure Module "AZ" - Version Min "5.5.0"

# Data Sources
To determine Readiness there are multiple data sources to check 
1.	Service Now Server Request Ticket
2.  Azure Portal
3.	Tenable - https://cloud.tenable.com/ 
4.	Splunk - https://splunk.textron.com:10443/
5.	McAfee - https://txasecapp001.txt.textron.com/
6.  Active Directory

# Importing Modules
To import a local module follow the below steps: 
1. Make sure you do not already have a copy of the ORR_Check module on your computer and remove the folder in that path until the below script returns nothing. 
    get-module ORR_Checks -listavailable
2. Make sure the module was also cleaned up from your session
    get-module ORR_Checks | remove-module
3. Understand the 'paths' that powershell looks for modules
    $env:PSModulePath.split
4. Place the ORR_Checks folder in one of those 'path' directories. This folder should contain 
    - 2 folders named 'Public' and 'Private' which hold the functions and supporting files for the script
    - A ORR_Checks.psm1 file which loads the contents of the 'Public' and 'Private' folder into the session
    - A ORR_Checks.psd1 file which is the module manifest and tells powershell which functions to make available as well as other module metadata. 
5. Import the module into your session
    import-module ORR_Checks
6. Make sure the version is the expected version and that the import was successful
    get-module ORR_Checks

