# Introduction 
An Automation of VM Operational Readiness Review found here:
https://ontextron.sharepoint.com/:w:/r/sites/TISMidrange/_layouts/15/Doc.aspx?sourcedoc=%7BF83F80DE-EC6B-40D4-8994-309E7A6F6FC6%7D&file=Azure%20Server%20Delivery%20Packet.dotx&action=default&mobileredirect=true

# Access Requirements
Your Azure Contributor role Must be checked out over the scope of the VM you are running the ORR on

# Module Requirements
 Powershell - Version Min "7.1.2"
 Azure Module "AZ" - Version Min "5.5.0"
 Dbatools - Version Min "1.0.148"

# Data Sources
To determine Readiness there are multiple data sources to check 
1.	Service Now Server Request Ticket
2.  Azure Portal
3.	Tenable - https://cloud.tenable.com/ 
4.	Splunk - https://splk.textron.com:8089/
5.	McAfee - https://txasecapp001.txt.textron.com/
6.  Active Directory

# Importing Modules
To import a local module follow the below steps: 
1. Make sure you do not already have a copy of the ORR_Check module on your computer and remove the folder in that path until the below script returns nothing. 
    get-module ORR_Checks
2. Make sure the module was also cleaned up from your session
    get-module ORR_Checks | remove-module
5. Import the module into your session by changing into the directory that holds the ORR_Checks folder, README.md, ORR_Checks.ps1, and VM_Request_Fields.json then importing the module in the ORR_Checks folder
    import-module .\ORR_Checks\
6. Make sure the version is the expected version and that the import was successful
    get-module ORR_Checks

# Running the Script
1. Make sure you are in the correct directory ORR_Checks folder, README.md, ORR_Checks.ps1, and VM_Request_Fields.json
2. Update and save the values for VM_Request_Fields.json using valid JSON syntax. 
3. Run ORR_Checks.ps1 by . sourcing the file while in the correct working directory
    .\Orr_Checks.ps1
4. Upload the text file named SERVERNAME_yyyy-MM-dd.HH.mm.txt to the Snow ticket once all steps have correctly passed. If there are any questions please reach out to CloudOps@Textron.com via email with the textfile output, Server Name, Ticket Number, and Timestamp of the run you are having trouble with. 

# Server Build Process (*Assuming a normal server build*)
1. A new server request gets created through ServiceNow - Ticket is assigned to a tech at 10M
2. 10M creates the server in Azure according to ticket info
3. 10M RDP's into the newly created machine using a local account that they maintain
4. Scripts 0-7 are executed through 10M. Script repo is maintained by Cloud Ops team
    - Server name status is updated via SQL tables
5. 10M will then utilize the ORR_Checks module to go through the ORR process via Textron policy
    - Refer to the 'Importing Modules' section above for module importing/execution
6. Once the module is imported, update the VM_Request_Fields.json file with relevant VM info
    - This will be used to pull in metadata about the VM that was just created
7. To run the entire ORR process, Go into the ORR_Checks.ps1 file and execute the code starting at the 'URI' variable instantiation all the way down to approx. line 337 ($output += $rawdata)
    - This will log you into one or both azure portals so make sure to click your account in the GUI that pops up in the new browser tab to log in.
    - The entire file checks that tags validate our format, services are running on the VM, all updates are installed, domain joined to TXT with appropriate admin groups, added to WSUS GPO group, and all security controls are reporting in and operating accordingly. 
    - Within that file, we have commented blocks out for each step to make it easier to troubleshoot the location of the issue and more user-friendly to read
8. Assuming all services/controls/etc. are running and configured correctly, all outputs and raw data will be exported to a text file that lives in your Temp drive on your local machine
    - C:\Temp\"exported_text_file.txt" - refer to file name format towards the end of ORR_Checks.ps1
9. Eventually, this file will replace the ORR word document that Cloud Ops creates in order to hand the new server over to the server owner. This text file will be attached to the ticket request that was originally submitted through ServiceNow. 

# Notes on ORR execution
* If you receive any sort of error in the text file or forgot to do something on the server, you will have to rerun all of the code in ORR_Checks.ps1 
  - might be wise to delete the text file that was created for the inaccurate one not to be confused with the updated one that it will create
* If you do not want to run the Tennable scan then you can set "RunTenableScan" : "No" in the VM_Request_Fields.Json. Any value other than "No" will result in the tenable scan running.
* You may run the ORR_Checks.ps1 as many times as you need but to pass ORR all fields must have Passed or Failed as expected 
  - Servers not AD joined will fail correctly on the ERPMCheck - ActiveDirectory OU Step. Please specify this is intentional in the ticket. 



