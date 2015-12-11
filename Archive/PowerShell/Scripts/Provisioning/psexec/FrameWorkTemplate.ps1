Function PsexecRemoteCommandSend {
$commandBytes = [System.Text.Encoding]::Unicode.GetBytes($expression)
$encodedCommand = [Convert]::ToBase64String($commandBytes)
.\PsExec.exe \\$computerName -u $computerName\$username -p $password cmd /c “echo . | powershell -EncodedCommand $encodedCommand”
}
Function PsexecRemoteCommandSendDomainAccount {
$commandBytes = [System.Text.Encoding]::Unicode.GetBytes($expression)
$encodedCommand = [Convert]::ToBase64String($commandBytes)
.\PsExec.exe \\$computername -u $username -p $password cmd /c “echo . | powershell -EncodedCommand $encodedCommand” >> .\Output\stdout.txt 2>> .\Output\stderr.txt
}
Function Robo {
Robocopy.exe D:\Scripts\Provisioning \\$computerName\c$\Scripts\Provisioning *.* /E 
}
 

Clear
Write-host "`n---------------------------------------" -fore red
Write-host "HTTPS Group Install Process" -fore red
Write-host "---------------------------------------`n" -fore red
#$computername = read-host "What is the server to be probed"

$FilePath = ".\CSVs\https_group_install.csv"
$ServerList = Import-CSV $FilePath
ForEach ($computerNamex in $ServerList) {
$computerName = ($computerNamex).Name
set-location D:\Scripts\Provisioning\psexec
Write-host "`n`nPSexec Command Execution for $computername" -fore Cyan
$username = "blatanha"
$password = "Bl@ck*Y@k!"

#$expression = “winrm e winrm/config/listener”
#PsexecRemoteCommandSend

}
