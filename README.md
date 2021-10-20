# Introduction 
An Automation of VM Operational Readiness Review found here:
    https://ontextron.sharepoint.com/:w:/r/sites/TISMidrange/_layouts/15/Doc.aspx?sourcedoc=%7BF83F80DE-EC6B-40D4-8994-309E7A6F6FC6%7D&file=Azure%20Server%20Delivery%20Packet.dotx&action=default&mobileredirect=true

## Access Requirements
Your Azure Contributor role Must be checked out over the scope of the VM you are running the ORR on

## Module Requirements
* Powershell - Version Min "7.1.2"
* Azure Module "AZ" - Version Min "5.5.0"
* Dbatools - Version Min "1.0.148"

## Data Sources
To determine Readiness there are multiple data sources to check 
1.	Service Now Server Request Ticket
2.  Azure Portal
3.	Tenable - https://cloud.tenable.com/ 
4.	Splunk - https://splk.textron.com:8089/
5.	McAfee - https://txasecapp001.txt.textron.com/
6.  Active Directory
7.  Cloud Operation's Database txadbsazu001.database.windows.net
8.  Cloud Operation's Azure Blob https://tisutility.blob.core.windows.net/orrchecks 

## Importing Modules
To import a local module follow the below steps: 
1. Download the ORR Check files from the Azure Blob and download the file with the most current datetime stamp.
2. Make sure you do not already have a copy of the ORR_Check module on your computer and remove the folder in that path until the below script returns nothing. 
    get-module ORR_Checks
3. Make sure the module was also cleaned up from your session
    get-module ORR_Checks | remove-module
4. Import the module into your session by changing into the directory that holds the ORR_Checks folder, README.md, ORR_Checks.ps1, and VM_Request_Fields.json then importing the module in the ORR_Checks folder
    import-module .\ORR_Checks\
5. Make sure the version is the expected version and that the import was successful
    get-module ORR_Checks

## Running the Script
1. Make sure you are in the correct directory ORR_Checks folder, README.md, ORR_Checks.ps1, and VM_Request_Fields.json
2. Update and save the values for VM_Request_Fields.json using valid JSON syntax. 
3. Run ORR_Checks.ps1 by . sourcing the file while in the correct working directory
    .\Orr_Checks.ps1
4. Upload the text file in your temp drive named SERVERNAME_yyyy-MM-dd.HH.mm.txt to the Snow ticket once all steps have correctly passed. 

## Server Build Process (*Assuming a normal server build*)
1. A new server request gets created through ServiceNow - Ticket is assigned to the Vendor technician
2. The Vendor creates the server in Azure according to ticket info
3. The Vendor RDP's into the newly created machine using a local account that they maintain
4. Scripts 0-7 are executed through the Vendor. Script repo is maintained by Cloud Ops team
    - Server name status is updated via SQL tables
5. The Vendor will then utilize the ORR_Checks module to go through the ORR process via Textron policy
    - Refer to the 'Importing Modules' section above for module importing/execution
6. Run the Orr Checks script as described above.
7. The text file will be attached to the ticket request that was originally submitted through ServiceNow as ORR Evidence. 

## Notes on ORR execution
* If you receive any sort of error in the text file or forgot to do something on the server, you will have to rerun all of the code in ORR_Checks.ps1.
* If you do not want to run the Tennable scan then you can set "RunTenableScan" : "No" in the VM_Request_Fields.Json. Any value other than "No" will result in the tenable scan running.
* You may run the ORR_Checks.ps1 as many times as you need but to pass ORR all fields must have Passed or Failed as expected 
  - Servers not AD joined will fail correctly on the ERPMCheck - ActiveDirectory OU Step. Please specify this is intentional in the ticket. 

## Need help?
If there are any questions please reach out to CloudOps@Textron.com via email with the textfile output, Server Name, Ticket Number, and Timestamp of the run you are having trouble with. 


