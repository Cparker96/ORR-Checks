# Introduction 
An Automation of VM Operational Readiness Review found here:<br>

[Server Build ORR Checklist](https://ontextron.sharepoint.com/:w:/r/sites/TISMidrange/Shared%20Documents/Cloud%20Ops/Azure/Delivery%20Packets/Server%20Build%20ORR%20Checklist.docx?d=wa85f08a1d3aa416d83afb1dc087b8b59&csf=1&web=1&e=2CjJFB)

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
7.  Cloud Operation's Database - txadbsazu001.database.windows.net
8.  Cloud Operation's Azure Blob - https://tisutility.blob.core.windows.net/orrchecks 

## Importing Modules
To import a local module follow the below steps: 
1. Download the ORR Check files from the Azure Blob and download the file with the most current datetime stamp.
2. Make sure you do not already have a copy of the ORR_Check module on your computer and remove the folder in that path until the below script returns nothing.<br> 
```powershell
get-module ORR_Checks
```
3. Make sure the module was also cleaned up from your session<br>
```powershell
get-module ORR_Checks | remove-module
```
4. Import the module into your session by changing into the root directory that holds the ORR_Checks folder then importing the module in the ORR_Checks folder<br>
```powershell
import-module .\ORR_Checks\
```
5. Make sure the version is the expected version and that the import was successful.<br>
```powershell
get-module ORR_Checks
```

## Running the Script
1. Make sure you are in the root directory for the ORR_Checks folder
2. Update and save the values for VM_Request_Fields.json using valid JSON syntax. 
3. Run ORR_Checks.ps1 by . sourcing the file while in the correct working directory<br>
```powershell
.\Orr_Checks.ps1
```
4. Upload the text file in your temp drive named SERVERNAME_yyyy-MM-dd.HH.mm.txt to the Snow ticket once all steps have correctly passed. 

## Server Build Process (*Assuming a normal server build*)
1. A new server request gets created through ServiceNow. The ticket is assigned to the Vendor technician
2. The Vendor creates the server in Azure according to the specs provided in the ticket
3. The Vendor RDP's into the newly created machine using a local account that they maintain
4. Build scripts 0-7 are executed by the Vendor technician. Script repo is maintained by Cloud Ops team
    - Server name status is updated via SQL tables
5. The Vendor will then utilize the ORR_Checks module to go through the ORR process via Textron policy
    - Refer to the 'Importing Modules' section above for module importing/execution
6. Run the Orr Checks script as described above.
7. The text file will be attached to the ticket request that was originally submitted through ServiceNow as ORR Evidence. 

## Notes on ORR execution
* If you receive any sort of error in the text file or forgot to do something on the server, you will have to rerun all of the code in ORR_Checks.ps1.

* If you do not want to run the Tennable scan then you can set the following value in the VM_Request_Fields.Json.<br>
```json
"RunTenableScan" : "No" 
```
Any value other than "No" will result in the tenable scan running.

* You may run the ORR_Checks.ps1 as many times as you need but to pass ORR all fields must have Passed or Failed as expected 
  - Servers not AD joined will fail correctly on the ERPMCheck - ActiveDirectory OU Step. Please specify this is intentional in the ticket. 

* In VM_Request_Fields.Json the "Environment" parameter must be one of the following values : 
 - Public Cloud - "AzureCloud" 
 - Azure Gov - "AzureUSGovernment_Old"
 - Azure Gov GCC High - "AzureUSGovernment"

## Need help?
If there are any questions please reach out to CloudOps@Textron.com via email with the textfile output, Server Name, Ticket Number, and Timestamp of the run you are having trouble with. 
