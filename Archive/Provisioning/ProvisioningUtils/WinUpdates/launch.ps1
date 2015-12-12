Function StopWinUpdateTimer {
#--- Stop script timer ---#
$end = Get-Date
Write-Host "[ It took " -Fore Green -nonewline
$ts = ($end - $timer)
$tm = $ts.TotalMinutes
$math = [math]::round($tm,0)
write-host $math -NoNewline -Fore Yellow
write-host " to perform this round of Updates ]" -Fore Green
}

$ComputerName = $ENV:ComputerName
$RunAsUser = "System"
$TaskName = "'Windows Updates'"
$TaskRun = "'PowerShell.exe -NoLogo -File C:\Scripts\Provisioning\WinUpdates\Winupdates.ps1'"
$Schedule = "ONCE"
$StartTime = (Get-Date).AddSeconds(70).ToString("HH:mm:ss")

$Command = "schtasks.exe /create /s $ComputerName /ru $RunAsUser /tn $TaskName /tr $TaskRun /sc $Schedule /st $StartTime /F"

Write-Host "`nPerforming Windows Updates" -Fore Yellow

Invoke-Expression $Command

$condition = Test-Path C:\Scripts\Provisioning\WinUpdates\complete.txt
write-host "`nPerforming Windows Updates" -nonewline
$script:timer = Get-Date	# Start Script Timer
DO
{
write-host "." -nonewline;start-Sleep -Seconds 5
$condition = Test-Path C:\Scripts\Provisioning\WinUpdates\complete.txt
} While ($condition -like "false")

write-host "`n[ Windows Updates Complete ]" -Fore Green
StopWinUpdateTimer

Remove-Item C:\Scripts\Provisioning\WinUpdates\complete.txt

#Unregister-ScheduledTask -TaskName "Windows Updates" -Confirm:$false