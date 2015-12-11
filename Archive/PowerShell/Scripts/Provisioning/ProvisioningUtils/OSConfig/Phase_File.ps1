# Define Paramters
Param(
	[string]$targetComputer,
	[string]$ServerType,
	[string]$PrivateIP,
	[string]$Domain,
	[string]$OU,
	[string]$ftpIP,
	[string]$inusad,
	[string]$phasestep,
	[string]$OSversion
)

#$script:VerbosePreference = "Continue"
#$script:DebugPreference = "Continue"

#--- Error Checking set to prompt for action ---*
#$script:ErrorActionPreference = "inquire"

#Load External Functions Files
. "C:\Scripts\Provisioning\OSConfig\Phase_Functions.ps1"  # Custom Functions for configuring the server

If ($phasestep -eq "1") {
Write-Host "`nRunning [ Phase1 ] Config" -Fore DarkGray
#DisplayVariables
Load-ConfigurationFromRegistry
DetectOS
Set-TimeZone "Central Standard Time"
Disable-Firewall
Change-CDromDriveLetter
Enable-RemoteDesktop
Configure-EventLogSettings
Disable-UAC
Disable-ServerManagerSplashScreen
Configure-IconsAndNotifications
Configure-SNMPRegistrySettings
Configure-DisableIPV6RegistrySettings
Configure-DriverSigningPolicyRegistrySettings
Configure-ProtocolRegistrySettings
Configure-NullSessionShareRegistrySettings
Create-LogFolderOnDriveD 
#Configure-DisksWithNoPartitions
#LetterAndLabelDrives
PlaceUtilsFolder
RolesandFeatures
If (($OSversion -eq "2008") -or ($OSversion -eq "2008R2")){
DotNET45Install
WindowsManagementFramework4Install
}Else {}
Configure-WindowsUpdateSettings
If (($servertype -eq "base") -or ($servertype -eq "sql")){
#DriveRights
PageFile
}
ElseIf ($servertype -eq "web") {
#DriveRights
PageFile
IIS6_PS_config
netsvc_PS_config
SmartHost_PS_config
}Else {}
If (($OSversion -eq "2008") -or ($OSversion -eq "2008R2")){
NIC2008
}
ElseIf (($OSversion -eq "2012") -or ($OSversion -eq "2012R2")){
NIC2012
}Else {}
Routes
If ($inusad -eq "false"){
JoinDomain
}
Else {}
RebootTargetComputer
}
Else {
#Write-Host "Phase 1 Skipped" -fore darkgray
}


If ($phasestep -eq "2"){
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
}
Else {
#Write-Host "Phase 2 Skipped" -fore darkgray
}


if ($phasestep -eq "3"){
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
}
Else {
#Write-Host "Phase 3 Skipped"
}
