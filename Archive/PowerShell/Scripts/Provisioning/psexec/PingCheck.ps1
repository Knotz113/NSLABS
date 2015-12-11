
$outputfile = "D:\Scripts\Output\PingCheck.csv"

if (test-path $outputfile){
remove-item -path $outputfile -force
start-sleep -s 2
Write-Output "Name,Check" >> "$outputfile"
} Else {
Write-Output "Name,Check" >> "$outputfile"
}

Clear
Write-host "`n---------------------------------------" -fore red
Write-host "Ping Test" -fore red
Write-host "---------------------------------------" -fore red



$FilePath = "D:\Scripts\Provisioning\psexec\CSVs\cmdb_ci_win_server.csv"
$ServerList = Import-Csv $FilePath  #| Where-Object {$_.department -eq "Finance"}
ForEach ($computerName in $ServerList) {
$sname = ($computerName.name)
write-host "Testing Connection To $sname " -fore yellow -nonewline
if (Test-Connection $sname -quiet) {
	Add-Content $outputfile "$sname,pass"
	write-host " ...Pass" -fore green
	}
	Else{
	Add-Content $outputfile "$sname,fail"
	write-host " ...Fail" -fore red
	}	
}
