param (
   [string]$computerName
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
Function PsexecRemoteCommandSendDomainAccount {
write-host "Sending [ $expression ] to $computerName" -fore yellow -nonewline
$commandBytes = [System.Text.Encoding]::Unicode.GetBytes($expression)
$encodedCommand = [Convert]::ToBase64String($commandBytes)
.\PsExec.exe \\$computername -u $username -p $password cmd /c “echo . | powershell -EncodedCommand $encodedCommand” >> .\Output\stdout.txt 2>> .\Output\stderr.txt
write-host " ...Complete" -fore green
}
Function PsexecRemoteCommandSend {
write-host "Sending [ $expression ] to $computerName" -fore yellow -nonewline
$commandBytes = [System.Text.Encoding]::Unicode.GetBytes($expression)
$encodedCommand = [Convert]::ToBase64String($commandBytes)
.\PsExec.exe \\$computerName -u $computerName\$username -p $password cmd /c “echo . | powershell -EncodedCommand $encodedCommand” >> .\Output\PsexecCommandOutput.txt 2>> .\Output\ConsoleOutputDump.txt
write-host " ...Complete" -fore green
}
Function AdminShareTest {
write-host "Testing Admin share on $computerName" -fore yellow -nonewline
if (test-path \\$computerName\c$){
write-host " ...Pass" -fore green
}
Else {
write-host " ...Fail" -fore red
}
}
#Clear
$hostname = ($env:computername)
Write-host "`n---------------------------------------" -fore red
Write-host "Psexec Command Execution" -fore red
Write-host "---------------------------------------" -fore red

if (!$computerName){
$computername = read-host "What is the server to be probed"
} Else {}

Write-host "`n[ $computerName ]" -fore cyan
$username = "blatanha"
$password = ""
write-host "Cred check for [ $username ] against [ $computerName ]" -fore yellow -nonewline
$expression = “winrm enumerate winrm/config/listener”
$commandBytes = [System.Text.Encoding]::Unicode.GetBytes($expression)
$encodedCommand = [Convert]::ToBase64String($commandBytes)
.\PsExec.exe \\$computerName -u $computerName\$username -p $password cmd /c “echo . | powershell -EncodedCommand $encodedCommand” >> .\Output\PsexecCommandOutput.txt 2>> .\Output\ConsoleOutputDump.txt
if ($LastExitCode -eq "0") {
write-host " ...Pass" -fore green
$skip = "yes"


set-location D:\Scripts\Provisioning\psexec
Write-host "`nPSexec Command Execution for $computername" -fore Cyan
$username = "blatanha"
$password = ""

AdminShareTest

write-host "Copying Files to $computerName" -fore yellow -nonewline
Robocopy.exe D:\Scripts\Provisioning \\$computerName\c$\Scripts\Provisioning *.* /E >$null
write-host " ...Complete" -fore green

$expression = “Set-ExecutionPolicy Unrestricted -force”
PsexecRemoteCommandSend

$expression = “C:\Scripts\Provisioning\psexec\SendFiles\HTTPS_Listener_Check.ps1”
PsexecRemoteCommandSend
start-sleep -s 5

write-host "Copying from $computerName" -fore yellow -nonewline
robocopy \\$computerName\c$\Scripts\Provisioning\psexec\SendFiles D:\Scripts\Provisioning\psexec\SendFiles variable.txt >$null
write-host " ...Complete" -fore green

#if ($results){
#remove-variable results
#} Else {}

$global:results = (Get-Content .\SendFiles\variable.txt)
write-output "$results" | out-file D:\Scripts\Provisioning\psexec\Output\HTTPS_Check_Results.txt -append
write-host "Results: " -nonewline
write-host "$results" -fore gray 

$expression = “Remove-Item C:\Scripts\Provisioning\psexec -recurse”
PsexecRemoteCommandSend

write-host "Removing local variable file" -fore yellow -nonewline
Remove-Item D:\Scripts\Provisioning\psexec\SendFiles\variable.txt
write-host " ...Complete" -fore green


} Else {
write-host " ...Fail" -fore Red
}




if (!$skip){
$username = "Inoc"
$password = ""
write-host "Cred check for [ $username ] against [ $computerName ]" -fore yellow -nonewline
$expression = “winrm enumerate winrm/config/listener”
$commandBytes = [System.Text.Encoding]::Unicode.GetBytes($expression)
$encodedCommand = [Convert]::ToBase64String($commandBytes)
.\PsExec.exe \\$computerName -u $computerName\$username -p $password cmd /c “echo . | powershell -EncodedCommand $encodedCommand” >> .\Output\PsexecCommandOutput.txt 2>> .\Output\ConsoleOutputDump.txt
if ($LastExitCode -eq "0") {
write-host " ...Pass" -fore green
$skip = "yes"

set-location D:\Scripts\Provisioning\psexec
Write-host "`nPSexec Command Execution for $computername" -fore Cyan
$username = "Inoc"
$password = ""

AdminShareTest

write-host "Copying Files to $computerName" -fore yellow -nonewline
Robocopy.exe D:\Scripts\Provisioning \\$computerName\c$\Scripts\Provisioning *.* /E >$null
write-host " ...Complete" -fore green

$expression = “Set-ExecutionPolicy Unrestricted -force”
PsexecRemoteCommandSend

$expression = “C:\Scripts\Provisioning\psexec\SendFiles\HTTPS_Listener_Check.ps1”
PsexecRemoteCommandSend
start-sleep -s 5

write-host "Copying from $computerName" -fore yellow -nonewline
robocopy \\$computerName\c$\Scripts\Provisioning\psexec\SendFiles D:\Scripts\Provisioning\psexec\SendFiles variable.txt >$null
write-host " ...Complete" -fore green

#if ($results){
#remove-variable results
#} Else {}

$global:results = (Get-Content .\SendFiles\variable.txt)
write-output "$results" | out-file D:\Scripts\Provisioning\psexec\Output\HTTPS_Check_Results.txt -append
write-host "Results: " -nonewline
write-host "$results" -fore gray 

$expression = “Remove-Item C:\Scripts\Provisioning\psexec -recurse”
PsexecRemoteCommandSend

write-host "Removing local variable file" -fore yellow -nonewline
Remove-Item D:\Scripts\Provisioning\psexec\SendFiles\variable.txt
write-host " ...Complete" -fore green

}
Else {
write-host " ...Fail" -fore Red
}
} Else {}


if (!$skip){
SetSNCreds
write-host "Cred check for [ $username ] against [ $computerName ]" -fore yellow -nonewline
$expression = “winrm enumerate winrm/config/listener”
$commandBytes = [System.Text.Encoding]::Unicode.GetBytes($expression)
$encodedCommand = [Convert]::ToBase64String($commandBytes)
.\PsExec.exe \\$computername -u $username -p $password cmd /c “echo . | powershell -EncodedCommand $encodedCommand” >> .\Output\stdout.txt 2>> .\Output\stderr.txt
if ($LastExitCode -eq "0") {
write-host " ...Pass" -fore green
$skip = "yes"

set-location D:\Scripts\Provisioning\psexec
Write-host "`nPSexec Command Execution for $computername" -fore Cyan

AdminShareTest

write-host "Copying Files to $computerName" -fore yellow -nonewline
Robocopy.exe D:\Scripts\Provisioning \\$computerName\c$\Scripts\Provisioning *.* /E >$null
write-host " ...Complete" -fore green

$expression = “Set-ExecutionPolicy Unrestricted -force”
PsexecRemoteCommandSendDomainAccount

$expression = “C:\Scripts\Provisioning\psexec\SendFiles\HTTPS_Listener_Check.ps1”
PsexecRemoteCommandSendDomainAccount
start-sleep -s 5

write-host "Copying from $computerName" -fore yellow -nonewline
robocopy \\$computerName\c$\Scripts\Provisioning\psexec\SendFiles D:\Scripts\Provisioning\psexec\SendFiles variable.txt >$null
write-host " ...Complete" -fore green

#if ($results){
#remove-variable results
#} Else {}

$global:results = (Get-Content .\SendFiles\variable.txt)
write-output "$results" | out-file D:\Scripts\Provisioning\psexec\Output\HTTPS_Check_Results.txt -append
write-host "Results: " -nonewline
write-host "$results" -fore gray 

$expression = “Remove-Item C:\Scripts\Provisioning\psexec -recurse”
PsexecRemoteCommandSendDomainAccount

write-host "Removing local variable file" -fore yellow -nonewline
Remove-Item D:\Scripts\Provisioning\psexec\SendFiles\variable.txt
write-host " ...Complete" -fore green

}
Else {
write-host " ...Fail" -fore Red
}
} Else {}

