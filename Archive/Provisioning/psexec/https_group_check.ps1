Function WriteToCsv {
$Outputstring = "$results"
$Outputstring -join "," >> D:\Scripts\Output\HTTPS_Check_Results.csv
}

If (Test-path D:\Scripts\Output\HTTPS_Check_Results.txt){
remove-item D:\Scripts\Output\HTTPS_Check_Results.txt
} Else {}

# Blatanha Account check
Clear
Write-host "`n---------------------------------------" -fore red
Write-host "Psexec Command Execution" -fore red
Write-host "---------------------------------------" -fore red
#$computername = read-host "What is the server to be probed"

# ServiceNow Domain Account Check

$FilePath = "D:\Scripts\Credcheck\ServiceNowDomainAccountPass.csv"
$ServerList = get-content $FilePath
ForEach ($computerName in $ServerList) {
.\https_single_check.ps1 -computerName $computerName
write-host "Results: " -nonewline
write-host "$results" -fore gray
WriteToCsv
}

$FilePath = "D:\Scripts\Credcheck\InocPass.csv"
$ServerList = get-content $FilePath
ForEach ($computerName in $ServerList) {
.\https_single_check.ps1 -computerName $computerName
write-host "Results: " -nonewline
write-host "$results" -fore gray
WriteToCsv
}

$FilePath = "D:\Scripts\Credcheck\BlatanhaPass.csv"
$ServerList = Get-Content $FilePath
ForEach ($computerName in $ServerList) {
.\https_single_check.ps1 -computerName $computerName
write-host "Results: " -nonewline
write-host "$results" -fore gray
WriteToCsv
}
