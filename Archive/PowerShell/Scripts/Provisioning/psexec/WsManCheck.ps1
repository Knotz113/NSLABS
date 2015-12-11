
$outputfile = "D:\Scripts\Output\WsManCheck.csv"

if (test-path $outputfile){
remove-item -path $outputfile -force
start-sleep -s 2
Write-Output "Name,WsManCheck" >> "$outputfile"
} Else {
Write-Output "Name,WsManCheck" >> "$outputfile"
}

Clear
Write-host "`n---------------------------------------" -fore red
Write-host "Ping Test" -fore red
Write-host "---------------------------------------" -fore red



$FilePath = "D:\Scripts\Output\PingCheck.csv"
$ServerList = Import-Csv $FilePath  | Where-Object {$_.Check -eq "pass"}
ForEach ($computerName in $ServerList) {
$sname = ($computerName.name)
write-host "Testing WsMan To $sname " -fore yellow -nonewline
if (Test-WSMan -ComputerName $sname) {
	Add-Content $outputfile "$sname,on"
	write-host " ...Pass" -fore green
	}
	Else{
	Add-Content $outputfile "$sname,off"
	write-host " ...Fail" -fore red
	}	
}
