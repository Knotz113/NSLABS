Param(
    [Parameter(Mandatory = $false)]
    [String]$computerName
)

Function SetSNCreds {
If (($hostname -eq "fenappmgp20") -or ($hostname -eq "fenappmgp03")){
$script:username = "us\S_ServiceNowRB_US"
$script:password = ""
}
ElseIf ($hostname -eq "fenappmgp05"){
$script:username = "MNETI\S_ServiceNowRB_MNETI"
$script:password = ""
}
ElseIf ($hostname -eq "fenappmgp09"){
$script:username = "MPNI\S_ServiceNowRB_MPNI"
$script:password = ""
}
ElseIf ($hostname -eq "fenappmgp04"){
$script:username = "MPNE\S_ServiceNowRB_MPNE"
$script:password = ""
}
ElseIf ($hostname -eq "fenappmgp08"){
$script:username = "MPN\S_ServiceNowRB_MPN"
$script:password = ""
}
ElseIf ($hostname -eq "fenappmgp06"){
$script:username = "MNETE\S_ServiceNowRB_MNETe"
$script:password = ""
}
}
Function PsexecRemoteCommandSend {
$commandBytes = [System.Text.Encoding]::Unicode.GetBytes($expression)
$encodedCommand = [Convert]::ToBase64String($commandBytes)
.\PsExec.exe \\$computerName -u $computerName\$username -p $password cmd /c “echo . | powershell -EncodedCommand $encodedCommand” #>> .\Output\stdout.txt 2>> .\Output\stderr.txt
}
Function PsexecRemoteCommandSendDomainAccount {
$commandBytes = [System.Text.Encoding]::Unicode.GetBytes($expression)
$encodedCommand = [Convert]::ToBase64String($commandBytes)
.\PsExec.exe \\$computername -u $username -p $password cmd /c “echo . | powershell -EncodedCommand $encodedCommand” >> .\Output\stdout.txt 2>> .\Output\stderr.txt
}
Function WriteToLog {
Param (
    [Parameter(Mandatory = $false)]
    [String]$Entry
)
If (!(Test-path D:\Scripts\Output)){
New-Item c:\Scripts\Output -type directory
}
Else {}
Write-output "$Entry" | out-file "D:\Scripts\Output\PowershellUpgradeLog.txt" -append
}
Function BlatanhaCheck {
$global:username = "blatanha"
$global:password = ""
write-host "Cred check for [ $username ] against [ $computerName ]" -fore yellow -nonewline
$expression = “winrm enumerate winrm/config/listener”
PsexecRemoteCommandSend >> .\Output\stdout.txt 2>> .\Output\stderr.txt
}
Function EstablishSession {
if(Test-Path "$scriptPath\..\RemoteFunctions\New-RemoteSession\New-RemoteSession.ps1") {
    $global:Session = Invoke-Expression "$scriptPath\..\RemoteFunctions\New-RemoteSession\New-RemoteSession.ps1 -ComputerName $computername -UseRunBook -maxwait 240 2>&1"
    if ($Session){
	WriteToLog -Entry "Session Established"
    } 
	else {
	}
}
else {
}
}
Function CopyFiles {
write-host "Copying Files to $computerName" -fore yellow -nonewline
Try {
Robocopy.exe D:\Scripts\PowershellVersionUpgrade \\$computername\c$\Scripts\PSVersionUpgrade *.* /E >$null
}
Catch {
write-host " ...Error" -fore red
WriteToLog -Entry "Robocopy Error $LastExitCode"
}
write-host " ...Complete [ $LastExitCode ]" -fore green
WriteToLog -Entry "Robocopy Complete"
}

# Identify parent directory for the script
$scriptPath = split-path -parent $MyInvocation.MyCommand.Definition
if(!$scriptPath) {
$scriptPath = split-path -parent $psISE.CurrentFile.FullPath
}


Write-host "`n---------------------------------------" -fore red
Write-host "PsVersion Fix" -fore red
Write-host "---------------------------------------`n" -fore red
If (!($computername)){
$computername = read-host "What is the server to be probed"
}
Else {}

$time = Get-Date
WriteToLog -Entry "[$computername]"
WriteToLog -Entry "Powershell Script Started $time"

Write-host "`n[ $computerName ]" -fore cyan
BlatanhaCheck
if ($LastExitCode -ne "0") {
write-host " ...Fail" -fore Red
WriteToLog -Entry "Failed Blatanha cred check"
} Else {
write-host " ...Pass" -fore green
WriteToLog -Entry "Passed Psexec Check"
$continue = 1
}

#Write-host "Port Check" -fore yellow -nonewline
#If ($continue){
#$port = 5986 
#$ErrorActionPreference = 'SilentlyContinue'
#If (New-Object System.Net.Sockets.TCPClient -ArgumentList $ServerIP,$port) { 
#write-host " ...Port Open`n" -foreground green
#$ErrorActionPreference = 'Continue'
#$portcheckopen = 1
#}
#} Else { write-host " ...Port Not Open`n" -fore red }

