########################################################################################
#
#    MARITZ - AUTOMATED POST SCRIPTS - POWERSHELL SCRIPT												
#    NAME: Automated_Post_Scripts.ps1																	
# 
#    AUTHOR:  MGTS
#    DATE:  11/5/2014
# 
#    COMMENT:  This script will configure the server to Maritz Build specifications
#
#    VERSION HISTORY
#    1.000 - initial creation
#    1.001 - Added creation of Log folder on the D drive to basic.ps1
#    1.002 - Consolidated NIC scripts to one nic config script, NicConfig.ps1
#          - Also added the ability to detect 1 or 2 nics and name them Private and Public respectively
#    1.003 - Consolidated NIC scripts to one nic config script, NicConfig.ps1 
#    1.004 - Moved nic config portion to after the Join Domain portion.  Changing DNS before domain join can break that function.
#    1.005 - Added Drive tuning.  This will ensure all disks are initialized, online, lettered, and expanded to the fullest capacity that vmware is presenting.
#    1.006 - Added logic to LocalAccount_PS_config.ps1 to assign H0 password for 2012 and Bl@ck password for 2008.  
#
#	 STEPS
#--- 1. Start of Post Deployment Script
#--- 2. Menu to select server role
#--- 3. Menu to select domain
#--- 4. Menu to select AD OU
#--- 5. Post Scripts Functions
#
#	 Post Script Parts
#--- Copying provisioning and util folder to the remote server
#--- Rerunning base scripts since Vmware Customization Specs wipe out some basic settings
#--- Placing the Util folder on the D drive
#--- Setting PageFile & Basic Drive Permissions if "base" or "sql"
#--- Setting PageFile & Basic Drive Permissions if "web"
#--- Joining Domain
#--- Reboot Computer
#--- Renaming Nic to Private
#--- Initializing Roles and Features
#--- Installing .NET 3.5 if "sql"
#--- Adding Server Ops Security
#--- Certification Request and Import
#--- Enabling Powershell over HTTPS
#--- Disabling Powershell Remoting over HTTP
#--- Renaming Admin and Guest Accounts
#--- Performing FTP procedures if "ftp"
#--- Completion Message
#
#    The Completion Message is the end of the script. (Line 786)
#
########################################################################################

#-------------- FUNCTIONS -----------------#
#
#   LogWrite - Writes to C:\Scripts\Logs\installlogs on the mid server
#   LogSetup - Creates Log at C:\script\Logs\installlogs
#   Flushdns - "ipconfig /flushdns" command in function form
#   Get-DNS - Pulls dns record of server from primary dns server
#   Write-Centered-Red - write function that is centered/red
#   Write-Centered-Yellow - write function that is centered/yellow
#   Write-Centered-Cyan - write function that is centered/cyan
#   CheckIPisActive - Will ping requested server and give positive or negative results
#   CheckIPisValid - Will examine the input and ensure its in a "#.#.#.#" format
#   CheckDdrive - Will see if a D drive exists
#   CheckEdrive - Will see if a E drive exists
#   CheckFdrive - Will see if a F drive exists
#   CheckGdrive - Will see if a G drive exists
#   CheckHdrive - Will see if a H drive exists
#   Get-Size - Will query size of a partition 
#   Exit - Will end script
#
#-------------------------------------------#

Function LogWrite {
   Param ([string]$logstring)
   $date = get-date -format g
   Add-content -path c:\Scripts\Logs\installlogs\"$targetComputer"_install.log -value $date":"$logstring
}
Function LogSetup {
$scriptversion = "2.000"
$currentScriptName = $MyInvocation.MyCommand.Name
$logfile = "c:\Scripts\Logs\installlogs\"+$targetComputer+"_install.log"
#if(!(test-path -path c:\Scripts\Logs\installlogs\"+$targetComputer+"_install.log))
#{new-item c:\Scripts\Logs\installlogs -itemType directory}
LogWrite " Script Log Created"
}
Function Flushdns {
ipconfig /flushdns
}
Function Get-DNS{
$dnschk = $NULL
$dnsexist =$NULL
$ErrorActionPreference= "silentlycontinue"
$dnschk = [System.Net.DNS]::GetHostAddresses("$targetComputer")
$dnsip = $dnschk.IPAddressToString 
if ($dnsip -match "(\d{1,3}).(\d{1,3}).(\d{1,3}).(\d{1,3})") {
Write-host " ...$dnsip" -Fore Green;start-Sleep -Seconds 2
} else {
write-host " ...No DNS entry found." -Fore Red;start-Sleep -Seconds 2
}
}
Function Write-Centered-Red {
    Param(  [string] $message,
            [string] $color = "red")
    $offsetvalue = [Math]::Round(([Console]::WindowWidth / 2) + ($message.Length / 2))
    Write-Host ("{0,$offsetvalue}" -f $message) -ForegroundColor $color
}
Function Write-Centered-Yellow {
    Param(  [string] $message,
            [string] $color = "yellow")
    $offsetvalue = [Math]::Round(([Console]::WindowWidth / 2) + ($message.Length / 2))
    Write-Host ("{0,$offsetvalue}" -f $message) -ForegroundColor $color
}
Function Write-Centered-Cyan {
    Param(  [string] $message,
            [string] $color = "cyan")
    $offsetvalue = [Math]::Round(([Console]::WindowWidth / 2) + ($message.Length / 2))
    Write-Host ("{0,$offsetvalue}" -f $message) -ForegroundColor $color
}
Function CheckIPisActive {
$testconnection = Test-Connection -computer $targetComputer -quiet
if ($testconnection -eq "true"){
Write-host " ...Server is online"-Fore Green;start-Sleep -Seconds 2
Write-host ""
} Else {
Write-host " ...Server is not responding to ping."-Fore Red;start-Sleep -Seconds 5
Write-host "`n`t`tServer being deployed needs to be on the network and accessible to continue."-Fore Red;start-Sleep -Seconds 7
Write-host ""
Read-Host "`t`tPress enter to restart..." | Out-Null
.\Automated_Post_Scripts.ps1
}
}
Function CheckIPisValid {
if($PrivateIP -match "(\d{1,3}).(\d{1,3}).(\d{1,3}).(\d{1,3})") { 
Write-host " ...Format is valid" -Fore Green;start-Sleep -Seconds 3
LogWrite " IP address format was valid"
 } Else {
Write-host "`n`t`tThe IP address you used is in an improper format.  Please try again." -Fore Red;start-Sleep -Seconds 3
LogWrite " IP address format was not valid.  Reloading Menu"
Write-host ""
Read-Host "`t`tPress enter to restart..." | Out-Null
.\Automated_Post_Scripts.ps1
 }
 }
