# Define Paramters
Param(
	[string]$targetComputer,
	[string]$ServerType,
	[string]$PrivateIP,
	[string]$Domain,
	[string]$OU,
	[string]$ftpIP,
	[string]$inusad
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
Write-Host "`nRunning [ Phase1 ] Config" -Fore DarkGray


Write-Host "Variable Carry-Over" -Fore White
Write-Host "ServerName: $targetComputer"
Write-Host "ServerType: $ServerType"
Write-Host "PrivateIP: $PrivateIP"
Write-Host "Domain: $Domain"
Write-Host "OU: $OU"
Write-Host "ftpIP: $ftpIP"
write-host "inusad: $inusad"


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