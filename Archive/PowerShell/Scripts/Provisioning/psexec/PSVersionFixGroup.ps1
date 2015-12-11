Clear
Write-host "`n---------------------------------------" -fore red
Write-host "PSVersionFixGroup Command Execution" -fore red
Write-host "---------------------------------------" -fore red



$FilePath = "D:\Scripts\Output\PS_Version_Check.csv"
$ServerList = Import-CSV $FilePath | Where-Object {$_.OS -eq "2008"}
ForEach ($computerName in $ServerList) {
$Name = $computername.Name
.\PSVersionFixSingle.ps1 $Name
}