Function CheckDdrive{
 
 $dcheck = (Test-Path "\\$targetComputer\d$")
 if($dcheck -eq "True"){
 Write-host "`t`t...D drive found." -Fore Yellow;start-Sleep -Seconds 3
 LogWrite " D drive checked and located"
 }
 else {
  Write-host "`t`tD Drive not detected.  D drive is necessary to continue." -Fore Red;start-Sleep -Seconds 3
  LogWrite " D drive not detected.  Reloading menu"
Read-Host "`t`tPress Enter To Acknowledge..." | Out-Null
 }
 }
Function CheckEdrive{
 
write-host "`n`t`tChecking for E drive on $targetComputer....." -Fore Cyan;start-Sleep -Seconds 2 
  $dcheck = (Test-Path "\\$targetComputer\e$")
 if($dcheck -eq "True"){
  Write-host "`t`t...E drive found." -Fore Yellow;start-Sleep -Seconds 3
  LogWrite " E drive checked and located"
 }
 else {
  Write-host "`t`tE Drive not detected.  Make sure you setup an E drive before handing off the server." -Fore Red;start-Sleep -Seconds 3
  LogWrite " E drive not detected.  Reloading menu"
 }
 }
Function CheckFdrive{
  write-host ""
write-host "`t`tChecking for F drive on $targetComputer....." -Fore Cyan;start-Sleep -Seconds 2 
 $dcheck = (Test-Path "\\$targetComputer\f$")
 if($dcheck -eq "True"){
 Write-host "`t`t...F drive found." -Fore Yellow;start-Sleep -Seconds 3
  LogWrite " F drive checked and located"
 }
 else {
  Write-host "`t`tE Drive not detected.  Make sure you setup an F drive before handing off the server." -Fore Red;start-Sleep -Seconds 3
    LogWrite " F drive not detected.  Reloading menu"
 }
 }
Function CheckGdrive{
  write-host ""
write-host "`t`tChecking for G drive on $targetComputer....." -Fore Cyan;start-Sleep -Seconds 2 
 $dcheck = (Test-Path "\\$targetComputer\g$")
 if($dcheck -eq "True"){
 Write-host "`t`t...G drive found." -Fore Yellow;start-Sleep -Seconds 3
  LogWrite " G drive checked and located"
 }
 else {
  Write-host "`t`tE Drive not detected.  Make sure you setup an G drive before handing off the server." -Fore Red;start-Sleep -Seconds 3
  LogWrite " G drive not detected.  Reloading menu"
 }
 }
Function CheckHdrive{
  write-host ""
write-host "`t`tChecking for H drive on $targetComputer....." -Fore Cyan;start-Sleep -Seconds 2 
 $dcheck = (Test-Path "\\$targetComputer\h$")
 if($dcheck -eq "True"){
 Write-host "`t`t...H drive found." -Fore Yellow;start-Sleep -Seconds 3
  LogWrite " H drive checked and located"
 }
 else {
  Write-host "`t`tE Drive not detected.  Make sure you setup an H drive before handing off the server." -Fore Red;start-Sleep -Seconds 3
  LogWrite " H drive not detected.  Reloading menu"
 }
 }
Function Get-Size{
 param([string]$pth)
 "{0:n2}" -f ((gci -path $pth -recurse | measure-object -property length -sum).sum /1mb) + " mb"
}
Function Exit {
Exit-PSSession
} 

