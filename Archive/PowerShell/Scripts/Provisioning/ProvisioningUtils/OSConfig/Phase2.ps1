# Define Paramters
Param(
	[string]$targetComputer,
	[string]$ServerType,
	[string]$PrivateIP,
	[string]$Domain,
	[string]$OU,
	[string]$ftpIP
)

#$script:VerbosePreference = "Continue"
#$script:DebugPreference = "Continue"

#--- Error Checking set to prompt for action ---*
#$script:ErrorActionPreference = "inquire"

#Load External Functions Files
. "C:\Scripts\Provisioning\OSConfig\Phase_Functions.ps1"  # Custom Functions for configuring the server

#-----------------#
#Steps
#-----------------#
Write-Host "`nRunning [ Phase2 ] Config" -Fore DarkGray

If ($servertype -eq "sql") {
ImportCarbon
DerivingSqlServiceAccount
SqlPrep
}
Else {}
AddServerOps
If ($wincollect -eq "yes") {
WinCollect
}
Else {}
