Function Get-DNS{
Write-host "Looking up DNS entry for $computerName " -fore yellow -nonewline
$dnschk = $NULL
$dnsexist =$NULL
$ErrorActionPreference= "silentlycontinue"
$dnschk = [System.Net.DNS]::GetHostAddresses("$computername")
$script:dnsip = $dnschk.IPAddressToString 
if ($dnsip -match "(\d{1,3}).(\d{1,3}).(\d{1,3}).(\d{1,3})") {
Write-host " ...$dnsip" -Fore Green
} else {
write-host " ...No DNS entry found." -Fore Red
}
}
Function USNetSegDnsCheck {
Write-host "Running USNetSeg Check " -fore yellow -nonewline
If (($dnsip -match "(172).(19).(\d{1,3}).(\d{1,3})") -or ($dnsip -match "(172).(18).(\d{1,3}).(\d{1,3})")) {
write-host "This is in the USNetSeg" -fore red
$Outputstring = "$computerName"
$Outputstring -join "," >> D:\Scripts\Provisioning\psexec\CSVs\US-DomainNetSegExport.csv
}
Else {
Write-host "This is not in USNetSeg" -fore green
$Outputstring = "$computerName"
$Outputstring -join "," >> D:\Scripts\Provisioning\psexec\CSVs\US-DomainNonUSNetSegExport.csv
}
}
Function PsexecRemoteCommandSend {
$commandBytes = [System.Text.Encoding]::Unicode.GetBytes($expression)
$encodedCommand = [Convert]::ToBase64String($commandBytes)
.\PsExec.exe \\$computerName -u $computerName\$username -p $password cmd /c “echo . | powershell -EncodedCommand $encodedCommand” >> .\Output\stdout.txt 2>> .\Output\stderr.txt
}


Write-host "`n---------------------------------------" -fore red
Write-host "Parse Vmware csv Export file" -fore red
Write-host "---------------------------------------`n" -fore red
#$computername = read-host "What is the server to be probed"


$FilePath = ".\CSVs\ExportList.csv"
$ServerList = Import-CSV $FilePath
ForEach ($computerNamex in $ServerList) {
$computerName = ($computerNamex).Name
$dnsName = ($computerNamex)."DNS Name"
write-host "$computerName"
If ($dnsName -like "*us.maritz.net"){
$Outputstring = "$computerName"
$Outputstring -join "," >> D:\Scripts\Provisioning\psexec\CSVs\US-DomainALLExport.csv
}
ElseIf ($dnsName -like "*mpn.local"){
$Outputstring = "$computerName"
$Outputstring -join "," >> D:\Scripts\Provisioning\psexec\CSVs\MPN-DomainExport.csv
}
ElseIf ($dnsName -like "*mpne.local"){
$Outputstring = "$computerName"
$Outputstring -join "," >> D:\Scripts\Provisioning\psexec\CSVs\MPNE-DomainExport.csv
}
ElseIf ($dnsName -like "*mpni.local"){
$Outputstring = "$computerName"
$Outputstring -join "," >> D:\Scripts\Provisioning\psexec\CSVs\MPNI-DomainExport.csv
}
ElseIf ($dnsName -like "*mneti.local"){
$Outputstring = "$computerName"
$Outputstring -join "," >> D:\Scripts\Provisioning\psexec\CSVs\MNETI-DomainExport.csv
}
ElseIf ($dnsName -like "*mnete.local"){
$Outputstring = "$computerName"
$Outputstring -join "," >> D:\Scripts\Provisioning\psexec\CSVs\MNETE-DomainExport.csv
}
Else {
$Outputstring = "$computerName"
$Outputstring -join "," >> D:\Scripts\Provisioning\psexec\CSVs\NON-DomainExport.csv
}
}


$FilePath = ".\CSVs\US-DomainALLExport.csv"
$ServerList = Get-Content $FilePath
ForEach ($computerName in $ServerList) {
write-host "$computerName"
Get-DNS
USNetSegDnsCheck
}