If ($continue){

#############################################################################
EstablishSession
#############################################################################
$TESTPS = Invoke-Command -Session $Session -ScriptBlock {
function Test-PS {
Write-host "`nPowershell" -fore yellow -nonewline
if ($PSVersionTable.PSVersion.Major -lt 4){
return $true
}
Else {
return $false
}
}
Test-PS
}
If ($TESTPS -eq "true"){
write-host " ...Out of Date" -fore red
WriteToLog -Entry "Powershell is out of date"

#############################################################################
$osbit = Invoke-Command -Session $Session -ScriptBlock {
function Test-OSVersion {
if ([System.IntPtr]::Size -eq 4) {
$osbit = "32"
return $osbit 
} 
else {
$osbit = "64"
return $osbit 
}
}
Test-OSVersion
}
WriteToLog -Entry "OS bit set to $osbit"
#############################################################################
CopyFiles
#############################################################################
Write-host "DotNet Framework" -fore yellow -nonewline
$Net45 = Invoke-Command -Session $Session -ScriptBlock {
function Test-Net45 {
if (Test-Path 'HKLM:\SOFTWARE\Microsoft\NET Framework Setup\NDP\v4\Full') {
if (Get-ItemProperty 'HKLM:\SOFTWARE\Microsoft\NET Framework Setup\NDP\v4\Full' -Name Release -ErrorAction SilentlyContinue){
return $true
}
return $false
}
}
Test-Net45
}
If($Net45 -eq "true"){
write-host " ...Up to Date" -fore green
WriteToLog -Entry "DotNet is up to date"
}
Else {
write-host " ...Out of Date" -fore red
WriteToLog -Entry "DotNot is out of date"
Write-host "Installing [ NDP452-KB2901907-x86-x64-AllOS-ENU.exe ]" -fore yellow -nonewline
.\PsExec.exe \\$computerName -u $computerName\$username -p $password 'C:\Scripts\PSVersionUpgrade\NDP452-KB2901907-x86-x64-AllOS-ENU.exe' /q /norestart  >> .\Output\stdout.txt 2>> .\Output\stderr.txt
if ($LastExitCode -eq "0") {
write-host " ...Complete [ $LastExitCode ]" -fore green
WriteToLog -Entry "DotNet Completed with LastExitCode of [ $LastExitCode ]"
}
Else {
write-host " ...Failed [ $LastExitCode ]" -fore red
WriteToLog -Entry "DotNet Failed with LastExitCode of [ $LastExitCode ]"
}
}
#############################################################################

#############################################################################
$rebootneeded = Invoke-Command -Session $Session -ScriptBlock {
function RebootCheck {
if (test-path 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\WindowsUpdate\Auto Update\RebootRequired') {
$result = "yes"
return $result
}
Else {
$result = "no"
return $result
}
}
RebootCheck
}
if ($rebootneeded -eq "no"){
if ($osbit = "64"){
Write-host "Installing [ Windows6.1-KB2819745-x64-MultiPkg.msu ]" -fore yellow -nonewline
.\PsExec.exe \\$computerName -u $computerName\$username -p $password wusa.exe 'C:\Scripts\PSVersionUpgrade\Windows6.1-KB2819745-x64-MultiPkg.msu' /quiet /norestart >> .\Output\stdout.txt 2>> .\Output\stderr.txt
if ($LastExitCode -eq "1641") {
write-host " ...Complete [ $LastExitCode ]" -fore green
WriteToLog -Entry "Powershell 4 install completed with LastExitCode of [ $LastExitCode ]"
}
Elseif ($LastExitCode -eq "3010"){
Write-host " ...Complete [ $LastExitCode - Reboot Required]" -fore green
WriteToLog -Entry "Powershell 4 install completed with LastExitCode of [ $LastExitCode ]"
}
Else {
Write-host " ...Failed [ Error Code $LastExitCode ]" -fore red
WriteToLog -Entry "Powershell 4 install failed with LastExitCode of [ $LastExitCode ]"
}
}
Else {
Write-host "Installing [ Windows6.1-KB2819745-x86-MultiPkg.msu ]" -fore yellow -nonewline
.\PsExec.exe \\$computerName -u $computerName\$username -p $password wusa.exe 'C:\Scripts\PSVersionUpgrade\Windows6.1-KB2819745-x86-MultiPkg.msu' /quiet /norestart >> .\Output\stdout.txt 2>> .\Output\stderr.txt
if ($LastExitCode -eq "1641") {
write-host " ...Complete [ $LastExitCode ]" -fore green
WriteToLog -Entry "Powershell 4 install completed with LastExitCode of [ $LastExitCode ]"
}
Elseif ($LastExitCode -eq "3010"){
Write-host " ...Complete [ But reboot is required - $LastExitCode ]" -fore green
WriteToLog -Entry "Powershell 4 install completed with LastExitCode of [ $LastExitCode ]"
}
Else {
Write-host " ...Failed [ Error Code $LastExitCode ]" -fore red
WriteToLog -Entry "Powershell 4 install failed with LastExitCode of [ $LastExitCode ]"
}
}
}
Else {
Write-Host "Reboot $computername and try this again!" -fore red
WriteToLog -Entry " $computername needs to be reboot to reflect Powershell changes"
}
#############################################################################

}
Else {
write-host " ...Up to Date" -fore green
WriteToLog -Entry "Powershell is up to date"
}

$skip = "yes"
}

# Remove the remote session
if ($session){
Remove-PSSession $Session
}
Else {}

$time = Get-Date
WriteToLog -Entry "Powershell Script Stopped $time"
WriteToLog -Entry ""
write-host ""