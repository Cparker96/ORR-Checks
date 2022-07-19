**THIS IS NOT THE OFFICIAL README OF THE REPO AS SOME OF THE CONTENT CONTAINS COMPANY SPECIFIC LINKS AND DETAILS**

This readme will be fully dedicated to the ORR Checks repository that serves as a custom powershell module to verify that an Azure virtual machine is ready for handoff once it has been vetted for any vulnerabilities, domain joined, and other checks to the server. 

All resource and other utilities such as variable names, keys, and links have been sanitized and have been replaced by the word "some" followed by a general description of what the resource entails (Ex: $key = "some_key").

Description: 

The ORR process, short for Operational Readiness Review, is a process that is utilized when someone submits a ticket request for a new virtual machine build inside the Azure Portal. A vendor will go out and build the VM to the requestor's needs in terms of size, number of cores, RAM, location, etc. Once complete, a member of the Cloud Operations team will execute the ORR process which includes validating that certain services are running (McAfee, Splunk, Tenable, etc.), validates that it is domain joined within Active Directory, and validates that no existing vulnerabilities exist on the server.

Once the server has cleared ORR, the server will be handed off to the requestor, allowing them to install any necessary applications and software. 

Usage:

1. Open an IDE of your choice with the parent ORR_Checks folder, fill out the VM_Request_Fields.json file with server metadata and save it
2. Load the custom powershell module into your session
  ```powershell
  import-module .\ORR_Checks\
  ```
   - The Private folder will house any files that include commands that need to be executed on the server via an RDP connection and return data back to the localhost.
   - The Public folder will include the powershell functions that utilize the data returned from the commands in the files of the Private folder and perform checks and    conditional logic for the ORR process.
   - The ORR_Checks.ps1 file will serve as the "control" script and utilize all functions in the Public folder, format the data properly, output to a SQL database, and    create a text file in the localhost's C:\Temp directory of the raw data.
3. Dot source and execute the ORR_Checks.ps1 file
```powershell
.\ORR_Checks.ps1
```

