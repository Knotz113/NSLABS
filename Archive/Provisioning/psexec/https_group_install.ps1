

Clear
Write-host "`n---------------------------------------" -fore red
Write-host "HTTPS Group Install Process" -fore red
Write-host "---------------------------------------`n" -fore red

$FilePath = ".\CSVs\https_group_install.csv"
$exsistingpath = read-host "Do you want to set a File Path for the CSV import? (y/n)"
if (($exsistingpath -eq "y") -or ($exsistingpath -eq "Y")){

Do {
remove-variable FilePath
$FilePath = read-host "Where is the CSV located?"
Write-host "Importing File" -fore yellow -nonewline
if (!(Test-path $FilePath)) {
write-host " ...No File was found there." -fore red
Write-Host "Press any key to try again...`n";
$null = $Host.UI.RawUI.ReadKey('NoEcho,IncludeKeyDown');
}
Else {Write-host " ...Complete" -fore green}
} Until (Test-path $FilePath)
}
Else {}

$ServerList = Import-CSV $FilePath
ForEach ($computerNamex in $ServerList) {
$computerName = ($computerNamex).Name

.\https_single_install.ps1 -computerName $computerName

Start-Sleep -s 5
}
