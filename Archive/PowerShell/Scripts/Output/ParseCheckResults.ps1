$FilePath = "D:\Scripts\Output\HTTPS_Check_Results.csv"
$ServerList = get-content $FilePath
ForEach ($computerName in $ServerList) {
write-host "$computerName"

If ($computerName -like "*NA NA"){
$computerName = $computerName.Replace(" NA NA", "")
$Outputstring = "$computerName"
$Outputstring -join "," >> D:\Scripts\Output\NoListener.csv
} Else {}

If ($computerName -like "*HTTP NA"){
$computerName = $computerName.Replace(" HTTP NA", "")
$Outputstring = "$computerName"
$Outputstring -join "," >> D:\Scripts\Output\NoListener.csv
} Else {}

}