
Function Pause {
Read-Host "`n`t`tPress Enter to continue..." | Out-Null
}
Function WelcomeMessage {
MenuHeader
Write-host "`n`t`tWelcome to Version 3 of the Post Scripts!`n" -fore yellow
Write-host "`t`tHere are some of the new features:`n" -fore gray
Write-host "`t`t1: Local environmental check" -fore gray
Write-host "`t`t- This identifies local mid server issues and corrects them before running the script`n" -fore darkgray
Write-host "`t`t2: Functionalized all remote script calls" -fore gray
Write-host "`t`t- This greatly improves our flexibility with making script changes`n" -fore darkgray
Write-host "`t`t3: Combined all functions into a function file" -fore gray
Write-host "`t`t- This greatly cleaned up our scripts for easier management`n" -fore darkgray
Write-host "`t`t4: Corrected a loop error we were seeing in V2`n" -fore gray
Write-host "`t`t5: Optional Email Alert added when script is complete`n" -fore gray
Write-host "`t`t6: OU verification check" -fore gray
Write-host "`t`t- We now have a verification in place to ensure the server is placed in the right OU`n" -fore darkgray
Write-host "`t`t7: Top notation to show last editing date`n" -fore gray
Write-host "`t`t8: Moved the updating process to later in the script`n" -fore gray
Write-host "`t`t9: We can launch the provisioning script from a one-liner like the example shown below" -fore gray
Write-host "`t`t.\Server_Provisioning.ps1 -TargetComputer "ns2008-new" -PrivateIP "156.45.55.60" " -fore darkgray
Write-host "`t`t-ftpIP "10.10.10.10" -servertype "APP" -Domain "us" -OU "APP" -emailalert "n" -Wincollect "n"" -fore darkgray
Write-host "`t`t -DisplayResults "n" -Updates "n"" -fore darkgray

Pause
}
Function DetectLocalOS {
write-host "Detecting Local OS" -Fore Yellow -nonewline
$OSVerNumber = (Get-WmiObject Win32_OperatingSystem).version
Switch -wildcard ($OSVerNumber){
                "5.2*" { 
				$script:OSversion = "2003" 
				Write-host " ...$OSversion Detected" -Fore Green
				}
                "6.0*" { 
				$script:OSversion = "2008" 
				Write-host " ...$OSversion Detected" -Fore Green
				}
                "6.1*" { 
				$script:OSversion = "2008R2" 
				Write-host " ...$OSversion Detected" -Fore Green
				}
                "6.2*" { 
				$script:OSversion = "2012" 
				Write-host " ...$OSversion Detected" -Fore Green
				}
                "6.3*" { 
				$script:OSversion = "2012R2"
				Write-host " ...$OSversion Detected" -Fore Green
				}
                default { 
				$script:OSversion = "Unknown" 
				Write-host " ...$OSversion Detected" -Fore Green
				}
}

}
function Get-ScriptDirectory{
  $Invocation = (Get-Variable MyInvocation -Scope 1).Value
  Split-Path $Invocation.MyCommand.Path
}
Function MenuHeader {
CLS
$x = Get-Item D:\Scripts\Server_Provisioning-TEST.ps1 | select LastWriteTime
$lwt = $x.LastWriteTime
write-host "`n"
Write-Centered-Red "*-----------------------------------------------------------------------------------*"
Write-Centered-Red "Maritz Automated Post Script Process – Version 3.0"
Write-Centered-Red "*-----------------------------------------------------------------------------------*"
Write-Centered-DarkGray "The last time this script was updated was $lwt`n"
}
Function ServerName {
Write-Centered-Yellow “General Configuration and Setup`n`n” 
$script:targetComputer = Read-Host "`t`tEnter server name of the machine being deployed" 
}
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
LogWrite " Script is being run by [ $loggedinuser ]"
LogWrite " Server name is [ $targetComputer ]`n"
}
Function ClearDns {
write-host "`n`t`tClearing local dns cache" -Fore Yellow -nonewline;start-Sleep -Seconds 0
Flushdns > $null
Write-Host " ...Dns flushed" -Fore Green;start-Sleep -Seconds 0
write-host "`t`tLooking up DNS entry for this server" -Fore Yellow -nonewline;start-Sleep -Seconds 0 
Get-DNS
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
Write-host " ...$dnsip" -Fore Green;start-Sleep -Seconds 0
} else {
write-host " ...No DNS entry found." -Fore Red;start-Sleep -Seconds 0
}
}
Function PingTest {
write-host "`t`tAttempting to PING [ $targetComputer ]" -Fore Yellow -nonewline;start-Sleep -Seconds 0
CheckIPisActive
}
Function CheckIPisActive {
$testconnection = Test-Connection -computer $targetComputer -quiet
If ($testconnection -eq "true"){
Write-host " ...Server is pingable`n"-Fore Green;start-Sleep -Seconds 0
}
Else {
Write-host " ...Server is not responding to ping."-Fore Red;start-Sleep -Seconds 0
Write-host "`n`t`tServer being deployed needs to be on the network and accessible to continue."-Fore Red;start-Sleep -Seconds 0
Write-host ""
Read-Host "`t`tPress enter to restart..." | Out-Null
.\Automated_Post_Scripts.ps1
}
}
Function EnterIP {
$script:privateip = Read-Host "`t`tEnter Production IP for machine being deployed"
LogWrite " IP input is [ $PrivateIP ]"
}
Function CheckIPisValid {
write-host "`n`t`tChecking IP address format" -Fore Yellow -nonewline;start-Sleep -Seconds 0
if($PrivateIP -match "(\d{1,3}).(\d{1,3}).(\d{1,3}).(\d{1,3})") { 
Write-host " ...Format is valid`n" -Fore Green;start-Sleep -Seconds 0
LogWrite " IP address format was valid"
 } Else {
Write-host "`n`t`tThe IP address you used is in an improper format.  Please try again." -Fore Red;start-Sleep -Seconds 0
LogWrite " IP address format was not valid.  Reloading Menu"
Write-host ""
Read-Host "`t`tPress enter to restart..." | Out-Null
.\Server_Provisioning.ps1
 }
 }
