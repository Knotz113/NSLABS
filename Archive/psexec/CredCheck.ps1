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
.\PsExec.exe \\$computerName -u $computerName\$username -p $password cmd /c “echo . | powershell -EncodedCommand $encodedCommand” >> .\Output\stdout.txt 2>> .\Output\stderr.txt
}
Function PsexecRemoteCommandSendDomainAccount {
$commandBytes = [System.Text.Encoding]::Unicode.GetBytes($expression)
$encodedCommand = [Convert]::ToBase64String($commandBytes)
.\PsExec.exe \\$computername -u $username -p $password cmd /c “echo . | powershell -EncodedCommand $encodedCommand” >> .\Output\stdout.txt 2>> .\Output\stderr.txt
}

$hostname = ($env:computername)
Write-host "`n---------------------------------------" -fore red
Write-host "Psexec Credential Check" -fore red
Write-host "---------------------------------------`n" -fore red
#$computername = read-host "What is the server to be probed"

$outputfile = "D:\Scripts\Output\CredCheck.csv"
if (test-path $outputfile){
remove-item -path $outputfile -force
start-sleep -s 2
Write-Output "Name,Cred" >> "$outputfile"
} Else {
Write-Output "Name,Cred" >> "$outputfile"
}

$FilePath = "D:\Scripts\Output\PingCheck.csv"
$ServerList = Import-Csv $FilePath  | Where-Object {$_.Check -eq "pass"}
ForEach ($computerName in $ServerList) {
$computerName = ($computerName.name)
if ($skip) {
remove-variable skip
} Else {}




Write-host "`n[ $computerName ]" -fore cyan
$username = "blatanha"
$password = "Bl@ck*Y@k!"
write-host "Cred check for [ $username ] against [ $computerName ]" -fore yellow -nonewline
$expression = “winrm enumerate winrm/config/listener”
PsexecRemoteCommandSend
if ($LastExitCode -eq "0") {
Add-Content $outputfile "$computerName,blatanha"
write-host " ...Pass" -fore green
$skip = "yes"
}
Else {
write-host " ...Fail" -fore Red
}





if (!$skip){
$username = "Inoc"
$password = "Wttm030(3"
write-host "Cred check for [ $username ] against [ $computerName ]" -fore yellow -nonewline
$expression = “winrm enumerate winrm/config/listener”
PsexecRemoteCommandSend
if ($LastExitCode -eq "0") {
Add-Content $outputfile "$computerName,Inoc"
write-host " ...Pass" -fore green
$skip = "yes"
}
Else {
write-host " ...Fail" -fore Red
}
} Else {}






if (!$skip){
SetSNCreds
write-host "Cred check for [ $username ] against [ $computerName ]" -fore yellow -nonewline
$expression = “winrm enumerate winrm/config/listener”
PsexecRemoteCommandSendDomainAccount
if ($LastExitCode -eq "0") {
Add-Content $outputfile "$computerName,sndomain"
write-host " ...Pass" -fore green
$skip = "yes"
}
Else {
write-host " ...Fail" -fore Red
}
} Else {}






if (!$skip){
Add-Content $outputfile "$computerName,none"
} Else {}

} 
