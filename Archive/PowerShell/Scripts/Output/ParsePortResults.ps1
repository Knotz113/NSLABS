$FilePath = "D:\Scripts\Output\PortConnectionCheck.csv"

$ServerList = Import-Csv $FilePath  | Where-Object {$_.PSEXEC135 -eq "Y" -and $_.PSEXEC445 -eq "Y"}
$servercount = $ServerList.count
Write-host "$servercount Servers are PSEXEC accessible" -fore Yellow

$ServerList = Import-Csv $FilePath  | Where-Object {$_.PSEXEC135 -eq "N" -and $_.PSEXEC445 -eq "N" -and $_.HTTP -eq "N" -and $_.HTTPS -eq "N"}
$servercount = $ServerList.count
Write-host "$servercount Servers are inaccessible and have no listeners available" -fore Yellow

$ServerList = Import-Csv $FilePath  | Where-Object {$_.HTTP -eq "Y" -and $_.HTTPS -eq "N"}
$servercount = $ServerList.count
Write-host "$servercount Servers only have the HTTP listener on" -fore Yellow

$ServerList = Import-Csv $FilePath  | Where-Object {$_.HTTP -eq "N" -and $_.HTTPS -eq "Y"}
$servercount = $ServerList.count
Write-host "$servercount Servers only have the HTTPS listener on" -fore Yellow

$ServerList = Import-Csv $FilePath  | Where-Object {$_.HTTP -eq "Y" -and $_.HTTPS -eq "Y"}
$servercount = $ServerList.count
Write-host "$servercount Servers have both listeners turned on" -fore Yellow

$ServerList = Import-Csv $FilePath  | Where-Object {$_.PSEXEC135 -eq "N" -or $_.PSEXEC445 -eq "N"}
$servercount = $ServerList.count
Write-host "$servercount Servers do not have PSEXEC ports open" -fore Yellow

$ServerList = Import-Csv $FilePath  | Where-Object {$_.PSEXEC135 -eq "Y" -and $_.PSEXEC445 -eq "Y" -and $_.HTTP -eq "Y" -and $_.HTTPS -eq "N"} | Where-Object {$_.Name -notlike "Fenxen*" -and $_.Name -notlike "Aws*" -and $_.Name -notlike "mss*" -and $_.Name -notlike "mau*" -and $_.Name -notlike "krk*"}
$servercount = $ServerList.count
Write-host "$servercount Servers need to be corrected and PSEXEC is accessible" -fore Yellow

##################################################################################################
<#
set-location D:\Scripts\Provisioning\psexec

# Identify parent directory for the script
$scriptPath = split-path -parent $MyInvocation.MyCommand.Definition
if(!$scriptPath) {
$scriptPath = split-path -parent $psISE.CurrentFile.FullPath
}



ForEach ($computerNamex in $ServerList) {
$computerName = ($computerNamex).Name
write-host "`n$computerName" -fore cyan


if(Test-Path "$scriptPath\..\Provisioning\RemoteFunctions\New-RemoteSession\New-RemoteSession.ps1") {
    $Session = Invoke-Expression "$scriptPath\..\Provisioning\RemoteFunctions\New-RemoteSession\New-RemoteSession.ps1 -ComputerName $computerName -UseRunBook -UseHTTP -maxwait 10"
    if ($Session){
    } else {}
} else {}

if ($Session){

$osv = Invoke-Command -Session $Session -ScriptBlock {
function OSVersion {
$osver = (Get-WmiObject Win32_OperatingSystem).caption
return $osver
}
OSVersion
}
If ($osv -notlike "*2003*"){
Write-host "$osv" -fore green
.\https_single_install.ps1 -computerName $computerName
} Else {
Write-host "$osv" -fore red
}
} Else {}
}
set-location D:\Scripts\Output
#>