#--- 2. Menu to select server role ---*

Function MenuRole{
Do{
CLS
#… Present the Menu Options
write-host ""
write-host ""
Write-Centered-Red "*-----------------------------------------------------------------------------------*"
Write-Centered-Red "Maritz Automated Post Script Process – Version 2.0"
Write-Centered-Red "*-----------------------------------------------------------------------------------*"
write-host ""
Write-Centered-Yellow “Please select the type of server you are deploying” 
write-host ""
Write-Centered-Yellow “1. Base/APP Server    ” 
Write-Centered-Yellow “2. Domain Controller  ” 
Write-Centered-Yellow “3. FTP Server         ” 
Write-Centered-Yellow “4. Print              ” 
Write-Centered-Yellow “5. SQL Server         ” 
Write-Centered-Yellow “6. Web/Wap            ”
Write-Centered-Yellow “7. Exit Script        ”  
write-host ""
write-host ""
$menunum = Read-Host "`t`tSelect one of the above options"
} until (($menunum -eq "1") -or ($menunum -eq "2") -or ($menunum -eq "3") -or ($menunum -eq "4") -or ($menunum -eq "5") -or ($menunum -eq "6") -or ($menunum -eq "7"))
switch ($menunum){
"1" {
$servertype = "base"
  LogWrite " Server role set to [ $servertype ]"
MenuDomain
}
"2" {
$servertype = "dc"
  LogWrite " Server role set to [ $servertype ]"
MenuDomain
}
"3" {
$servertype = "ftp"
  LogWrite " Server role set to [ $servertype ]"
CLS
write-host ""
write-host ""
write-host ""
Write-Centered-Red "*-----------------------------------------------------------------------------------*"
Write-Centered-Red "Maritz Automated Post Script Process – Version 2.0"
Write-Centered-Red "*-----------------------------------------------------------------------------------*"
write-host ""
write-host ""
Write-Centered-Yellow “Please provide FTP IP for the machine being deployed.” 
write-host ""
write-host ""
$ftpIP = Read-Host "`t`tEnter FTP IP address" 
  LogWrite " FTP IP set to [ $ftpIP ]"
write-host ""
write-host "`t`tRunning check to ensure the IP address is in a valid format....."-Fore Cyan;start-Sleep -Seconds 2 
CheckIPisValid
MenuDomain
}
"4" {
$servertype = "print"
  LogWrite " Server role set to [ $servertype ]"
MenuDomain
}
"5" {
$servertype = "sql"
  LogWrite " Server role set to [ $servertype ]"
MenuDomain
}
"6" {
$servertype = "web"
  LogWrite " Server role set to [ $servertype ]"
MenuDomain
}
"7" {
 LogWrite "Exiting Script"
Exit}
}
}

#--- 3. Menu to select domain ---*