Function Wincollectyn {
$script:wincollect = Read-Host "`t`tDo you need WinCollect installed? [ALE replacement] (Y/N)"
If (($wincollect -eq "y") -or ($wincollect -eq "Y")) { 
write-host "`n`t`tPreparing WinCollect package" -Fore Yellow -nonewline;start-Sleep -Seconds 0
$script:wincollect = "yes"
Write-Host " ....Complete`n" -Fore Green ;start-Sleep -Seconds 0  
}
ElseIf (($wincollect -eq "n") -or ($wincollect -eq "N")) {
write-host "`n`t`tRemoving WinCollect package" -Fore Red -nonewline;start-Sleep -Seconds 0 
$script:wincollect = "no"
Write-Host " ....Complete`n" -Fore Green ;start-Sleep -Seconds 0 
}
Else {}
 }
Function EmailAlert {
 $script:emailalert = Read-Host "`t`tDo you want to receive an email alert when complete? (Y/N)"
 If (($emailalert -eq "y") -or ($emailalert -eq "Y")) {
 $script:emailaddy = Read-host "`n`t`tPlease enter your email address"
 $script:emailalert = "yes"
 }
 ElseIf (($emailalert -eq "n") -or ($emailalert -eq "N")) {
 $script:emailalert = "no"
 }
 Else { }
 }
