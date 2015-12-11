Clear
Write-host "`n---------------------------------------" -fore red
Write-host "DebugUser Add" -fore red
Write-host "---------------------------------------" -fore red

$FilePath = "D:\Scripts\Output\ConnectionPass.txt"
$ServerList = Get-Content $FilePath
ForEach ($computerName in $ServerList) {
.\DebugUserAddSingle.ps1 $computerName
}