Function MenuDomain {
do{
CLS
write-host ""
write-host ""
Write-Centered-Red "*-----------------------------------------------------------------------------------*"
Write-Centered-Red "Maritz Automated Post Script Process – Version 2.0"
Write-Centered-Red "*-----------------------------------------------------------------------------------*"
write-host ""
Write-Centered-Yellow “Please select the Domain you are going to deploy to” 
write-host ""
Write-Centered-Yellow “1. US                 ” 
Write-Centered-Yellow “2. MPNE               ” 
Write-Centered-Yellow “3. MNETI              ” 
Write-Centered-Yellow “4. MNETE              ” 
Write-Centered-Yellow “5. MPN                ” 
Write-Centered-Yellow “6. MPNI               ”
Write-Centered-Yellow “7. Exit Script        ”  
write-host ""
$menunum = Read-Host "`t`tSelect one of the above options"
} until (($menunum -eq "1") -or ($menunum -eq "2") -or ($menunum -eq "3") -or ($menunum -eq "4") -or ($menunum -eq "5") -or ($menunum -eq "6") -or ($menunum -eq "7"))
switch ($menunum){
"1" {
$Domain = "us"
LogWrite " Domain set to [ $Domain ]"
if ($localip -eq "156.45.55.249")
{

Write-Host "`n`t`tConfirming server not in the US domain already" -Fore Yellow -NoNewline;start-Sleep -Seconds 1 
$ErrorActionPreference = 'SilentlyContinue'
if (-not $( Get-ADComputer -Identity $targetComputer -Server us.maritz.net)){ 
Write-Host " ...Confirmed" -Fore Green;start-Sleep -Seconds 5
$inad = "false"
MenuOU
}
Else { Write-Host " ...Server is already in the US domain" -Fore Cyan;start-Sleep -Seconds 5
Write-Host "`n`t`tThe < Join Domain > portion of the script will be skipped" -Fore Cyan;start-Sleep -Seconds 5 
$inad = "true"
PostScripts
}
$ErrorActionPreference = 'Continue'
}
Else
{
 write-host ""
 LogWrite " Domain does not equal the mid-server you are deploying from"
 Write-Centered-Red “`tTo join this domain you need to be on Fenappmgp07.  Please move to that server and try again.” -Fore Red;start-Sleep -Seconds 4
 MenuDomain
}
}
"2" {
$Domain = "mpne"
  LogWrite " Domain set to [ $Domain ]"
if ($localip -eq "159.45.69.249")
{
 MenuOU
}
Else
{
 write-host ""
 LogWrite " Domain does not equal the mid-server you are deploying from"
 Write-Centered-Red “`tTo join this domain you need to be on Fenappmgp04.  Please move to that server and try again.” -Fore Red;start-Sleep -Seconds 4
 MenuDomain
}
}
"3" {
$Domain = "mneti"
  LogWrite " Domain set to [ $Domain ]"
if ($localip -eq "172.19.13.249")
{
 MenuOU
}
Else
{
 write-host ""
 LogWrite " Domain does not equal the mid-server you are deploying from"
 Write-Centered-Red “`tTo join this domain you need to be on Fenappmgp05.  Please move to that server and try again.” -Fore Red;start-Sleep -Seconds 4
 MenuDomain
}
}
"4" {
$Domain = "mnete"
  LogWrite " Domain set to [ $Domain ]"
if ($localip -eq "156.45.59.119")
{
 MenuOU
}
Else
{
 write-host ""
 LogWrite " Domain does not equal the mid-server you are deploying from"
 Write-Centered-Red “`tTo join this domain you need to be on Fenappmgp06.  Please move to that server and try again.” -Fore Red;start-Sleep -Seconds 4
 MenuDomain
}
}
"5" {
$Domain = "mpn"
  LogWrite " Domain set to [ $Domain ]"
if ($localip -eq "10.99.13.249")
{
 MenuOU
}
Else
{
 write-host ""
 LogWrite " Domain does not equal the mid-server you are deploying from"
 Write-Centered-Red “`tTo join this domain you need to be on Fenappmgp08.  Please move to that server and try again.” -Fore Red;start-Sleep -Seconds 4
 MenuDomain
}
}
"6" {
$Domain = "mpni"
  LogWrite " Domain set to [ $Domain ]"
if ($localip -eq "192.168.239.249")
{
 MenuOU
}
Else
{
 write-host ""
 LogWrite " Domain does not equal the mid-server you are deploying from"
 Write-Centered-Red “`tTo join this domain you need to be on Fenappmgp09.  Please move to that server and try again.” -Fore Red;start-Sleep -Seconds 4
 MenuDomain
}
}
"7" {
 Logwrite " Exiting Script" 
Exit}
}
}

#--- 4. Menu to select AD OU ---*

Function MenuOU {
[INT]$xMenu1=0
while ( $xMenu1 -lt 1 -or $xMenu1 -gt 9 ){
CLS
write-host ""
write-host ""
Write-Centered-Red "*-----------------------------------------------------------------------------------*"
Write-Centered-Red "Maritz Automated Post Script Process – Version 2.0"
Write-Centered-Red "*-----------------------------------------------------------------------------------*"
write-host ""
Write-Centered-Yellow “Please select the Active Directory OU you are going to deploy to” 
write-host ""
Write-Centered-Yellow “1. WEB                ” 
Write-Centered-Yellow “2. WAP                ” 
Write-Centered-Yellow “3. SQL                ” 
Write-Centered-Yellow “4. APP                ” 
Write-Centered-Yellow “5. ADFS               ” 
Write-Centered-Yellow “6. CLOUD              ” 
Write-Centered-Yellow “7. FTP                ” 
Write-Centered-Yellow “8. TERMINAL           ”
Write-Centered-Yellow “9. Exit Script        ”  
write-host ""
[int]$xMenu1 = Read-Host “`t`tEnter Menu Option Number”
if( $xMenu1 -lt 1 -or $xMenu1 -gt 9 ){
Write-Host “`t`tPlease select one of the options available.” -Fore Red;start-Sleep -Seconds 3
}
}
Switch ($xMenu1){    #… User has selected a valid entry.. load next menu
1 {
$OU = "WEB"
LogWrite " OU set to [ $OU ]"
PostScripts
}
2 {
$OU = "WAP"
LogWrite " OU set to [ $OU ]"
PostScripts
}
3 {
$OU = "SQL"
LogWrite " OU set to [ $OU ]"
PostScripts
}
4 {
$OU = "APP"
LogWrite " OU set to [ $OU ]"
PostScripts
}
5 {
$OU = "ADFS"
LogWrite " OU set to [ $OU ]"
PostScripts
}
6 {
$OU = "CLOUD"
LogWrite " OU set to [ $OU ]"
PostScripts
}
7 {
$OU = "FTP"
LogWrite " OU set to [ $OU ]"
PostScripts
}
8 {
$OU = "TERMINAL"
LogWrite " OU set to [ $OU ]"
PostScripts
}
9 {
LogWrite " Exiting Script"
Exit}
}
}
Function DisplayResults {
CLS
write-host ""
write-host ""
write-host ""
Write-Centered-Red "*-----------------------------------------------------------------------------------*"
Write-Centered-Red "Maritz Automated Post Script Process – Version 2.0"
Write-Centered-Red "*-----------------------------------------------------------------------------------*"
write-host ""
write-host ""
Write-host "`t`t`t                     Verify your input choices                 "
Write-host "`t`t`t+-------------------------------------------------------------+"
Write-host "`t`t`t|"
Write-host "`t`t`t|  Displaying Input Results...";start-Sleep -Seconds 1
Write-host "`t`t`t|  Server Name: " -nonewline; Write-host "$targetComputer" -Fore Yellow;start-Sleep -Seconds 2
Write-host "`t`t`t|  Server Type: " -nonewline; Write-host "$servertype" -Fore Yellow;start-Sleep -Seconds 2
Write-host "`t`t`t|  Local IP: " -nonewline; Write-host "$PrivateIP" -Fore Yellow;start-Sleep -Seconds 2
Write-host "`t`t`t|  OU: " -nonewline; Write-Host "$OU" -Fore Yellow;start-Sleep -Seconds 2
Write-host "`t`t`t|  Domain: " -nonewline; Write-host "$Domain" -Fore Yellow;start-Sleep -Seconds 2
Write-host "`t`t`t|  FTP IP: " -nonewline; Write-host "$ftpIP" -Fore Yellow;start-Sleep -Seconds 2
Write-host "`t`t`t|"
Write-host "`t`t`t+-------------------------------------------------------------+"
Write-host "`t`t`t         If any of this is wrong, Hit Cntrl+C now              " -Fore Red;start-Sleep -Seconds 2
Write-host "`t`t`t                   You have 10 seconds.....                    " -Fore Red;start-Sleep -Seconds 10
}

