if (test-path D:\Scripts\Output\PS_Version_Check.csv){
remove-item -path D:\Scripts\Output\PS_Version_Check.csv -force
start-sleep -s 2
Write-Output "Name,Version" >> "D:\Scripts\Output\PS_Version_Check.csv"
} Else {
Write-Output "Name,Version" >> "D:\Scripts\Output\PS_Version_Check.csv"
}

Clear
Write-host "`n---------------------------------------" -fore red
Write-host "Psexec Command Execution" -fore red
Write-host "---------------------------------------" -fore red



$FilePath = "D:\Scripts\Credcheck\BlatanhaPass.csv"
$ServerList = get-content $FilePath
ForEach ($computerName in $ServerList) {
.\PSVersionCheck.ps1 -computerName $computerName
}
$FilePath = "D:\Scripts\Credcheck\ServiceNowDomainAccountPass.csv"
$ServerList = get-content $FilePath
ForEach ($computerName in $ServerList) {
.\PSVersionCheck.ps1 -computerName $computerName
}
$FilePath = "D:\Scripts\Credcheck\InocPass.csv"
$ServerList = get-content $FilePath
ForEach ($computerName in $ServerList) {
.\PSVersionCheck.ps1 -computerName $computerName
}

