 
Function PowershellV45Install64Bit {
     $arglist='C:\Scripts\PSVersionUpgrade\Windows6.1-KB2819745-x64-MultiPkg.msu','/quiet','/norestart'
     Start-Process -FilePath 'c:\windows\system32\wusa.exe' -ArgumentList $arglist -NoNewWindow -Wait
}
Function PowershellV45Install32Bit {
     $arglist='C:\Scripts\PSVersionUpgrade\Windows6.1-KB2819745-x86-MultiPkg.msu','/quiet','/norestart'
     Start-Process -FilePath 'c:\windows\system32\wusa.exe' -ArgumentList $arglist -NoNewWindow -Wait
}
Function InstallDotNet45 {
Start-Process -FilePath "C:\Scripts\PSVersionUpgrade\dotNetFx45_Full_setup.exe" -ArgumentList "/q /norestart" -Wait -Verb RunAs
}
Function InstallDotNet45Offline {
Start-Process -FilePath "C:\Scripts\PSVersionUpgrade\NDP452-KB2901907-x86-x64-AllOS-ENU.exe" -ArgumentList "/q /norestart" -Wait -Verb RunAs
}
Function WriteToLog {
Param (
    [Parameter(Mandatory = $false)]
    [String]$Entry
)
If (!(Test-path C:\Scripts\Output)){
New-Item c:\Scripts\Output -type directory
}
Else {}
Write-output "$Entry" | out-file "C:\Scripts\Output\$(get-date -f yyyy-MM-dd) PowershellUpgradeLog.txt" -append
}

$date = Get-Date
$COMPUTER = (Get-WmiObject Win32_OperatingSystem).CSName

# Get OS Version
if ([System.IntPtr]::Size -eq 4) {
$osbit = "32" 
} 
else {
$osbit = "64"
}
WriteToLog -Entry "OSBit: $osbit"

# Identify parent directory for the script
$scriptPath = split-path -parent $MyInvocation.MyCommand.Definition
if(!$scriptPath) {
$scriptPath = split-path -parent $psISE.CurrentFile.FullPath
}

$CurrentScriptFilePath = $script:MyInvocation.MyCommand.Path
$CurrentScriptLastModifiedDateTime = (Get-Item $script:MyInvocation.MyCommand.Path).LastWriteTime

#Clear
Write-host "`n-------------------------------------" -fore red
Write-host "  PSVersion Check/Install" -fore red
Write-host "-------------------------------------" -fore red
write-host "Host: " -nonewline
Write-host "[ $COMPUTER ]" -fore gray
Write-host "Powershell" -fore yellow -nonewline
if ($PSVersionTable.PSVersion.Major -lt 4){
Write-host " ...Out of Date" -fore red
WriteToLog -Entry "PowerShell is out of Date"
Write-host "DotNet Version" -fore yellow -nonewline
If (Get-ItemProperty 'HKLM:\SOFTWARE\Microsoft\NET Framework Setup\NDP\v4\Full' -EA SilentlyContinue){
$dotnetversion = (Get-ItemProperty 'HKLM:\SOFTWARE\Microsoft\NET Framework Setup\NDP\v4\Full').Version
Write-host " ...Up to Date" -fore green
WriteToLog -Entry "DotNet Version is up to Date"
Write-host "Current version: " -nonewline
Write-host "[ $dotnetversion ]" -fore gray
WriteToLog -Entry "Current Version is $dotnetversion"
}
Else {
Write-host " ...Out of Date`n" -fore red
WriteToLog -Entry "DotNet Version is out of date"
Write-host "Updating DotNet" -fore cyan
Write-host "Starting Install" -fore yellow -nonewline
InstallDotNet45Offline
WriteToLog -Entry "DotNet Update Complete"
Write-host " ...Complete" -fore green
$dotnetversion = (Get-ItemProperty 'HKLM:\SOFTWARE\Microsoft\NET Framework Setup\NDP\v4\Full').Version 
Write-host "DotNet Version: " -nonewline
Write-host "[ $dotnetversion ]" -fore gray
WriteToLog -Entry "Current Version is $dotnetversion"
}
Write-host "`nUpdating Powershell" -fore cyan
WriteToLog -Entry "Updating Powershell"
Write-host "Starting Install" -fore yellow -nonewline
if ($osbit -eq "32"){
PowershellV45Install32Bit
WriteToLog -Entry "Powershell 32bit install Complete"
}
Else {
PowershellV45Install64Bit
WriteToLog -Entry "Powershell 64bit install Complete"
}
Write-host " ...Complete" -fore green 
}
else {
Write-host " ...Up to Date" -fore green
WriteToLog -Entry "Powershell is up to date"
}