<#
    .SYNOPSIS
        The main file to run the Server Operational Readdiness Review (ORR) process
    .DESCRIPTION
        the Ps1 that actually runs the ORR workflow and outputs the validation steps
	.PARAMETER Hostname
		The Server name of the Server being ORR'd
    .PARAMETER Environment
		Specifies the Cloud platform and tennant to connect to
			Public Cloud - "AzureCloud" 
			Azure Gov - "AzureUSGovernment_Old"
			Azure Gov GCC High - "AzureUSGovernment" 
    .PARAMETER Subscription
		The friendly name of the subscription where the VM was built
    .PARAMETER Resource Group
		The Resource group name where the VM was built
    .PARAMETER Operating System
		Can be left null but a simple Windows or Linux is prefered
    .PARAMETER Requestor
		The name of the VM requestor
    .PARAMETER Created By
		The name of the IT professional who did the build
    .PARAMETER Ticket Number
		The Snow ticket that stared the build process and where the requirements and approvals are sourced 
    .PARAMETER RunTenableScan
		A quick way to not run the tennable scan (aprox 1 hour) for testing purposes. 
		Approved Values
			"Yes"
			"No"

    .EXAMPLE
		{
			"Hostname" : "TXAINFAZU021",
			"Environment" : "AzureCloud",
			"Subscription" : "Enterprise",
			"Resource Group" : "308-Utility",
			"Operating System" : "",
			"Requestor" : "Christopher Reilly",
			"Created By" : "Ricky Barbour",
			"Ticket Number" : "SCTASK0014780", 
			"RunTenableScan" : "Yes"
		}       

    .NOTES
        Created by      : Cody Parker and Claire Larvin
        Date Coded      : 04/16/2021
        Modified by     : Claire Larvin
        Date Modified   : 1/26/2022
        #>
