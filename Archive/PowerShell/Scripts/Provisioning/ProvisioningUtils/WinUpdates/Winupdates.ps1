# from http://www.lazywinadmin.com/2011/06/powershell-and-windows-updates.html

start-transcript -path C:\Scripts\Provisioning\WinUpdates\Winupdates.txt

function Get-WIAStatusValue($value)

{

switch -exact ($value)

{

0 {"NotStarted"}
1 {"InProgress"}

2 {"Succeeded"}

3 {"SucceededWithErrors"}

4 {"Failed"}

5 {"Aborted"}

}

}

$needsReboot = $false

$UpdateSession = New-Object -ComObject Microsoft.Update.Session

$UpdateSearcher = $UpdateSession.CreateUpdateSearcher()

Write-Host " - Searching for Updates"

$SearchResult = $UpdateSearcher.Search("IsAssigned=1 and IsHidden=0 and IsInstalled=0")

#$SearchResult = $UpdateSearcher.Search("IsInstalled=0 and Type='Software'")

Write-Host " - Found [$($SearchResult.Updates.count)] Updates to Download and install"

Write-Host

foreach($Update in $SearchResult.Updates)

{

$UpdatesCollection = New-Object -ComObject Microsoft.Update.UpdateColl

if ( $Update.EulaAccepted -eq 0 ) { $Update.AcceptEula() }

$UpdatesCollection.Add($Update) | out-null


Write-Host " + Downloading $($Update.Title)" -Fore yellow

$UpdatesDownloader = $UpdateSession.CreateUpdateDownloader()

$UpdatesDownloader.Updates = $UpdatesCollection

$DownloadResult = $UpdatesDownloader.Download()

$Message = " - Download {0}" -f (Get-WIAStatusValue $DownloadResult.ResultCode)

Write-Host $message


Write-Host " - Installing Update"

$UpdatesInstaller = $UpdateSession.CreateUpdateInstaller()

$UpdatesInstaller.Updates = $UpdatesCollection

$InstallResult = $UpdatesInstaller.Install()

$Message = " - Install {0}" -f (Get-WIAStatusValue $DownloadResult.ResultCode)

Write-Host "$message" -fore green

Write-Host

$needsReboot = $installResult.rebootRequired

}

if($needsReboot)
{
write-host "Reboot is needed" -Fore red
New-Item C:\Scripts\Provisioning\WinUpdates\complete.txt -type file
}
else{
write-host "Reboot is not needed" -Fore green
New-Item C:\Scripts\Provisioning\WinUpdates\complete.txt -type file
}

stop-transcript