#--- 5. Post Scripts Functions ---*

Function PostScripts{

DisplayResults

Clear-Host
write-host "`n`n"
Write-Centered-Red "*-----------------------------------------------------------------------------------*"
Write-Centered-Red "Maritz Automated Post Script Process – Version 2.0"
Write-Centered-Red "*-----------------------------------------------------------------------------------*"
write-host ""

# ================================================================================================================================== #
# Copying provisioning and util folder to the remote server
# ================================================================================================================================== #

$foldersize = Get-Size D:\Scripts\Provisioning
Write-Host "`n*----  Copying Scripts to [ $targetComputer ]  ----*" -Fore Magenta;start-Sleep -Seconds 1 
Write-Host "`nPreparing to copy the Provisioning Folder" -Fore Yellow -Nonewline;start-Sleep -Seconds 2
write-host "`nAmount of data to be moved: " -Fore Yellow -nonewline; Write-host "$foldersize" -Fore White;start-Sleep -Seconds 2
Write-Host "Copying Files" -Fore Yellow -Nonewline;start-Sleep -Seconds 0 
LogWrite "Calling D:\Scripts\Provisioning\CopyScriptsLocally\CopyScriptsLocally.ps1"
powershell -File "D:\Scripts\Provisioning\CopyScriptsLocally\CopyScriptsLocally.ps1" -ComputerName $targetComputer > $null
LogWrite " [ Copying Files ] Complete"
Write-Host " ...Complete" -Fore Green;start-Sleep -Seconds 3 
$foldersize = Get-Size D:\Scripts\utils
Write-Host "`nPreparing to copy the Util Folder" -Fore Yellow -Nonewline;start-Sleep -Seconds 1
write-host "`nAmount of data to be moved: " -Fore Yellow -nonewline; Write-host "$foldersize" -Fore White;start-Sleep -Seconds 1
Write-Host "Copying Files" -Fore Yellow -Nonewline;start-Sleep -Seconds 0 
LogWrite "Calling D:\Scripts\Provisioning\CopyScriptsLocally\CopyScriptsUtil.ps1"
powershell -File "D:\Scripts\Provisioning\CopyScriptsLocally\CopyScriptsUtil.ps1" -ComputerName $targetComputer > $null
LogWrite "[ Copying Util Folder ] Complete"
Write-Host " ...Complete" -Fore Green;start-Sleep -Seconds 3
If ($servertype -eq "sql"){
$foldersize = Get-Size D:\Scripts\sxs
Write-Host "`nPreparing to copy the .NET 3.5 SXS Folder" -Fore Yellow -Nonewline;start-Sleep -Seconds 1
write-host "`nAmount of data to be moved: " -Fore Yellow -nonewline; Write-host "$foldersize" -Fore White;start-Sleep -Seconds 1
Write-Host "Copying Files" -Fore Yellow -Nonewline;start-Sleep -Seconds 0 
LogWrite "Calling D:\Scripts\Provisioning\CopyScriptsLocally\CopyScriptsSQL.ps1"
powershell -File "D:\Scripts\Provisioning\CopyScriptsLocally\CopyScriptsSQL.ps1" -ComputerName $targetComputer > $null
LogWrite "[ Copying SXS Folder ] Complete"
Write-Host " ...Complete" -Fore Green;start-Sleep -Seconds 3 
} 
Else {
}

# ================================================================================================================================== #
# Rerunning base scripts since Vmware Customization Specs wipe out some basic settings
# ================================================================================================================================== #

Write-Host "`n*----  Running Base Settings on [ $targetComputer ] ----*`n" -Fore Magenta;start-Sleep -Seconds 3 
LogWrite "Calling D:\Scripts\Provisioning\basic.ps1"
powershell -File "D:\Scripts\Provisioning\RemoteFunctions\rCmd+.ps1" -UseAdmin -UseHTTP -ComputerName $targetComputer -ScriptBlock "C:\Scripts\Provisioning\basic.ps1" 
LogWrite "[ Running Basics ] Complete"

# ================================================================================================================================== #
# Tuning Drives
# ================================================================================================================================== #

Write-Host "`n*----  Expanding Drives if applicable (Server 2012 only)  ----*`n" -Fore Magenta;start-Sleep -Seconds 1 
LogWrite = "Calling C:\Scripts\Provisioning\12_RolesFeatures\RolesAndFeatures.ps1"
powershell -File "D:\Scripts\Provisioning\RemoteFunctions\rCmd+.ps1" -UseAdmin -UseHTTP -ComputerName $targetComputer -ScriptBlock "C:\Scripts\Provisioning\Partitions\expand_drives.ps1 "
LogWrite "Roles and Features Complete"

# ================================================================================================================================== #
# Initializing Roles and Features
# ================================================================================================================================== #

Write-Host "`n*----  Installation of Roles and Features  ----*`n" -Fore Magenta;start-Sleep -Seconds 1 
LogWrite = "Calling C:\Scripts\Provisioning\12_RolesFeatures\RolesAndFeatures.ps1"
powershell -File "D:\Scripts\Provisioning\RemoteFunctions\rCmd+.ps1" -UseAdmin -UseHTTP -ComputerName $targetComputer -ScriptBlock "C:\Scripts\Provisioning\12_RolesFeatures\RolesAndFeatures.ps1 -ServerType $servertype" 
LogWrite "Roles and Features Complete"

# ================================================================================================================================== #
# Setting PageFile & Basic Drive Permissions if "base" or "sql"
# ================================================================================================================================== #

If (($servertype -eq "base") -or ($servertype -eq "sql")){
	Write-Host "`n*----  Setting PageFile & Basic Drive Permissions  ----*`n" -Fore Magenta;start-Sleep -Seconds 3 
	LogWrite "Calling C:\Scripts\Provisioning\1_W2k8_PostTemplate\Master_Powershell_Base.ps1"
	powershell -File "D:\Scripts\Provisioning\RemoteFunctions\rCmd+.ps1" -UseAdmin -UseHTTP -ComputerName $targetComputer -ScriptBlock "C:\Scripts\Provisioning\1_W2k8_PostTemplate\Master_Powershell_Base.ps1"  
	LogWrite "[ Setting PageFile & Basic Drive Permissions ] Complete"
    Write-Host " ...Complete" -Fore Green;start-Sleep -Seconds 1 
}

# ================================================================================================================================== #
# Setting PageFile & Basic Drive Permissions if "web"
# ================================================================================================================================== #

ElseIf ($servertype -eq "web") {
	Write-Host "`n*----  Installing IIS since the Web role was selected  ----*`n" -Fore Magenta;start-Sleep -Seconds 3 
    LogWrite "Calling C:\Scripts\Provisioning\1_W2k8_PostTemplate\Master_Powershell_IIS.ps1"
    powershell -File "D:\Scripts\Provisioning\RemoteFunctions\rCmd+.ps1" -UseAdmin -UseHTTP -ComputerName $targetComputer -ScriptBlock "C:\Scripts\Provisioning\1_W2k8_PostTemplate\Master_Powershell_IIS.ps1" 
    LogWrite "[ IIS Full installation ] Complete"
    Write-Host "`n...IIS Role installed" -Fore Green;start-Sleep -Seconds 1 
}
Else {
}

If ($inad -eq "false"){
# ================================================================================================================================== #
# Joining Domain
# ================================================================================================================================== #

Write-Host "`n*----  Joining the [ $Domain ] Domain  ----*`n" -Fore Magenta;start-Sleep -Seconds 3 
LogWrite "Calling C:\Scripts\Provisioning\4_JoinDomain\JoinDomain.ps1"
powershell -File "D:\Scripts\Provisioning\RemoteFunctions\rCmd+.ps1" -UseAdmin -UseHTTP -ComputerName $targetComputer -ScriptBlock "C:\Scripts\Provisioning\4_JoinDomain\JoinDomain.ps1 -Domain $Domain -OU $OU" 
LogWrite "[ Joining %Domain Domain ] Complete"

# ================================================================================================================================== #
# Reboot Computer
# ================================================================================================================================== #

Write-Host "`n*----  Rebooting [ $targetComputer ]  ----*`n" -Fore Magenta;start-Sleep -Seconds 3 
LogWrite "Restarting Remote Server"
powershell -File "D:\Scripts\Provisioning\RemoteFunctions\rCmd+.ps1" -UseAdmin -UseHTTP -ComputerName $targetComputer -ScriptBlock 'Restart-Computer -Confirm:$False -Force' 
Write-Host "`nRebooting Server" -Fore Yellow -nonewline;start-Sleep -Seconds 2
Do {Start-Sleep -s 30}
Until (test-connection $targetComputer -quiet)
Write-Host " ...Complete" -Fore Green;start-Sleep -Seconds 2
LogWrite "Restart Complete"
}
Else {
}



# ================================================================================================================================== #
# Configuring Nic(s)
# ================================================================================================================================== #

Write-Host "`n*----  Configuring Networking on [ $targetComputer ]  ----*`n" -Fore Magenta;start-Sleep -Seconds 3 
LogWrite "Calling D:\Scripts\Provisioning\2_NetworkConfig\NicConfig.ps1"
powershell -File "D:\Scripts\Provisioning\RemoteFunctions\rScript+.ps1" -UseAdmin -UseHTTP -ComputerName $targetComputer -FilePath D:\Scripts\Provisioning\2_NetworkConfig\NicConfig.ps1 -ArgumentList $PrivateIP 
LogWrite "[ Configuring Networking ] Complete"

# ================================================================================================================================== #
# Adding Server Ops Security
# ================================================================================================================================== #

Write-Host "`n*----  Adding Server_Ops Security to [ $targetComputer ] ----*`n" -Fore Magenta;start-Sleep -Seconds 1 
LogWrite "Calling D:\Scripts\Provisioning\5_AddServerOps\AddServerOps.ps1"
powershell -File "D:\Scripts\Provisioning\RemoteFunctions\rScript+.ps1" -UseAdmin -UseHTTP -ComputerName $targetComputer -FilePath D:\Scripts\Provisioning\5_AddServerOps\AddServerOps.ps1 
LogWrite "[ Adding Server_Ops Security ] Complete"

# ================================================================================================================================== #
# Certification Request and Import
# ================================================================================================================================== #

Write-Host "`n*----  Requesting and Importing Certs for [ $targetComputer ]  ----*`n" -Fore Magenta;start-Sleep -Seconds 1 
Logwrite "Calling D:\Scripts\Provisioning\6_CertRequest\ServerCertRequest.ps1"
powershell -File "D:\Scripts\Provisioning\6_CertRequest\ServerCertRequest.ps1" -ComputerName $targetComputer 
LogWrite "[ Requesting Cert & Importing ] Complete"
Write-Host "...Cert Work Complete" -Fore Green;start-Sleep -Seconds 1 

# ================================================================================================================================== #
# Enabling Powershell over HTTPS
# ================================================================================================================================== #

Write-Host "`n*----  Enabling Powershell over HTTPS on [ $targetComputer ]  ----*`n" -Fore Magenta;start-Sleep -Seconds 1 
LogWrite "Calling C:\Scripts\Provisioning\7_WinRMHTTPS\ScheduleENABLE.ps1"
powershell -File "D:\Scripts\Provisioning\RemoteFunctions\rCmd+.ps1" -UseAdmin -UseHTTP -ComputerName $targetComputer -ScriptBlock "C:\Scripts\Provisioning\7_WinRMHTTPS\ScheduleENABLE.ps1" 
LogWrite "[ Enable Powershell Remoting over HTTPS ] Complete"

# ================================================================================================================================== #
# Disabling Powershell Remoting over HTTP
# ================================================================================================================================== #

Write-Host "`n*----  Disabling Powershell Remoting over HTTP on [ $targetComputer ]  ----*`n" -Fore Magenta;start-Sleep -Seconds 1 
LogWrite "Calling C:\Scripts\Provisioning\7_WinRMHTTPS\ScheduleDISABLE.ps1"
powershell -File "D:\Scripts\Provisioning\RemoteFunctions\rCmd+.ps1" -UseRunBook -ComputerName $targetComputer -ScriptBlock "C:\Scripts\Provisioning\7_WinRMHTTPS\ScheduleDISABLE.ps1" 
LogWrite "[ Disabling Powershell Remoting over HTTP ] Complete"

# ================================================================================================================================== #
# Renaming Admin and Guest Accounts
# ================================================================================================================================== #

Write-Host "`n*----  Renaming Admin & Guest Accounts on [ $targetComputer ]  ----*`n" -Fore Magenta;start-Sleep -Seconds 1 
LogWrite "Calling C:\Scripts\Provisioning\1_W2k8_PostTemplate\LocalAccount_PS_config.ps1"
#powershell -File "D:\Scripts\Provisioning\RemoteFunctions\rCmd+.ps1" -UseRunBook -ComputerName $targetComputer -ScriptBlock "C:\Scripts\Provisioning\1_W2k8_PostTemplate\LocalAccount_PS_config.ps1" 
LogWrite "[ Renaming Admin & Guest accounts ] Complete"

# ================================================================================================================================== #
# Performing FTP procedures if "ftp"
# ================================================================================================================================== #

If ($servertype -eq "ftp") {
Write-Host "`n*----  Performing FTPIP Procedures on [ $targetComputer ]  ----*`n" -Fore Magenta;start-Sleep -Seconds 1 
LogWrite "Calling D:\Scripts\Provisioning\9_BaseFTPSite\BaseFTPSite.ps1"
powershell -File "D:\Scripts\Provisioning\RemoteFunctions\rScript+.ps1" -UseRunBook -ComputerName $targetComputer -FilePath D:\Scripts\Provisioning\9_BaseFTPSite\BaseFTPSite.ps1 -ArgumentList $ftpIP 
LogWrite "[ If FTP add FTPIP procedure ] Complete"
Write-Host "`n...FTPIP Procedure complete" -Fore Green;start-Sleep -Seconds 1 
}
Else {
}

# ================================================================================================================================== #
# Qradar Installation
# ================================================================================================================================== #

If ($qradar -eq "yes") {
Write-Host "`n*----  Installing Qradar on [ $targetComputer ]  ----*`n" -Fore Magenta;start-Sleep -Seconds 1 
LogWrite "Calling C:\Scripts\Provisioning\Qradar\Qradar.ps1"
powershell -File "D:\Scripts\Provisioning\RemoteFunctions\rCmd+.ps1" -UseAdmin -UseHTTP -ComputerName $targetComputer -ScriptBlock "C:\Scripts\Provisioning\Qradar\Qradar.ps1" 
LogWrite "[ Renaming Admin & Guest accounts ] Complete"
}
Else {
}

# ================================================================================================================================== #
# Completion Message
# ================================================================================================================================== #

write-host "`n`t           ___________________________________________________________________________________" -fore green;start-Sleep -Seconds 1 
write-host "`t  ________|                                                                                   |_______" -fore green;start-Sleep -Seconds 1 
write-host "`t  \       |                    Server Installation & Provisioning is complete                 |      /" -fore green;start-Sleep -Seconds 1
write-host "`t   \      |  Please reboot server your server to ensure all configurations are initialized    |     /" -fore green;start-Sleep -Seconds 1
write-host "`t    \     |                                                                                   |    /"               -fore green;start-Sleep -Seconds 1
write-host "`t    /     |     Install log for this install can be found at C:\Scripts\Logs\installlogs\     |    \" -fore green;start-Sleep -Seconds 1
write-host "`t   /      |___________________________________________________________________________________|     \" -fore green;start-Sleep -Seconds 1
write-host "`t  /__________)                                                                             (_________\" -fore green;start-Sleep -Seconds 1
write-host ""
}