Function SelectRole {
 Do{
Write-Centered-Yellow “Please select the type of server you are deploying” 
write-host ""
Write-Centered-Yellow “1. Base/APP Server    ” 
Write-Centered-Yellow “2. Domain Controller  ” 
Write-Centered-Yellow “3. FTP Server         ” 
Write-Centered-Yellow “4. Print              ” 
Write-Centered-Yellow “5. SQL Server         ” 
Write-Centered-Yellow “6. Web/Wap            ”
Write-Centered-Yellow “7. Exit Script        ”  
Write-host ""
$script:menunum = Read-Host "`t`tSelect one of the above options"
} until (($menunum -eq "1") -or ($menunum -eq "2") -or ($menunum -eq "3") -or ($menunum -eq "4") -or ($menunum -eq "5") -or ($menunum -eq "6") -or ($menunum -eq "7"))
switch ($menunum){
"1" {
$script:servertype = "base"
LogWrite " Server role set to [ $servertype ]"
}
"2" {
$script:servertype = "dc"
LogWrite " Server role set to [ $servertype ]"
}
"3" {
$script:servertype = "ftp"
LogWrite " Server role set to [ $servertype ]"
MenuHeader
write-host ""
Write-Centered-Yellow “Please provide FTP IP for the machine being deployed.” 
write-host ""
write-host ""
$script:ftpIP = Read-Host "`t`tEnter FTP IP address" 
LogWrite " FTP IP set to [ $ftpIP ]"
}
"4" {
$script:servertype = "print"
LogWrite " Server role set to [ $servertype ]"
}
"5" {
$script:servertype = "sql"
LogWrite " Server role set to [ $servertype ]"
}
"6" {
$script:servertype = "web"
LogWrite " Server role set to [ $servertype ]"
MenuHeader
write-host ""
Write-Centered-Yellow “Please provide FTP IP for the machine being deployed.” 
write-host ""
write-host ""
$script:ftpIP = Read-Host "`t`tEnter FTP IP address" 
LogWrite " FTP IP set to [ $ftpIP ]"
}
"7" {
LogWrite "Exiting Script"
Exit}
}
}
Function SelectDomain {
Do{
write-host ""
Write-Centered-Yellow “Please select the Domain you are going to deploy to” 
write-host ""
Write-Centered-Yellow “1. US                 ” 
Write-Centered-Yellow “2. MPNE               ” 
Write-Centered-Yellow “3. MNETI              ” 
Write-Centered-Yellow “4. MNETE              ” 
Write-Centered-Yellow “5. MPN                ” 
Write-Centered-Yellow “6. MPNI               ”
Write-Centered-Yellow “7. LAB                ”
Write-Centered-Yellow “8. Exit Script        ”  
write-host ""
$menunum = Read-Host "`t`tSelect one of the above options"
} until (($menunum -eq "1") -or ($menunum -eq "2") -or ($menunum -eq "3") -or ($menunum -eq "4") -or ($menunum -eq "5") -or ($menunum -eq "6") -or ($menunum -eq "7") -or ($menunum -eq "8"))
switch ($menunum){
"1" {
$script:Domain = "us"
LogWrite " Domain set to [ $Domain ]"
}
"2" {
$script:Domain = "mpne"
LogWrite " Domain set to [ $Domain ]"
}
"3" {
$script:Domain = "mneti"
LogWrite " Domain set to [ $Domain ]"
}
"4" {
$script:Domain = "mnete"
LogWrite " Domain set to [ $Domain ]"
}
"5" {
$script:Domain = "mpn"
LogWrite " Domain set to [ $Domain ]"
}
"6" {
$script:Domain = "mpni"
LogWrite " Domain set to [ $Domain ]"
}
"7" {
$script:Domain = "LAB"
LogWrite " Domain set to [ $Domain ]" 
Exit
}
"8" {
Logwrite " Exiting Script" 
Exit
}
}
}
Function CheckUSDomain {
$ErrorActionPreference = 'SilentlyContinue'
if (-not $( Get-ADComputer -Identity $targetComputer -Server us.maritz.net)){ 
Write-host "Not in AD"
$script:inusad = "false"
}
else {
Write-host "in AD"
$script:inusad = "true"
}
}
Function New-RegistryKey([string]$key,[string]$Name,[string]$type,[string]$value) {

    #Split the registry path into its single keys and save
    #them in an array, use \ as delimiter:
    $subkeys = $key.split("\")
    
      #Do this for all elements in the array:
    foreach ($subkey in $subkeys)
    {
        #Extend $currentkey with the current element of
        #the array:
        $currentkey += ($subkey + '\')

        #Check if $currentkey already exists in the registry
        if (!(Test-Path $currentkey))
        {
            #If no, create it and send Powershell output
            #to null (don't show it)
            New-Item -Type String $currentkey | Out-Null
        }
     }
     #Set (or change if already exists) the value for $currentkey
      Set-ItemProperty $CurrentKey $Name -value $Value -type $type 
} 
Function SelectOU {
DO{
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
Write-host ""
$menunum = Read-Host "`t`tSelect one of the above options"
} until (($menunum -eq "1") -or ($menunum -eq "2") -or ($menunum -eq "3") -or ($menunum -eq "4") -or ($menunum -eq "5") -or ($menunum -eq "6") -or ($menunum -eq "7") -or ($menunum -eq "8") -or ($menunum -eq "9"))
switch ($menunum){
"1" {
$script:OU = "WEB"
LogWrite " OU set to [ $OU ]"
}
"2" {
$script:OU = "WAP"
LogWrite " OU set to [ $OU ]"
}
"3" {
$script:OU = "SQL"
LogWrite " OU set to [ $OU ]"
}
"4" {
$script:OU = "APP"
LogWrite " OU set to [ $OU ]"
}
"5" {
$script:OU = "ADFS"
LogWrite " OU set to [ $OU ]"
}
"6" {
$script:OU = "CLOUD"
LogWrite " OU set to [ $OU ]"
}
"7" {
$script:OU = "FTP"
LogWrite " OU set to [ $OU ]"
}
"8"{
$script:OU = "TERMINAL"
LogWrite " OU set to [ $OU ]"
}
"9"{
LogWrite " Exiting Script"
Exit
}
}
}
Function DisplayResults {
write-host "`n"
Write-host "`t`t`t                     Verify your input choices                 "
Write-host "`t`t`t+-------------------------------------------------------------+"
Write-host "`t`t`t|"
Write-host "`t`t`t|  Displaying Input Results...";start-Sleep -Seconds 1
Write-host "`t`t`t|  Server Name: " -nonewline; Write-host "$targetComputer" -Fore Yellow;start-Sleep -Seconds 0
Write-host "`t`t`t|  Server Type: " -nonewline; Write-host "$servertype" -Fore Yellow;start-Sleep -Seconds 0
Write-host "`t`t`t|  Local IP: " -nonewline; Write-host "$PrivateIP" -Fore Yellow;start-Sleep -Seconds 0
Write-host "`t`t`t|  OU: " -nonewline; Write-Host "$OU" -Fore Yellow;start-Sleep -Seconds 0
Write-host "`t`t`t|  Domain: " -nonewline; Write-host "$Domain" -Fore Yellow;start-Sleep -Seconds 0
Write-host "`t`t`t|  FTP IP: " -nonewline; Write-host "$ftpIP" -Fore Yellow;start-Sleep -Seconds 0
Write-host "`t`t`t|  Server is in AD?: " -nonewline; Write-host "$inad" -Fore Yellow;start-Sleep -Seconds 0
Write-host "`t`t`t|  Install WinCollect?: " -nonewline; Write-host "$wincollect" -Fore Yellow;start-Sleep -Seconds 0
Write-host "`t`t`t|  In US Domain Already??: " -nonewline; Write-host "$inusad" -Fore Yellow;start-Sleep -Seconds 0
Write-host "`t`t`t|"
Write-host "`t`t`t+-------------------------------------------------------------+"
Write-host "`t`t`t         If any of this is wrong, Hit Cntrl+C now              " -Fore Red;start-Sleep -Seconds 2
Write-host "`t`t`t      You have 10 seconds.." -Fore Red -nonewline;start-Sleep -Seconds 1
$i = 9
do 
{
write-host "..$i" -Fore Red -NoNewline; start-sleep -seconds 1
 $i--
} while ($i -gt -1)
}
Function CopyFiles {
$script:foldersize = Get-Size D:\Scripts\MaritzProvisioning
LogWrite "Copying Over Files"
################################
If (!($targetComputer)){
	Write-Host "computerName was not passed using the -computerName option.  Remote session was not established. ****" -Fore Red;start-Sleep -Seconds 0
	break
}

$script:mysession = D:\Scripts\MaritzProvisioning\dependencies\RemoteFunctions\New-RemoteSession\New-RemoteSession.ps1 -computerName $targetComputer -UseAdmin -UseHTTP

If ($mysession) {
	Write-Host "Copying Configuration Files To: [ $targetComputer ]" -Fore Yellow;start-Sleep -Seconds 0
	Write-Host "Copying " -Fore Yellow -Nonewline; Write-host "[ $foldersize ]" -Fore White -NoNewline; Write-Host " of data " -Fore Yellow -Nonewline
	D:\Scripts\MaritzProvisioning\dependencies\Send-Directory.ps1 -Session $mysession -localPath "D:\Scripts\MaritzProvisioning" -remotePath "C:\Scripts\Provisioning" >$null
}
Else { 
	Write-Host "ERROR: Session not found!" -Fore Cyan;start-Sleep -Seconds 0
	break
}
Remove-PSSession $mysession
################################
LogWrite " [ Copying Files ] Complete"
Write-Host " ...Complete" -Fore Green;start-Sleep -Seconds 0 
}
Function Phase1 {
LogWrite = "Calling C:\Scripts\Provisioning\12_RolesFeatures\RolesAndFeatures.ps1"
#powershell -File "D:\Scripts\MaritzProvisioning\dependencies\RemoteFunctions\rCmd+.ps1" -UseAdmin -UseHTTP -ComputerName $targetComputer -ScriptBlock "C:\Scripts\Provisioning\OSConfig\Phase1.ps1     -TargetComputer $targetComputer -ServerType $servertype -PrivateIP $PrivateIP -Domain $Domain -OU $OU -ftpIP $ftpIP -inusad $inusad"
$phasestep = 1
powershell -File "D:\Scripts\MaritzProvisioning\dependencies\RemoteFunctions\rCmd+.ps1" -UseAdmin -UseHTTP -ComputerName $targetComputer -ScriptBlock "C:\Scripts\Provisioning\OSConfig\Phase_File.ps1 -TargetComputer $targetComputer -ServerType $servertype -PrivateIP $PrivateIP -Domain $Domain -OU $OU -ftpIP $ftpIP -inusad $inusad -phasestep $phasestep"
LogWrite "Phase 1 Complete"
}
Function Phase2 {
LogWrite = "Calling C:\Scripts\Provisioning\12_RolesFeatures\RolesAndFeatures.ps1"
#powershell -File "D:\Scripts\MaritzProvisioning\dependencies\RemoteFunctions\rCmd+.ps1" -UseAdmin -UseHTTP -ComputerName $targetComputer -ScriptBlock "C:\Scripts\Provisioning\OSConfig\Phase2.ps1 -TargetComputer $targetComputer -ServerType $servertype -PrivateIP $PrivateIP -Domain $Domain -OU $OU -ftpIP $ftpIP"
$phasestep = 2
powershell -File "D:\Scripts\MaritzProvisioning\dependencies\RemoteFunctions\rCmd+.ps1" -UseAdmin -UseHTTP -ComputerName $targetComputer -ScriptBlock "C:\Scripts\Provisioning\OSConfig\Phase_File.ps1 -TargetComputer $targetComputer -ServerType $servertype -PrivateIP $PrivateIP -Domain $Domain -OU $OU -ftpIP $ftpIP -inusad $inusad -phasestep $phasestep"
LogWrite "Phase 2 Complete"
}
Function Phase3 {
LogWrite = "Calling C:\Scripts\Provisioning\12_RolesFeatures\RolesAndFeatures.ps1"
#powershell -File "D:\Scripts\MaritzProvisioning\dependencies\RemoteFunctions\rCmd+.ps1" -UseAdmin -UseHTTP -ComputerName $targetComputer -ScriptBlock "C:\Scripts\Provisioning\OSConfig\Phase3.ps1 -TargetComputer $targetComputer -ServerType $servertype -PrivateIP $PrivateIP -Domain $Domain -OU $OU -ftpIP $ftpIP -OSversion $OSversion"
$phasestep = 3
powershell -File "D:\Scripts\MaritzProvisioning\dependencies\RemoteFunctions\rCmd+.ps1" -UseAdmin -UseHTTP -ComputerName $targetComputer -ScriptBlock "C:\Scripts\Provisioning\OSConfig\Phase_File.ps1 -TargetComputer $targetComputer -ServerType $servertype -PrivateIP $PrivateIP -Domain $Domain -OU $OU -ftpIP $ftpIP -inusad $inusad -phasestep $phasestep"
LogWrite "Phase 3 Complete"
}
Function CertReq {

# Dot Source the Send-File Function
. D:\Scripts\Provisioning\DotSource\Send-File\Send-File.ps1

# Create Remote Session
$Session = Invoke-Expression "D:\Scripts\Provisioning\RemoteFunctions\New-RemoteSession\New-RemoteSession.ps1 -ComputerName $targetComputer -UseAdmin -UseHTTP"

# Determine Certificate File
$certName = Invoke-Command -Session $Session -ScriptBlock { [System.Net.DNS]::GetHostByName('').HostName }
Write-Host "CertName = $certName"

# Remove the Remote Session
Remove-PSSession $Session

Invoke-Expression "D:\Scripts\SSLCerts\1_SSLCertRequest.ps1 -UseAdmin -ComputerName $targetComputer -CertName $certName"
Invoke-Expression "D:\Scripts\SSLCerts\2_CertSubmitFENWEBOPS05.ps1 -CertName $certName"
Invoke-Expression "D:\Scripts\SSLCerts\3_InstallSignedCertificate.ps1 -UseAdmin -ComputerName $targetComputer -CertName $certName"
}
Function WinUpdates {
LogWrite = "Calling C:\Scripts\Provisioning\12_RolesFeatures\RolesAndFeatures.ps1"
powershell -File "D:\Scripts\MaritzProvisioning\dependencies\RemoteFunctions\rCmd+.ps1" -UseAdmin -UseHTTP -ComputerName $targetComputer -ScriptBlock "C:\Scripts\Provisioning\dependencies\WindowsUpdates\launch.ps1 -TargetComputer $targetComputer -ServerType $servertype -PrivateIP $PrivateIP -Domain $Domain -OU $OU -ftpIP $ftpIP"
LogWrite "Windows Update Complete"
}
Function CompleteMessage {
write-host "`n`t           ___________________________________________________________________________________" -fore green;start-Sleep -Seconds 0 
write-host "`t  ________|                                                                                   |_______" -fore green;start-Sleep -Seconds 0
write-host "`t  \       |                    Server Installation & Provisioning is complete                 |      /" -fore green;start-Sleep -Seconds 0
write-host "`t   \      |                                                                                   |     /" -fore green;start-Sleep -Seconds 0
write-host "`t    \     |                                                                                   |    /" -fore green;start-Sleep -Seconds 0
write-host "`t    /     |     Install log for this install can be found at C:\Scripts\Logs\installlogs\     |    \" -fore green;start-Sleep -Seconds 0
write-host "`t   /      |___________________________________________________________________________________|     \" -fore green;start-Sleep -Seconds 0
write-host "`t  /__________)                                                                             (_________\" -fore green;start-Sleep -Seconds 0
write-host ""
}
Function Get-Size{
 param([string]$pth)
 "{0:n2}" -f ((gci -path $pth -recurse | measure-object -property length -sum).sum /1mb) + " mb"
}
Function TrustedHostsCheck {
Write-host "Confirming Trusted Host Value is correct" -fore yellow -nonewline
$trustedhosts = (Get-Item wsman:localhost\client\trustedhosts).Value
if ($trustedhosts -eq "*") {
write-host " ...Complete" -fore green
}
Else {
write-host " ...Host value incorrect" -fore red
Write-host "Changing Trusted Host Value to Accept All " -fore yellow -nonewline
Set-Item WSMan:\localhost\Client\TrustedHosts -Value * -Force
write-host " ...Complete" -fore green
}
}
Function ClearKerberosTickets {
Write-host "Clearing Kerberos Tickets" -fore yellow -nonewline
KList purge > $null
write-host " ...Complete" -fore green
}
Function SendCompletionEmail {
Write-host "Sending Completion Email" -fore yellow -nonewline
Send-MailMessage -from "Post-Scripts <postscripts@matitz.com>" -to "<$emailaddy>" -subject "$targetComputer Provisioning Is Complete" -body " Provisioning of $targetComputer is complete" -smtpServer Mifenmail99.maritz.com
write-host " ...Complete" -fore green
}
Function RebootRemoteServer {
Write-Host "Rebooting $targetComputer" -Fore Yellow -Nonewline;start-Sleep -Seconds 0
Restart-Computer -Computername "$targetComputer" -Wait -For Wmi
Write-Host " ....Complete" -Fore Green ;start-Sleep -Seconds 0 
}
Function StopTimer{
#--- Stop script timer ---#
$end = Get-Date
Write-Host "`nIt took " -Fore Yellow -nonewline
$ts = ($end - $start)
$tm = $ts.TotalMinutes
$math = [math]::round($tm,0)
write-host $math -NoNewline -Fore White
write-host " minutes to provision this server" -Fore Yellow
}
Function Exit {
Exit-PSSession
} 
Function ConfirmUSDomainAppOU {
$a = (Get-ADComputer "$targetComputer").DistinguishedName
if ($a -Match "APP") {
Write-host " ...Confirmed" -fore green
}
Else {
write-host " ...Needs to be moved" -fore Cyan
Write-host "Moving $targetComputer to the App OU" -fore yellow -nonewline
Move-ADObject -Identity "OU=Prod App,OU=Servers,DC=us,DC=maritz,DC=net" -TargetPath $oupath
Write-host " ...Complete" -fore green
}
}

################################################################################################

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
Function Write-Centered-DarkGray {
    Param(  [string] $message,
            [string] $color = "DarkGray")
    $offsetvalue = [Math]::Round(([Console]::WindowWidth / 2) + ($message.Length / 2))
    Write-Host ("{0,$offsetvalue}" -f $message) -ForegroundColor $color
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

################################################################################################
#    Area below is for V2 Functions
################################################################################################

Function MidServerSetup {
Write-Host "`n*----  Local Mid-Server Setup Check  ----*`n" -Fore Magenta;start-Sleep -Seconds 0 
TrustedHostsCheck
ClearKerberosTickets
}
Function CopyProvisioningFolder {
# Copying provisioning folder to the remote server
$foldersize = Get-Size D:\Scripts\Provisioning
Write-Host "`n*----  Copying Scripts to [ $targetComputer ]  ----*" -Fore Magenta;start-Sleep -Seconds 0 
Write-Host "`nPreparing to copy the Provisioning Folder" -Fore Yellow -Nonewline;start-Sleep -Seconds 0
write-host "`nAmount of data to be moved: " -Fore Yellow -nonewline; Write-host "$foldersize" -Fore White;start-Sleep -Seconds 0
Write-Host "Copying Files" -Fore Yellow -Nonewline;start-Sleep -Seconds 0 
LogWrite "Calling D:\Scripts\Provisioning\CopyScriptsLocally\CopyScriptsLocally.ps1"
powershell -File "D:\Scripts\Provisioning\CopyScriptsLocally\CopyScriptsLocally.ps1" -ComputerName $targetComputer > $null
LogWrite " [ Copying Files ] Complete"
Write-Host " ...Complete" -Fore Green;start-Sleep -Seconds 0 
}
Function CopyUtilFolder {
$foldersize = Get-Size D:\Scripts\utils
Write-Host "`nPreparing to copy the Util Folder" -Fore Yellow -Nonewline;start-Sleep -Seconds 0
write-host "`nAmount of data to be moved: " -Fore Yellow -nonewline; Write-host "$foldersize" -Fore White;start-Sleep -Seconds 0
Write-Host "Copying Files" -Fore Yellow -Nonewline;start-Sleep -Seconds 0 
LogWrite "Calling D:\Scripts\Provisioning\CopyScriptsLocally\CopyScriptsUtil.ps1"
powershell -File "D:\Scripts\Provisioning\CopyScriptsLocally\CopyScriptsUtil.ps1" -ComputerName $targetComputer > $null
LogWrite "[ Copying Util Folder ] Complete"
Write-Host " ...Complete" -Fore Green;start-Sleep -Seconds 0
}
Function TuneDrives {
Write-Host "`n*----  Expanding Drives if applicable (Server 2012 only)  ----*`n" -Fore Magenta;start-Sleep -Seconds 0 
LogWrite = "Calling C:\Scripts\Provisioning\12_RolesFeatures\RolesAndFeatures.ps1"
powershell -File "D:\Scripts\Provisioning\RemoteFunctions\rCmd+.ps1" -UseAdmin -UseHTTP -ComputerName $targetComputer -ScriptBlock "C:\Scripts\Provisioning\Partitions\expand_drives.ps1 "
LogWrite "Roles and Features Complete"
}
Function BaseScripts {
# Rerunning base scripts since Vmware Customization Specs wipe out some basic settings
Write-Host "`n*----  Running Base Settings on [ $targetComputer ] ----*`n" -Fore Magenta;start-Sleep -Seconds 0 
LogWrite "Calling D:\Scripts\Provisioning\basic.ps1"
powershell -File "D:\Scripts\Provisioning\RemoteFunctions\rCmd+.ps1" -UseAdmin -UseHTTP -ComputerName $targetComputer -ScriptBlock "C:\Scripts\Provisioning\basic.ps1" 
LogWrite "[ Running Basics ] Complete"
}
Function InitializingRolesandFeatures {
# Initializing Roles and Features
Write-Host "`n*----  Installation of Roles and Features  ----*`n" -Fore Magenta;start-Sleep -Seconds 0 
LogWrite = "Calling C:\Scripts\Provisioning\12_RolesFeatures\RolesAndFeatures.ps1"
powershell -File "D:\Scripts\Provisioning\RemoteFunctions\rCmd+.ps1" -UseAdmin -UseHTTP -ComputerName $targetComputer -ScriptBlock "C:\Scripts\Provisioning\12_RolesFeatures\RolesAndFeatures.ps1 -ServerType $servertype" 
LogWrite "Roles and Features Complete"
}
Function SettingPageFileDrivePermissionsbasesql {
	Write-Host "`n*----  Setting PageFile & Basic Drive Permissions  ----*`n" -Fore Magenta;start-Sleep -Seconds 0 
	LogWrite "Calling C:\Scripts\Provisioning\1_W2k8_PostTemplate\Master_Powershell_Base.ps1"
	powershell -File "D:\Scripts\Provisioning\RemoteFunctions\rCmd+.ps1" -UseAdmin -UseHTTP -ComputerName $targetComputer -ScriptBlock "C:\Scripts\Provisioning\1_W2k8_PostTemplate\Master_Powershell_Base.ps1"  
	LogWrite "[ Setting PageFile & Basic Drive Permissions ] Complete"
    Write-Host " ...Complete" -Fore Green;start-Sleep -Seconds 0 
}
Function SettingPageFileDrivePermissionsweb {
	Write-Host "`n*----  Installing IIS since the Web role was selected  ----*`n" -Fore Magenta;start-Sleep -Seconds 0 
    LogWrite "Calling C:\Scripts\Provisioning\1_W2k8_PostTemplate\Master_Powershell_IIS.ps1"
    powershell -File "D:\Scripts\Provisioning\RemoteFunctions\rCmd+.ps1" -UseAdmin -UseHTTP -ComputerName $targetComputer -ScriptBlock "C:\Scripts\Provisioning\1_W2k8_PostTemplate\Master_Powershell_IIS.ps1" 
    LogWrite "[ IIS Full installation ] Complete"
    Write-Host "`n...IIS Role installed" -Fore Green;start-Sleep -Seconds 0 
}
Function ConfiguringNic {
# Configuring Nic(s)
Write-Host "`n*----  Configuring Networking on [ $targetComputer ]  ----*`n" -Fore Magenta;start-Sleep -Seconds 0 
LogWrite "Calling D:\Scripts\Provisioning\2_NetworkConfig\NicConfig.ps1"
powershell -File "D:\Scripts\Provisioning\RemoteFunctions\rScript+.ps1" -UseAdmin -UseHTTP -ComputerName $targetComputer -FilePath D:\Scripts\Provisioning\2_NetworkConfig\NicConfig.ps1 -ArgumentList $PrivateIP 
LogWrite "[ Configuring Networking ] Complete"
}
Function JoiningDomain {
# Joining Domain
Write-Host "`n*----  Joining the [ $Domain ] Domain  ----*`n" -Fore Magenta;start-Sleep -Seconds 0 
LogWrite "Calling C:\Scripts\Provisioning\4_JoinDomain\JoinDomain.ps1"
powershell -File "D:\Scripts\Provisioning\RemoteFunctions\rCmd+.ps1" -UseAdmin -UseHTTP -ComputerName $targetComputer -ScriptBlock "C:\Scripts\Provisioning\4_JoinDomain\JoinDomain.ps1 -Domain $Domain -OU $OU" 
LogWrite "[ Joining %Domain Domain ] Complete"
}
Function RebootComputerOld {
Write-Host "`n*----  Rebooting [ $targetComputer ]  ----*`n" -Fore Magenta;start-Sleep -Seconds 0 
LogWrite "Restarting Remote Server"
powershell -File "D:\Scripts\Provisioning\RemoteFunctions\rCmd+.ps1" -UseAdmin -UseHTTP -ComputerName $targetComputer -ScriptBlock 'Restart-Computer -Confirm:$False -Force' 
Write-Host "`nRebooting Server" -Fore Yellow -nonewline;start-Sleep -Seconds 0
Do {Start-Sleep -s 30}
Until (test-connection $targetComputer -quiet)
Write-Host " ...Complete" -Fore Green;start-Sleep -Seconds 0
LogWrite "Restart Complete"
}
Function InstallBaseSQLconfig {
Write-Host "`n*----  Installation Sql Base Config  ----*`n" -Fore Magenta;start-Sleep -Seconds 0 
LogWrite = "Calling C:\Scripts\Provisioning\SQL\Base_Sql_Config.ps1"
powershell -File "D:\Scripts\Provisioning\RemoteFunctions\rCmd+.ps1" -UseAdmin -UseHTTP -ComputerName $targetComputer -ScriptBlock "C:\Scripts\Provisioning\SQL\Base_Sql_Config.ps1" 
LogWrite "Base Sql Config Complete"
}
Function AddingServerOpsSecurity {
# Adding Server Ops Security
Write-Host "`n*----  Adding Server_Ops Security to [ $targetComputer ] ----*`n" -Fore Magenta;start-Sleep -Seconds 0 
LogWrite "Calling D:\Scripts\Provisioning\5_AddServerOps\AddServerOps.ps1"
powershell -File "D:\Scripts\Provisioning\RemoteFunctions\rScript+.ps1" -UseAdmin -UseHTTP -ComputerName $targetComputer -FilePath D:\Scripts\Provisioning\5_AddServerOps\AddServerOps.ps1 
LogWrite "[ Adding Server_Ops Security ] Complete"
}
Function UpdatingWindows {
# Updating Windows
Write-Host "`n*----  Performing Windows Updates on [ $targetComputer ] ----*`n" -Fore Magenta;start-Sleep -Seconds 0 
LogWrite "Calling C:\Scripts\Provisioning\WinUpdates\launch.ps1"
powershell -File "D:\Scripts\Provisioning\RemoteFunctions\rCmd+.ps1" -UseAdmin -UseHTTP -ComputerName $targetComputer -ScriptBlock "C:\Scripts\Provisioning\WinUpdates\launch.ps1" 
LogWrite "[ Windows Update ] Complete"
}
Function RebootComputerNew {
# Reboot Computer
Write-Host "`n*----  Rebooting [ $targetComputer ]  ----*`n" -Fore Magenta;start-Sleep -Seconds 0 
LogWrite "Restarting Remote Server"
Write-Host "`nRebooting Server" -Fore Yellow -nonewline;start-Sleep -Seconds 0
Restart-Computer -Computername $targetComputer -Wait -For Wmi
Write-Host " ...Complete" -Fore Green;start-Sleep -Seconds 0
LogWrite "Restart Complete"
}
Function WincollectInstallation {
Write-Host "`n*----  Installing Wincollect on [ $targetComputer ]  ----*`n" -Fore Magenta;start-Sleep -Seconds 0 
LogWrite "Calling C:\Scripts\Provisioning\WinCollect\InstallWincollect.ps1"
powershell -File "D:\Scripts\Provisioning\RemoteFunctions\rCmd+.ps1" -UseAdmin -UseHTTP -ComputerName $targetComputer -ScriptBlock "C:\Scripts\Provisioning\WinCollect\InstallWincollect.ps1"
LogWrite "[ Installing Wincollect ] Complete"
}
Function CertificationRequestandImport {
# Certification Request and Import
Write-Host "`n*----  Requesting and Importing Certs for [ $targetComputer ]  ----*`n" -Fore Magenta;start-Sleep -Seconds 0 
Logwrite "Calling D:\Scripts\Provisioning\6_CertRequest\ServerCertRequest.ps1"
powershell -File "D:\Scripts\Provisioning\6_CertRequest\ServerCertRequest.ps1" -ComputerName $targetComputer 
LogWrite "[ Requesting Cert & Importing ] Complete"
Write-Host "...Cert Work Complete" -Fore Green;start-Sleep -Seconds 0 
}
Function EnablingPowershelloverHTTPS {
# Enabling Powershell over HTTPS
Write-Host "`n*----  Enabling Powershell over HTTPS on [ $targetComputer ]  ----*`n" -Fore Magenta;start-Sleep -Seconds 0 
LogWrite "Calling C:\Scripts\Provisioning\7_WinRMHTTPS\ScheduleENABLE.ps1"
powershell -File "D:\Scripts\Provisioning\RemoteFunctions\rCmd+.ps1" -UseAdmin -UseHTTP -ComputerName $targetComputer -ScriptBlock "C:\Scripts\Provisioning\7_WinRMHTTPS\ScheduleENABLE.ps1" 
LogWrite "[ Enable Powershell Remoting over HTTPS ] Complete"
}
Function DisablingPowershellRemotingoverHTTP {
# Disabling Powershell Remoting over HTTP
Write-Host "`n*----  Disabling Powershell Remoting over HTTP on [ $targetComputer ]  ----*`n" -Fore Magenta;start-Sleep -Seconds 0 
LogWrite "Calling C:\Scripts\Provisioning\7_WinRMHTTPS\ScheduleDISABLE.ps1"
powershell -File "D:\Scripts\Provisioning\RemoteFunctions\rCmd+.ps1" -UseRunBook -ComputerName $targetComputer -ScriptBlock "C:\Scripts\Provisioning\7_WinRMHTTPS\ScheduleDISABLE.ps1" 
LogWrite "[ Disabling Powershell Remoting over HTTP ] Complete"
}
Function PerformingFTPprocedures {
Write-Host "`n*----  Performing FTPIP Procedures on [ $targetComputer ]  ----*`n" -Fore Magenta;start-Sleep -Seconds 0 
LogWrite "Calling D:\Scripts\Provisioning\9_BaseFTPSite\BaseFTPSite.ps1"
powershell -File "D:\Scripts\Provisioning\RemoteFunctions\rScript+.ps1" -UseRunBook -ComputerName $targetComputer -FilePath D:\Scripts\Provisioning\9_BaseFTPSite\BaseFTPSite.ps1 -ArgumentList $ftpIP 
LogWrite "[ If FTP add FTPIP procedure ] Complete"
Write-Host "`n...FTPIP Procedure complete" -Fore Green;start-Sleep -Seconds 0 
}
Function SqlCertPermission {
Write-Host "`n*----  Applying SQL Cert Permission settings on [ $targetComputer ]  ----*`n" -Fore Magenta;start-Sleep -Seconds 0 
LogWrite "Calling C:\Scripts\Provisioning\1_W2k8_PostTemplate\LocalAccount_PS_config.ps1"
powershell -File "D:\Scripts\Provisioning\RemoteFunctions\rCmd+.ps1" -UseRunBook -ComputerName $targetComputer -ScriptBlock "C:\Scripts\Provisioning\SQL\Grant-CertificateAccess.ps1 " 
LogWrite "[ Renaming Admin & Guest accounts ] Complete"
}
Function RenamingAdminandGuestAccounts {
# Renaming Admin and Guest Accounts
Write-Host "`n*----  Renaming Admin & Guest Accounts on [ $targetComputer ]  ----*`n" -Fore Magenta;start-Sleep -Seconds 0 
LogWrite "Calling C:\Scripts\Provisioning\1_W2k8_PostTemplate\LocalAccount_PS_config.ps1"
powershell -File "D:\Scripts\Provisioning\RemoteFunctions\rCmd+.ps1" -UseRunBook -ComputerName $targetComputer -ScriptBlock "C:\Scripts\Provisioning\1_W2k8_PostTemplate\LocalAccount_PS_config.ps1" 
LogWrite "[ Renaming Admin & Guest accounts ] Complete"
}
Function CompletionMessage {
write-host "`n`t           ___________________________________________________________________________________" -fore green;start-Sleep -Seconds 0 
write-host "`t  ________|                                                                                   |_______" -fore green;start-Sleep -Seconds 0 
write-host "`t  \       |                    Server Installation & Provisioning is complete                 |      /" -fore green;start-Sleep -Seconds 0
write-host "`t   \      |                                                                                   |     /" -fore green;start-Sleep -Seconds 0
write-host "`t    \     |                                                                                   |    /" -fore green;start-Sleep -Seconds 0
write-host "`t    /     |     Install log for this install can be found at C:\Scripts\Logs\installlogs\     |    \" -fore green;start-Sleep -Seconds 0
write-host "`t   /      |___________________________________________________________________________________|     \" -fore green;start-Sleep -Seconds 0
write-host "`t  /__________)                                                                             (_________\" -fore green;start-Sleep -Seconds 0
write-host ""
}