if (test-path D:\Scripts\Output\OS_Check.csv){
remove-item -path D:\Scripts\Output\OS_Check.csv -force
start-sleep -s 2
Write-Output "Name,OS" >> "D:\Scripts\Output\OS_Check.csv"
}

Clear
Write-host "`n---------------------------------------" -fore red
Write-host "Psexec Command Execution" -fore red
Write-host "---------------------------------------" -fore red



$FilePath = "D:\Scripts\Output\NoListener.csv"
$ServerList = get-content $FilePath
ForEach ($computerName in $ServerList) {
.\OS_check.ps1 -computerName $computerName
}

