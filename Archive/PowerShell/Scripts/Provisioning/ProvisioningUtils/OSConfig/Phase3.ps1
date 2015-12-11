# Define Paramters
Param(
	[string]$targetComputer,
	[string]$ServerType,
	[string]$PrivateIP,
	[string]$Domain,
	[string]$OU,
	[string]$ftpIP,
	[string]$OSversion
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
Write-Host "`nRunning [ Phase3 ] Config" -Fore DarkGray
write-host "Server: $OSversion"
EnablePsRemoting
EnablePowershelloverHTTPS
DisablePowershellRemotingoverHTTP
If (($servertype -eq "ftp") -or ($servertype -eq "web")) {
FtpSetup
}
Else {}
If (($OSversion -eq "2008") -or ($OSversion -eq "2008R2")){
RenameAdminandGuest2008
}
ElseIf (($OSversion -eq "2012") -or ($OSversion -eq "2012R2")){
RenameAdminandGuest2012
}
Else {}
