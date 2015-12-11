param (
   [string]$computerName
)

Function SetSNCreds {
If (($hostname -eq "fenappmgp20") -or ($hostname -eq "fenappmgp03")){
$script:username = "us\S_ServiceNowRB_US"
$script:password = "S3rv1c3N0wU$"
}
ElseIf ($hostname -eq "fenappmgp05"){
$script:username = "MNETI\S_ServiceNowRB_MNETI"
$script:password = "S3rv1c3N0wMN3+1"
}
ElseIf ($hostname -eq "fenappmgp09"){
$script:username = "MPNI\S_ServiceNowRB_MPNI"
$script:password = "S3rv1c3N0wM%N1"
}
ElseIf ($hostname -eq "fenappmgp04"){
$script:username = "MPNE\S_ServiceNowRB_MPNE"
$script:password = "S3rv1c3N0wM%N3"
}
ElseIf ($hostname -eq "fenappmgp08"){
$script:username = "MPN\S_ServiceNowRB_MPN"
$script:password = "S3rv1c3N0wM%N"
}
ElseIf ($hostname -eq "fenappmgp06"){
$script:username = "MNETE\S_ServiceNowRB_MNETe"
$script:password = "S3rv1c3N0wMN3+3"
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
.\PsExec.exe \\$computerName -u $computerName\$username -p $password cmd /c “echo . | powershell -EncodedCommand $encodedCommand” 
.\PsExec.exe \\$computerName -u $computerName\$username -p $password cmd /c “echo . | powershell -EncodedCommand $encodedCommand” >> .\Output\variablepass.txt 2>> .\Output\ConsoleOutputDump.txt
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
Clear
$hostname = ($env:computername)
Write-host "`n---------------------------------------" -fore red
Write-host "Psexec Command Execution" -fore red
Write-host "---------------------------------------" -fore red

if (!$computerName){
$computername = read-host "What is the server to be probed"
} Else {}

set-location D:\Scripts\Provisioning\psexec
Write-host "`nPSexec Command Execution for $computername" -fore Cyan
$username = "blatanha"
$password = "Bl@ck*Y@k!"

$expression = 'netstat -an | where{$_.Contains("5985")}'
PsexecRemoteCommandSend

$expression = 'netstat -an | where{$_.Contains("5986")}'
PsexecRemoteCommandSend
pause

$results = (Get-Content .\Output\variablepass.txt)
#write-output "$results" | out-file D:\Scripts\Provisioning\psexec\Output\HTTPS_Check_Results.txt -append
write-host "Results: " -nonewline
write-host "$results" -fore gray 


write-host "Removing local variable file" -fore yellow -nonewline
Remove-Item D:\Scripts\Provisioning\psexec\Output\variablepass.txt
write-host " ...Complete" -fore green




