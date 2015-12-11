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
.\PsExec.exe \\$computerName -u $computerName\$username -p $password cmd /c “echo . | powershell -EncodedCommand $encodedCommand” 
}
Function PsexecRemoteCommandSendDomainAccount {
$commandBytes = [System.Text.Encoding]::Unicode.GetBytes($expression)
$encodedCommand = [Convert]::ToBase64String($commandBytes)
.\PsExec.exe \\$computername -u $username -p $password cmd /c “echo . | powershell -EncodedCommand $encodedCommand” 
}

$hostname = ($env:computername)
Write-host "`n---------------------------------------" -fore red
Write-host "Psexec Credential Check" -fore red
Write-host "---------------------------------------`n" -fore red
$computername = read-host "What is the server to be probed"

Write-host "`n[ $computerName ]" -fore cyan
$username = "blatanha"
$password = "Bl@ck*Y@k!"
write-host "Cred check for [ $username ] against [ $computerName ]" -fore yellow -nonewline
$expression = “winrm enumerate winrm/config/listener”
PsexecRemoteCommandSend
if ($LastExitCode -eq "0") {
write-host " ...Pass" -fore green
} Else {
write-host " ...Fail" -fore Red
}

$username = "Inoc"
$password = "Wttm030(3"
write-host "Cred check for [ $username ] against [ $computerName ]" -fore yellow -nonewline
$expression = “winrm enumerate winrm/config/listener”
PsexecRemoteCommandSend
if ($LastExitCode -eq "0") {
write-host " ...Pass" -fore green
} Else {
write-host " ...Fail" -fore Red
}

SetSNCreds
write-host "Cred check for [ $username ] against [ $computerName ]" -fore yellow -nonewline
$expression = “winrm enumerate winrm/config/listener”
PsexecRemoteCommandSendDomainAccount
if ($LastExitCode -eq "0") {
write-host " ...Pass" -fore green
} Else {
write-host " ...Fail" -fore Red
}

