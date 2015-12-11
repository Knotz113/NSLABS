param (
   [string]$computerName
)

Function PsexecRemoteCommandSendDomainAccount {
$commandBytes = [System.Text.Encoding]::Unicode.GetBytes($expression)
$encodedCommand = [Convert]::ToBase64String($commandBytes)
.\PsExec.exe \\$computername -u $username -p $password cmd /c “echo . | powershell -EncodedCommand $encodedCommand” >> .\Output\stdout.txt 2>> .\Output\stderr.txt
}
Function PsexecRemoteCommandSend {
$commandBytes = [System.Text.Encoding]::Unicode.GetBytes($expression)
$encodedCommand = [Convert]::ToBase64String($commandBytes)
.\PsExec.exe \\$computerName -u $computerName\$username -p $password cmd /c “echo . | powershell -EncodedCommand $encodedCommand” >> .\Output\variablepass.txt 2>> .\Output\ConsoleOutputDump.txt
}
Function Robo {
Robocopy.exe D:\Scripts\Provisioning \\$computerName\c$\Scripts\Provisioning *.* /E 
}
Function DefineOS {
If ($results -like "*2003*"){
$script:OS = "2003"
Add-Content D:\Scripts\Output\OS_Check.csv "$computerName,2003"
}
ElseIf ($results -like "*2008*"){
$script:OS = "2008"
Add-Content D:\Scripts\Output\OS_Check.csv "$computerName,2008"
}
ElseIf ($results -like "*2012*"){
$script:OS = "2012"
Add-Content D:\Scripts\Output\OS_Check.csv "$computerName,2012"
}
}
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
#Clear
$hostname = ($env:computername)
Write-host "`n---------------------------------------" -fore red
Write-host "Psexec Command Execution" -fore red
Write-host "---------------------------------------`n" -fore red

if ($computerName){
}
Else {
$computername = read-host "What is the server to be probed"
}

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
Write-host "`n`nPSexec Command Execution for $computername" -fore Cyan
$expression = '(Get-WmiObject Win32_OperatingSystem).caption'
PsexecRemoteCommandSend
$results = (Get-Content .\Output\variablepass.txt)
write-host "Results: " -nonewline
write-host "$results" -fore gray 
DefineOS
write-host "Removing local variable file" -fore yellow -nonewline
Remove-Item D:\Scripts\Provisioning\psexec\Output\variablepass.txt
write-host " ...Complete" -fore green

} 
Else {
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
Write-host "`n`nPSexec Command Execution for $computername" -fore Cyan
$expression = '(Get-WmiObject Win32_OperatingSystem).caption'
PsexecRemoteCommandSend
$results = (Get-Content .\Output\variablepass.txt)
write-host "Results: " -nonewline
write-host "$results" -fore gray 
DefineOS
write-host "Removing local variable file" -fore yellow -nonewline
Remove-Item D:\Scripts\Provisioning\psexec\Output\variablepass.txt
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
Write-host "`n`nPSexec Command Execution for $computername" -fore Cyan
$expression = '(Get-WmiObject Win32_OperatingSystem).caption'
$commandBytes = [System.Text.Encoding]::Unicode.GetBytes($expression)
$encodedCommand = [Convert]::ToBase64String($commandBytes)
.\PsExec.exe \\$computername -u $username -p $password cmd /c “echo . | powershell -EncodedCommand $encodedCommand” >> .\Output\variablepass.txt 2>> .\Output\ConsoleOutputDump.txt
$results = (Get-Content .\Output\variablepass.txt)
write-host "Results: " -nonewline
write-host "$results" -fore gray 
DefineOS

write-host "Removing local variable file" -fore yellow -nonewline
Remove-Item D:\Scripts\Provisioning\psexec\Output\variablepass.txt
write-host " ...Complete" -fore green

}
Else {
write-host " ...Fail" -fore Red
}
} Else {}