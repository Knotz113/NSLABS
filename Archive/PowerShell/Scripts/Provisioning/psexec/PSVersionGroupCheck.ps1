Write-host "`n---------------------------------------" -fore red
Write-host "PSVersionFixGroup Command Execution" -fore red
Write-host "---------------------------------------" -fore red



$FilePath = "D:\Scripts\Provisioning\psexec\CSVs\us_domain_server_list.csv"
$ServerList = Import-CSV $FilePath
ForEach ($computerName in $ServerList) {
$Name = $computername.Name
.\PSVersionCheck2.ps1 $Name
}