# ==========================================================================================
# 
#                          1. Start of Post Deployment Script
# 
# ==========================================================================================


#--- variable to gather local IP of server script is being run on ---*
$localip = (gwmi Win32_NetworkAdapterConfiguration | ? { $_.IPAddress -ne $null }).ipaddress

#--- variable to gather logged in user ---*
$loggedinuser = [Environment]::UserName

#--- variable to set FTP to null ---*
$ftpIP = "NA"

CLS
#--- Header ---*
write-host "`n`n"
Write-Centered-Red "*-----------------------------------------------------------------------------------*"
Write-Centered-Red "Maritz Automated Post Script Process – Version 2.0"
Write-Centered-Red "*-----------------------------------------------------------------------------------*`n`n"

#--- Collecting Server Name ---*
Write-Centered-Yellow “Please provide Target Computer Name and Private IP`n`n” 
$targetComputer = Read-Host "`t`tEnter server name of the machine being deployed" 
LogSetup
LogWrite " Script is being run by [ $loggedinuser ]"
LogWrite " Server name is [ $targetComputer ]`n"

#--- Function to query dns of $targetComputer ---*
write-host "`n`t`tClearing local dns cache" -Fore Yellow -nonewline;start-Sleep -Seconds 2
Flushdns > $null
Write-Host " ...Dns flushed" -Fore Green;start-Sleep -Seconds 2
write-host "`t`tLooking up DNS entry for this server" -Fore Yellow -nonewline;start-Sleep -Seconds 2 
Get-DNS

#--- Function to ensure that IP address is pingable ---*
write-host "`t`tEnsuring the server is online" -Fore Yellow -nonewline;start-Sleep -Seconds 1
CheckIPisActive
write-host "`t`tServer [ $targetComputer ] appears to be online and ready`n" -Fore Green;start-Sleep -Seconds 3

#--- Collecting IP Address ---*
$PrivateIP = Read-Host "`t`tEnter Production IP for machine being deployed"
LogWrite " IP input is [ $PrivateIP ]"

#--- Function to ensure that IP address is in a valid format ---*
write-host "`n`t`tChecking IP address format" -Fore Yellow -nonewline;start-Sleep -Seconds 2 
CheckIPisValid
write-host ""

#--- QRadar installation? ---*
$qradar = Read-Host "`t`tDo you need Qradar installed? (Y/N)"

If (($qradar -eq "y") -or ($qradar -eq "Y")) { $qradar = "yes" }
ElseIf (($qradar -eq "n") -or ($qradar -eq "N")) { $qradar = "no" }
Else {}

#--- Jump to Function: MenuRole ---*
MenuRole

#-- The script ends at the end of the PostScript Function --*