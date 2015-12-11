Param(
    [Parameter(Mandatory = $false)]
    [String]$servername
)

$outputfile = "D:\Scripts\Output\AccessibilityResults.csv"
if (test-path $outputfile){
remove-item -path $outputfile -force
start-sleep -s 2
Write-Output "NAME,PING,HTTP,HTTPS,PSEXEC135,PSEXEC445,BLATANHA,INOC,SNCRED" >> "$outputfile"
} Else {
Write-Output "NAME,PING,HTTP,HTTPS,PSEXEC135,PSEXEC445,BLATANHA,INOC,SNCRED" >> "$outputfile"
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
Else {}
}
Function PsexecRemoteCommandSend {
$commandBytes = [System.Text.Encoding]::Unicode.GetBytes($expression)
$encodedCommand = [Convert]::ToBase64String($commandBytes)
.\PsExec.exe \\$servername -u $servername\$username -p $password cmd /c “echo . | powershell -EncodedCommand $encodedCommand” >> .\Output\stdout.txt 2>> .\Output\stderr.txt 
}
Function PsexecRemoteCommandSendDomainAccount {
$commandBytes = [System.Text.Encoding]::Unicode.GetBytes($expression)
$encodedCommand = [Convert]::ToBase64String($commandBytes)
.\PsExec.exe \\$servername -u $username -p $password cmd /c “echo . | powershell -EncodedCommand $encodedCommand” >> .\Output\stdout.txt 2>> .\Output\stderr.txt
}

$hostname = ($env:computername)

Write-host "`n---------------------------------------" -fore red
Write-host "Accessibility Check" -fore red
Write-host "---------------------------------------" -fore red

if (!($servername)){
$servername = read-host "What is the server to be probed"
} Else {}



Write-host "`n[ $servername ]" -fore cyan

$ErrorActionPreference = 'SilentlyContinue'
write-host "Pinging $servername" -fore yellow -nonewline
if (test-connection $servername) {
write-host " ...Pass" -fore green
$a = "Y" 
}
Else {
write-host " ...Fail" -fore red
$a = "N"
}
$ErrorActionPreference = 'Continue'

$port = 5985 
Write-host "Checking HTTP listening port $port" -fore yellow -nonewline
$ErrorActionPreference = 'SilentlyContinue'
If (New-Object System.Net.Sockets.TCPClient -ArgumentList $servername,$port) { 
Write-Host ' ...Port Open' -fore green
$b = "Y"
}
If ($? -eq $false) { 
Write-Host ' ...Port Not Accessible' -fore red 
$b = "N"
}
$ErrorActionPreference = 'Continue'

$port = 5986 
Write-host "Checking HTTPS listening port $port" -fore yellow -nonewline
$ErrorActionPreference = 'SilentlyContinue'
If (New-Object System.Net.Sockets.TCPClient -ArgumentList $servername,$port) { 
Write-Host ' ...Port Open' -fore green 
$c = "Y"
}
If ($? -eq $false) { 
Write-Host ' ...Port Not Accessible' -fore red 
$c = "N"
}
$ErrorActionPreference = 'Continue'

$port = 135 
Write-host "Checking Psexec port $port" -fore yellow -nonewline
$ErrorActionPreference = 'SilentlyContinue'
If (New-Object System.Net.Sockets.TCPClient -ArgumentList $servername,$port) { 
Write-Host ' ...Port Open' -fore green 
$d = "Y"
}
If ($? -eq $false) { 
Write-Host ' ...Port Not Accessible' -fore red 
$d = "N"
}
$ErrorActionPreference = 'Continue'

$port = 445 
Write-host "Checking Psexec port $port" -fore yellow -nonewline
$ErrorActionPreference = 'SilentlyContinue'
If (New-Object System.Net.Sockets.TCPClient -ArgumentList $servername,$port) { 
Write-Host ' ...Port Open' -fore green 
$e = "Y"
}
If ($? -eq $false) { 
Write-Host ' ...Port Not Accessible' -fore red 
$e = "N"
}
$ErrorActionPreference = 'Continue'

$username = "blatanha"
$password = "Bl@ck*Y@k!"
write-host "Cred check for [ $username ] against [ $servername ]" -fore yellow -nonewline
$expression = “winrm enumerate winrm/config/listener”
PsexecRemoteCommandSend
if ($LastExitCode -eq "0") {
write-host " ...Pass" -fore green
$f = "Y"
} Else {
write-host " ...Fail" -fore Red
$f = "N"
}

$username = "Inoc"
$password = "Wttm030(3"
write-host "Cred check for [ $username ] against [ $servername ]" -fore yellow -nonewline
$expression = “winrm enumerate winrm/config/listener”
PsexecRemoteCommandSend
if ($LastExitCode -eq "0") {
write-host " ...Pass" -fore green
$g = "Y"
} Else {
write-host " ...Fail" -fore Red
$g = "N"
}

#SetSNCreds
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
Else {}

write-host "Cred check for [ $username ] against [ $servername ]" -fore yellow -nonewline
$expression = “winrm enumerate winrm/config/listener”
PsexecRemoteCommandSendDomainAccount
if ($LastExitCode -eq "0") {
write-host " ...Pass" -fore green
$h = "Y"
} Else {
write-host " ...Fail" -fore Red
$h = "N"
}
