
Param(
	[Parameter(Mandatory=$False)]
	[string]$targetComputer,
	[Parameter(Mandatory=$False)]
	[string]$PrivateIP,
	[Parameter(Mandatory=$False)]
	[string]$ftpIP,
	[Parameter(Mandatory=$False)]
	[string]$servertype,
	[Parameter(Mandatory=$False)]
	[string]$Domain,
	[Parameter(Mandatory=$False)]
	[string]$OU,
	[Parameter(Mandatory=$False)]
	[string]$emailalert,
	[Parameter(Mandatory=$False)]
	[string]$wincollect,
	[Parameter(Mandatory=$False)]
	[string]$DisplayResults,
	[Parameter(Mandatory=$False)]
	[string]$Updates
)

# Example with parameters
#  .\Server_Provisioning-TEST.ps1 -TargetComputer "ns2008-new" -PrivateIP "156.45.55.60" -ftpIP "10.10.10.10" -servertype "APP" -Domain "us" -OU "APP" -emailalert "n" -Wincollect "n" -DisplayResults "n" -Updates "n"

$script:VerbosePreference = "Continue"
$script:DebugPreference = "Continue"

#--- Error Checking set to prompt for action ---*
$script:ErrorActionPreference = "inquire"

#--- variable to gather local IP of server script is being run on ---*
$script:localip = (gwmi Win32_NetworkAdapterConfiguration | ? { $_.IPAddress -ne $null }).ipaddress

#--- variable to gather logged in user ---*
$script:loggedinuser = [Environment]::UserName

#--- variable to set FTP to null ---*
$script:ftpIP = "NA"

# Provisioning Folder Location
$ProvisioningFolder = $scriptPath = split-path -parent $MyInvocation.MyCommand.Definition

#Load External Functions Files
. $ProvisioningFolder\Provisioning\ProvisioningUtils\Server_Provisioning_Functions.ps1  # Custom Functions for configuring the server


# <------------------------------------------------ Script Start ------------------------------------------------>

WelcomeMessage

###################################
#     Data Collection START       #
###################################

MenuHeader
If (!$targetComputer){
ServerName 	# Collect Server Name
} Else {}
LogSetup 	# Setup Log file and log servername and user running script
ClearDns	# Function to query dns of $targetComputer
PingTest    # Function to ensure that IP address is pingable
If (!$PrivateIP){
EnterIP		# Input production IP to determine what dns/routes to give the server
} Else {}
#CheckIPisValid	#--- Function to ensure that IP address is in a valid format ---*
If (!$wincollect){
Wincollectyn	#--- WinCollect installation question
} Else {}
If (!$emailalert) {
EmailAlert	# Email option for alert
} Else {}
MenuHeader
If (!$servertype) {
SelectRole	# Choose (Base/App) / DC / FTP / Print / SQL / (Web/Wap) / EXIT
} Else {}
MenuHeader
If (!$Domain) {
SelectDomain	# Choose US / MPNE / MNETI / MNETE / MPN / MPNI / LAB / EXIT
} Else {}
#CheckUSDomain
MenuHeader
If (!$OU) {
SelectOU	# Web / Wap / Sl / App / ADFS / Cloud / FTP / Terminal / EXIT
} Else {}
MenuHeader
If (($DisplayResults -eq "n") -or ($DisplayResults -eq "N")) {
} Else {
DisplayResults
}
$script:start = Get-Date	# Start Script Timer
MenuHeader

###################################
#     Data Collection STOP        #
###################################



###################################################
#     V3 Method - Functional~ized Parts START      #
###################################################

MidServerSetup
CopyProvisioningFolder
CopyUtilFolder
TuneDrives
BaseScripts
InitializingRolesandFeatures
If (($servertype -eq "base") -or ($servertype -eq "sql")){
SettingPageFileDrivePermissionsbasesql
}
ElseIf ($servertype -eq "web") {
SettingPageFileDrivePermissionsweb
} Else {}
ConfiguringNic
JoiningDomain
If (($domain -eq "US") -and ($OU -eq "APP")){
#ConfirmUSDomainAppOU - Stopped working 6-17-2015
} Else {}
RebootComputerOld
If ($servertype -eq "sql") {
InstallBaseSQLconfig
} Else {}
AddingServerOpsSecurity
If (($updates -eq "n") -or ($updates -eq "N")) {
} Else {
#UpdatingWindows
#RebootComputerNew
#UpdatingWindows
#RebootComputerNew
}
If ($wincollect -eq "yes") {
WincollectInstallation
} Else {}
CertificationRequestandImport
EnablingPowershelloverHTTPS
DisablingPowershellRemotingoverHTTP
If (($servertype -eq "ftp") -or ($servertype -eq "web")) {
PerformingFTPprocedures
} Else {}
If ($servertype -eq "sql") {
SqlCertPermission
} Else {}
RenamingAdminandGuestAccounts
RebootComputerNew
CompletionMessage
If ($emailalert -eq "yes") {
SendCompletionEmail
} Else {}
StopTimer	# Stop Script Timer and display results

###################################################
#     V3 Method - Functionalized Parts STOP       #
###################################################


# <------------------------------------------------ Script Stop ------------------------------------------------>


################################################### \
#     V4 Method - Functionalized Parts START      #  > This portion is inactive
################################################### /
<#
CopyFiles	# Copy all necessary setup files to the server
Phase1		# Execute Phase 1
Do {Start-Sleep -s 30}
Until (test-connection $targetComputer -quiet)
Phase2
RebootRemoteServer
#WinUpdates
#RebootRemoteServer
#WinUpdates
#RebootRemoteServer
CertReq
Phase3
RebootRemoteServer
CompleteMessage
StopTimer	# Stop Script Timer and display results
#>
################################################### \
#     V4 Method - Functionalized Parts STOP       #  > This portion is inactive
################################################### /