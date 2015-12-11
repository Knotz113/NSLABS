
#$ErrorActionPreference = "inquire"

#-----------------------#
#
#  Phase 1 Functions
#
#-----------------------#
Function DisplayVariables {
Write-Host "Variable Carry-Over" -Fore White
Write-Host "ServerName: $targetComputer"
Write-Host "ServerType: $ServerType"
Write-Host "PrivateIP: $PrivateIP"
Write-Host "Domain: $Domain"
Write-Host "OU: $OU"
Write-Host "ftpIP: $ftpIP"
write-host "inusad: $inusad"
write-host "phasestep: $phasestep"
write-host "OSversion: $OSversion"
}
Function DetectOS {

write-host "Detecting Local OS" -Fore Yellow -nonewline
$OSVerNumber = (Get-WmiObject Win32_OperatingSystem).version
Switch -wildcard ($OSVerNumber){
                "5.2*" { 
				$script:OSversion = "2003" 
				Write-host " ...$OSversion Detected" -Fore Green
				}
                "6.0*" { 
				$script:OSversion = "2008" 
				Write-host " ...$OSversion Detected" -Fore Green
				}
                "6.1*" { 
				$script:OSversion = "2008R2" 
				Write-host " ...$OSversion Detected" -Fore Green
				}
                "6.2*" { 
				$script:OSversion = "2012" 
				Write-host " ...$OSversion Detected" -Fore Green
				}
                "6.3*" { 
				$script:OSversion = "2012R2"
				Write-host " ...$OSversion Detected" -Fore Green
				}
                default { 
				$script:OSversion = "Unknown" 
				Write-host " ...$OSversion Detected" -Fore Green
				}
}

}
Function FindDisksWithNoPartitions {

$drives = gwmi Win32_diskdrive
$scriptdisk = $Null
$script = $Null
$OSversion = (((Get-WmiObject Win32_operatingsystem).version).ToString()).Split('.')[0]

foreach ($disk in $drives){
if ($disk.Partitions -eq "0"){
    $drivenumber = $disk.DeviceID -replace '[\\\\\.\\physicaldrive]',''
    
    If ($OSversion -eq "5"){
$script = @"
select disk $drivenumber
online noerr
create partition primary noerr
"@
    }
    ElseIf ($OSversion -eq "6"){
$script = @"
select disk $drivenumber
online disk noerr
attributes disk clear readonly noerr
create partition primary noerr
format quick
"@
}
    }
    $drivenumber = $Null
    $scriptdisk += $script + "`n"
    }
$scriptdisk | diskpart
}
Function Change-CDromDriveLetter {

    Write-host "Change CD Rom letter to R" -Fore Yellow -nonewline
    (gwmi Win32_cdromdrive).drive | %{$a=mountvol $_ /l;mountvol $_ /d;$a=$a.Trim();mountvol r: $a}
	Write-host " ...Complete" -Fore Green
}
Function AssignDriveLetters {

Write-host "Assigning Drive Letters" -Fore Yellow -nonewline
#(http://powershell.com/cs/blogs/tips/archive/2009/01/15/enumerating-drive-letters.aspx)
$volumes = gwmi Win32_volume | where {$_.BootVolume -ne $True -and $_.SystemVolume -ne $True}
$letters = 68..89 | ForEach-Object { ([char]$_)+":" }
$freeletters = $letters | Where-Object { 
  (New-Object System.IO.DriveInfo($_)).DriveType -eq 'NoRootDirectory'
}
foreach ($volume in $volumes){
    if ($volume.DriveLetter -eq $Null){
        If ($OSVersion -eq "5"){
          mountvol $freeletters[0] $volume.DeviceID
          format $freeletters[0] /FS:NTFS /q /y
        }
        Else {
            mountvol $freeletters[0] $volume.DeviceID    
        }    
    }
$freeletters = $letters | Where-Object { 
    (New-Object System.IO.DriveInfo($_)).DriveType -eq 'NoRootDirectory'
}
} 
Write-host " ...Complete" -Fore Green
}
Function New-RegistryKey([string]$key,[string]$Name,[string]$type,[string]$value) {

    #Split the registry path into its single keys and save
    #them in an array, use \ as delimiter:
    $subkeys = $key.split("\")
    
      #Do this for all elements in the array:
    foreach ($subkey in $subkeys)
    {
        #Extend $currentkey with the current element of
        #the array:
        $currentkey += ($subkey + '\')

        #Check if $currentkey already exists in the registry
        if (!(Test-Path $currentkey))
        {
            #If no, create it and send Powershell output
            #to null (don't show it)
            New-Item -Type String $currentkey | Out-Null
        }
     }
     #Set (or change if already exists) the value for $currentkey
      Set-ItemProperty $CurrentKey $Name -value $Value -type $type 
} 
Function RegAction {

Param (
        [String]$action,
        [string]$path,
        [string]$value,
        [string]$data,
        [string]$type
        )

if($action -ne $null)
{
    Switch($action)
    {
    "RegWrite"
        {
        If(-not(test-path -path $path))
            {
            New-Item -path $path -force
            New-ItemProperty -path $path -name $value -Type $type -Value $data -force
            }
        Else
            {
            Set-ItemProperty -path $path -name $value -Type $type -Value $data -force
            }
        }
    "RegDelete"
        {
		if($value -eq "" ){
			Remove-Item -Path $path}
		Else {
        Remove-ItemProperty -path $path -name $value
			}
        }
   }
}        
       
} 
Function Remove-DriveAccount {

    param(
	[string] $accountName,
	[string] $Drive
	)
    $colRights = [System.Security.AccessControl.FileSystemRights]"Read" 

    $InheritanceFlag = [System.Security.AccessControl.InheritanceFlags]::None
    $PropagationFlag = [System.Security.AccessControl.PropagationFlags]::None 

    $objType =[System.Security.AccessControl.AccessControlType]::Allow 

    $objUser = New-Object System.Security.Principal.NTAccount($accountName) 

    $objACE = New-Object System.Security.AccessControl.FileSystemAccessRule `
    ($objUser, $colRights, $InheritanceFlag, $PropagationFlag, $objType) 

    $objACL = Get-ACL $Drive 
    $objACL.RemoveAccessRuleAll($objACE) 

    Set-ACL $Drive $objACL
}
Function Add-DriveAccount {

    param(
	[string] $accountName,
	[string] $Drive
	)
    
    $colRights = [System.Security.AccessControl.FileSystemRights]"ListDirectory, `
    ReadAndExecute, ReadAttributes, ReadExtendedAttributes, ReadPermissions, Traverse"
    $InheritanceFlag = [System.Security.AccessControl.InheritanceFlags]"ContainerInherit, ObjectInherit"
    $PropagationFlag = [System.Security.AccessControl.PropagationFlags]::None 

    $objType =[System.Security.AccessControl.AccessControlType]::Allow 

    $objUser = New-Object System.Security.Principal.NTAccount($accountName) 

    $objACE = New-Object System.Security.AccessControl.FileSystemAccessRule `
    ($objUser, $colRights, $InheritanceFlag, $PropagationFlag, $objType) 

    $objACL = Get-ACL $Drive 
    $objACL.AddAccessRule($objACE) 

    Set-ACL $Drive $objACL
}
Function Set-TimeZone { 

 
    param( 
        [parameter(Mandatory=$true)] 
        [string]$TimeZone 
    ) 
     
    $osVersion = (Get-Item "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion").GetValue("CurrentVersion") 
    $proc = New-Object System.Diagnostics.Process 
    $proc.StartInfo.WindowStyle = "Hidden" 
 
    if ($osVersion -ge 6.0) 
    { 
        # OS is newer than XP 
        $proc.StartInfo.FileName = "tzutil.exe" 
        $proc.StartInfo.Arguments = "/s `"$TimeZone`"" 
    } 
    else 
    { 
        # XP or earlier 
        $proc.StartInfo.FileName = $env:comspec 
        $proc.StartInfo.Arguments = "/c start /min control.exe TIMEDATE.CPL,,/z $TimeZone" 
    } 
 
    $proc.Start() | Out-Null 
 
}
Function CreateDLogsFolder {

New-Item -Path D:\Logs -ItemType directory
}
Function SetTimeZone {

Write-Host "Set Time Zone to Central Standard" -Fore Yellow -NoNewline
Set-TimeZone "Central Standard Time"
Write-Host " ...Complete" -Fore Green
}
Function LogWrite {
   Param ([string]$logstring)

   $date = get-date -format g
   Add-content -path c:\Scripts\Logs\installlogs\"$targetComputer"_install.log -value $date":"$logstring
}
Function LogSetup {

    $scriptversion = "2.000"
    $currentScriptName = $MyInvocation.MyCommand.Name
    $logfile = "c:\Scripts\Logs\installlogs\"+$targetComputer+"_install.log"
    #if(!(test-path -path c:\Scripts\Logs\installlogs\"+$targetComputer+"_install.log))
    #{new-item c:\Scripts\Logs\installlogs -itemType directory}
    LogWrite " Script Log Created"
}
Function New-RegistryKey {
    param([string]$key,[string]$Name,[string]$type,[string]$value)

    #Split the registry path into its single keys and save
    #them in an array, use \ as delimiter:
    $subkeys = $key.split("\")
    
    #Do this for all elements in the array:
    foreach ($subkey in $subkeys)
    {
        #Extend $currentkey with the current element of
        #the array:
        $currentkey += ($subkey + '\')

        #Check if $currentkey already exists in the registry
        if (!(Test-Path $currentkey))
        {
            #If no, create it and send Powershell output
            #to null (don't show it)
            New-Item -Type String $currentkey | Out-Null
        }
     }
     #Set (or change if alreday exists) the value for $currentkey
      Set-ItemProperty $CurrentKey $Name -value $Value -type $type 
}
Function RegAction {

    Param(
            [String]$action,
            [string]$path,
            [string]$value,
            [string]$data,
            [string]$type
          )

    if($action -ne $null)
    {
        Switch($action)
        {
        "RegWrite"
            {
            If(-not(test-path -path $path))
                {
                New-Item -path $path -force
                New-ItemProperty -path $path -name $value -Type $type -Value $data -force
                }
            Else
                {
                Set-ItemProperty -path $path -name $value -Type $type -Value $data -force
                }
            }
        "RegDelete"
            {
		    if($value -eq "" ){
			    Remove-Item -Path $path}
		    Else {
            Remove-ItemProperty -path $path -name $value
			    }
            }
       }
    }           
} 
Function Remove-DriveAccount {

    param(
	[string] $accountName,
	[string] $Drive
	)
    $colRights = [System.Security.AccessControl.FileSystemRights]"Read" 

    $InheritanceFlag = [System.Security.AccessControl.InheritanceFlags]::None
    $PropagationFlag = [System.Security.AccessControl.PropagationFlags]::None 

    $objType =[System.Security.AccessControl.AccessControlType]::Allow 

    $objUser = New-Object System.Security.Principal.NTAccount($accountName) 

    $objACE = New-Object System.Security.AccessControl.FileSystemAccessRule `
    ($objUser, $colRights, $InheritanceFlag, $PropagationFlag, $objType) 

    $objACL = Get-ACL $Drive 
    $objACL.RemoveAccessRuleAll($objACE) 

    Set-ACL $Drive $objACL
}
Function Add-DriveAccount{
    param(
	[string] $accountName,
	[string] $Drive
	)
    
    $colRights = [System.Security.AccessControl.FileSystemRights]"ListDirectory, `
    ReadAndExecute, ReadAttributes, ReadExtendedAttributes, ReadPermissions, Traverse"
    $InheritanceFlag = [System.Security.AccessControl.InheritanceFlags]"ContainerInherit, ObjectInherit"
    $PropagationFlag = [System.Security.AccessControl.PropagationFlags]::None 

    $objType =[System.Security.AccessControl.AccessControlType]::Allow 

    $objUser = New-Object System.Security.Principal.NTAccount($accountName) 

    $objACE = New-Object System.Security.AccessControl.FileSystemAccessRule `
    ($objUser, $colRights, $InheritanceFlag, $PropagationFlag, $objType) 

    $objACL = Get-ACL $Drive 
    $objACL.AddAccessRule($objACE) 

    Set-ACL $Drive $objACL
}
Function Set-TimeZone { 
    param( 
        [parameter(Mandatory=$true)] 
        [string]$TimeZone 
    ) 
Write-Host "Setting Time Zone" -Fore Yellow -NoNewLine     
    $osVersion = (Get-Item "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion").GetValue("CurrentVersion") 
    $proc = New-Object System.Diagnostics.Process 
    $proc.StartInfo.WindowStyle = "Hidden" 
 
    if ($osVersion -ge 6.0) 
    { 
        # OS is newer than XP 
        $proc.StartInfo.FileName = "tzutil.exe" 
        $proc.StartInfo.Arguments = "/s `"$TimeZone`"" 
    } 
    else 
    { 
        # XP or earlier 
        $proc.StartInfo.FileName = $env:comspec 
        $proc.StartInfo.Arguments = "/c start /min control.exe TIMEDATE.CPL,,/z $TimeZone" 
    } 
    $proc.Start() | Out-Null 
Write-Host " ...Complete" -Fore Green
}
Function CreateDLogsFolder {
    New-Item -Path D:\Logs -ItemType directory
}
Function Exit {
Exit-PSSession
} 
Function offlinedisks {
Get-Disk | Where-Object {$_.OperationalStatus -eq "Offline"} | Initialize-Disk -PartitionStyle GPT -PassThru | New-Partition -AssignDriveLetter -UseMaximumSize | Format-Volume -FileSystem NTFS -Confirm:$false
}
Function notinitializeddisks {
Get-Disk | Where-Object {$_.PartitionStyle -eq "RAW"} | Initialize-Disk -PartitionStyle GPT -PassThru | New-Partition -AssignDriveLetter -UseMaximumSize | Format-Volume -FileSystem NTFS -Confirm:$false
}
Function expandpart {
    $MaxSize = (Get-PartitionSupportedSize -DriveLetter $deviceDL).sizeMax
    Resize-Partition -DriveLetter $deviceDL -Size $MaxSize
    Write-Verbose " ...Expansion Complete" -Fore Green;start-Sleep -Seconds 0
}
Function DNS2008 {
	netsh interface ip set dns name="Private" static $DNSp
	netsh interface ip add dns name="Private" $DNSs index=2
}
Function DNS2012 {
	netsh interface ip set dns name="Private" static $DNSp
	netsh interface ip add dns name="Private" $DNSs index=2
}
Function Confirmdns {
netsh interface ip show dns "Private"
}
Function Add-DriveAccount {

    param(
		[string] $accountName,
		[string] $drivePath
	)
    
    $colRights = [System.Security.AccessControl.FileSystemRights]"FullControl"
    $InheritanceFlag = [System.Security.AccessControl.InheritanceFlags]"ContainerInherit, ObjectInherit"
    $PropagationFlag = [System.Security.AccessControl.PropagationFlags]::None 
    $objType =[System.Security.AccessControl.AccessControlType]::Allow 

    $objUser = New-Object System.Security.Principal.NTAccount($accountName) 

    $objACE = New-Object System.Security.AccessControl.FileSystemAccessRule `
    ($objUser, $colRights, $InheritanceFlag, $PropagationFlag, $objType) 

    $objACL = Get-ACL $drivePath 
    $objACL.AddAccessRule($objACE) 

    Set-ACL $drivePath $objACL
}
Function Remove-DriveAccount {
    param([string] $accountName)
    $colRights = [System.Security.AccessControl.FileSystemRights]"Read" 

    $InheritanceFlag = [System.Security.AccessControl.InheritanceFlags]::None
    $PropagationFlag = [System.Security.AccessControl.PropagationFlags]::None 

    $objType =[System.Security.AccessControl.AccessControlType]::Allow 

    $objUser = New-Object System.Security.Principal.NTAccount($accountName) 

    $objACE = New-Object System.Security.AccessControl.FileSystemAccessRule `
    ($objUser, $colRights, $InheritanceFlag, $PropagationFlag, $objType) 

    $objACL = Get-ACL "D:\" 
    $objACL.RemoveAccessRuleAll($objACE) 

    Set-ACL "D:\" $objACL
}
Function Add-DriveAccount {
    param([string] $accountName)
    
    $colRights = [System.Security.AccessControl.FileSystemRights]"ListDirectory, `
    ReadAndExecute, ReadAttributes, ReadExtendedAttributes, ReadPermissions, Traverse"
    $InheritanceFlag = [System.Security.AccessControl.InheritanceFlags]"ContainerInherit, ObjectInherit"
    $PropagationFlag = [System.Security.AccessControl.PropagationFlags]::None 

    $objType =[System.Security.AccessControl.AccessControlType]::Allow 

    $objUser = New-Object System.Security.Principal.NTAccount($accountName) 

    $objACE = New-Object System.Security.AccessControl.FileSystemAccessRule `
    ($objUser, $colRights, $InheritanceFlag, $PropagationFlag, $objType) 

    $objACL = Get-ACL "D:\" 
    $objACL.AddAccessRule($objACE) 

    Set-ACL "D:\" $objACL
}
Function Replace-String {
    param([string]$FilePath, [string]$pattern, [string]$replacement)
    
    $text = Get-Content -Path $FilePath
    if($text -match $pattern)
    {
    $text -replace $pattern, $replacement | out-file -encoding ascii $FilePath
    }
}
Function LMHOST {

    $wmiNACfg = [wmiclass]'Win32_NetworkAdapterConfiguration'
    $wmiNACfg.enablewins($false,$false)
}
Function NETBIOS {

    $nics = gwmi Win32_NetworkAdapterConfiguration | where {$_.IPEnabled -eq $true}
    foreach ($nic in $nics) {
      $nic.settcpipnetbios(1)
      $nic.SetDynamicDNSRegistration($TRUE)
      }
}
Function NICRENAME {
$nic1 = Get-NetAdapterHardwareInfo | Sort-Object Bus,Function | Select -First 1
$nic2 = Get-NetAdapterHardwareInfo | Sort-Object Bus,Function | Select -Last 1
If ($nic1.name -eq $nic2.name) {
Write-Verbose " | 1 NIC detected | " -Fore White -nonewline;start-Sleep -Seconds 0
Get-NetAdapter | Select -First 1 | Rename-NetAdapter -NewName Private
}
ElseIf ($nic1.name -ne $nic2.name) {
Write-Verbose " | 2 NICs detected | " -Fore White -nonewline;start-Sleep -Seconds 0
Get-NetAdapter | Select -First 1 | Rename-NetAdapter -NewName Private
Get-NetAdapter | Select -Last 1 | Rename-NetAdapter -NewName Public
}
Else {
}
}
Function NICRENAME2008 {

    $nic1 = Get-WmiObject -class win32_networkadapter -filter "NetConnectionStatus = 2" | Select -First 1
    $nic2 = Get-WmiObject -class win32_networkadapter -filter "NetConnectionStatus = 2" | Select -Last 1

    If ($nic1.DeviceID -eq $nic2.DeviceID) 
    {
        Write-Verbose " | 1 NIC detected | " -Fore White -nonewline;start-Sleep -Seconds 0
        $newname1 = "Private"
        $nic1.NetConnectionID = $newname1
        $nic1.Put()
    }
    ElseIf ($nic1.DeviceID -ne $nic2.DeviceID) 
    {
        Write-Verbose " | 2 NICs detected | " -Fore White -nonewline;start-Sleep -Seconds 0
        $newname1 = "Private"
        $nic1.NetConnectionID = $newname1
        $nic1.Put()
        $newname2 = "Public"
        $nic2.NetConnectionID = $newname2
        $nic2.Put()
    }
}
Function Disable-Firewall {

    IF (($OSversion -eq "2012R2") -or ($OSversion -eq "2012"))
    {
        Write-Host "Turning off Firewall ($OSversion)" -Fore Yellow -NoNewLine
        Get-NetFirewallProfile | Set-NetFirewallProfile -Enabled False
		Write-Host " ...Complete" -Fore Green
    }
	ElseIf (($OSversion -eq "2008R2") -or ($OSversion -eq "2008"))
	{
	    Write-Host "Turning off Firewall ($OSversion)" -Fore Yellow -NoNewLine
        netsh advfirewall set allprofiles state off > $null
		Write-Host " ...Complete" -Fore Green
	}
	Else
	{
	}
}
Function Change-CDromDriveLetter {

    Write-Host "Change CD Rom letter to R" -Fore Yellow -NoNewLine
    (gwmi Win32_cdromdrive).drive | %{$a=mountvol $_ /l;mountvol $_ /d;$a=$a.Trim();mountvol r: $a}
	Write-Host " ...Complete" -Fore Green
}
Function Configure-WindowsUpdateSettings {
    Write-Host "Change Windows Update to Never Check for Updates" -Fore Yellow -NoNewLine
    $UpdateValue = 1
    $AutoUpdatePath = "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\WindowsUpdate\Auto Update"
    Set-ItemProperty -Path $AutoUpdatePath -Name AUOptions -Value $UpdateValue
	Write-Host " ...Complete" -Fore Green
}
Function Enable-RemoteDesktop {
    Write-Host "Enable Remote Desktop" -Fore Yellow -NoNewLine
    $regKey = "HKLM:\SYSTEM\CurrentControlSet\Control\Terminal Server"
    Set-ItemProperty $regKey fDenyTsConnections 0
	Write-Host " ...Complete" -Fore Green
}
Function Configure-EventLogSettings {
    Write-Host "Set event log attributes" -Fore Yellow -NoNewLine
    Limit-EventLog -LogName Application -MaximumSize 65536kb -OverflowAction OverwriteAsNeeded
    Limit-EventLog -LogName Security -MaximumSize 81920kb -OverflowAction OverwriteAsNeeded
    Limit-EventLog -LogName System -MaximumSize 65536kb -OverflowAction OverwriteAsNeeded
	Write-Host " ...Complete" -Fore Green
}
Function Disable-UAC {
    Write-Host "Turn Off UAC" -Fore Yellow -NoNewLine
    Set-ItemProperty -path "HKLM:SOFTWARE\Microsoft\Windows\CurrentVersion\policies\system" -name EnableLUA -value 0
	Write-Host " ...Complete" -fore Green
}
Function Disable-ServerManagerSplashScreen {
    Write-Host "Turn Off Server Manager From Opening Automatically On Startup" -Fore Yellow -NoNewLine
    Set-ItemProperty -path "HKLM:SOFTWARE\Microsoft\ServerManager" -name DoNotOpenServerManagerAtLogon -value 1
    Set-ItemProperty -path "HKLM:SOFTWARE\Microsoft\ServerManager\Oobe" -name DoNotOpenInitialConfigurationTasksAtLogon -value 1
	Write-Host " ...Complete" -Fore Green
}
Function Configure-IconsAndNotifications {
    Write-Host "Always Show Icons and Notifications" -Fore Yellow -NoNewLine
    New-RegistryKey "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer" "EnableAutoTray" "Dword" "0"
	Write-Host " ...Complete" -Fore Green
}
Function Configure-SNMPRegistrySettings {
    Write-Host "SNMP configuration" -Fore Yellow -NoNewLine
    RegAction "RegWrite" "HKLM:\SYSTEM\CurrentControlSet\services\SNMP\Parameters\PermittedManagers" "1" "156.45.55.61" "String"
    RegAction "RegWrite" "HKLM:\SYSTEM\CurrentControlSet\services\SNMP\Parameters\PermittedManagers" "2" "127.0.0.1" "String"
    RegAction "RegWrite" "HKLM:\SYSTEM\CurrentControlSet\services\SNMP\Parameters\PermittedManagers" "3" "156.45.55.117" "String"
    RegAction "RegWrite" "HKLM:\SYSTEM\CurrentControlSet\services\SNMP\Parameters\TrapConfiguration\NetManagers" "1" "156.45.55.117" "String"
    RegAction "RegWrite" "HKLM:\SYSTEM\CurrentControlSet\services\SNMP\Parameters\TrapConfiguration\NetManagers" "2" "156.45.55.61" "String"
    RegAction "RegWrite" "HKLM:\SYSTEM\CurrentControlSet\services\SNMP\Parameters\ValidCommunities" "NetManagers" "8" "Dword"
    RegAction "RegWrite" "HKLM:\SYSTEM\CurrentControlSet\services\SNMP\Parameters\ValidCommunities" "Public" "1" "Dword"
	Write-Host " ...Complete" -Fore Green
}
Function Configure-DisableIPV6RegistrySettings {
    Write-Host "Disabling IPV6" -Fore Yellow -NoNewLine
    RegAction "RegWrite" "HKLM:\SYSTEM\CurrentControlSet\Services\Tcpip6\Parameters" "DisabledComponents" "0xFFFFFFFF" "DWord"
	Write-Host " ...Complete" -Fore Green
}
Function Configure-DriverSigningPolicyRegistrySettings {
    Write-Host "Driver Signing Policy setting" -Fore Yellow -NoNewLine
    RegAction "RegWrite" "HKLM:\SOFTWARE\Microsoft\Driver Signing" "Policy" "01" "Binary"
	Write-Host " ...Complete" -Fore Green
}
Function Configure-ProtocolRegistrySettings {
    Write-Host "Protocol Settings" -Fore Yellow -NoNewLine
    RegAction "RegWrite" "HKLM:\SYSTEM\CurrentControlSet\Control\SecurityProviders\SCHANNEL\Protocols\PCT 1.0\Client" "Enabled" "0" "DWord"
    RegAction "RegWrite" "HKLM:\SYSTEM\CurrentControlSet\Control\SecurityProviders\SCHANNEL\Protocols\PCT 1.0\Server" "Enabled" "0" "DWord"
    RegAction "RegWrite" "HKLM:\SYSTEM\CurrentControlSet\Control\SecurityProviders\SCHANNEL\Protocols\SSL 2.0\Client" "Enabled" "0" "DWord"
    RegAction "RegWrite" "HKLM:\SYSTEM\CurrentControlSet\Control\SecurityProviders\SCHANNEL\Protocols\SSL 2.0\Server" "Enabled" "0" "DWord"
	Write-Host " ...Complete" -Fore Green
} 
Function Configure-NullSessionShareRegistrySettings {
    Write-Host "Null Session Shares" -Fore Yellow -NoNewLine
    RegAction "RegWrite" "HKLM:\SYSTEM\CurrentControlSet\Services\LanmanServer\Parameters" "NullSessionShares" "7" "Binary"
	Write-Host " ...Complete" -Fore Green
}
Function Configure-DisksWithNoPartitions {

    $drives = gwmi Win32_diskdrive
    $scriptdisk = $Null
    $script = $Null
    $OSversion = (((Get-WmiObject Win32_operatingsystem).version).ToString()).Split('.')[0]

    foreach ($disk in $drives)
    {
        if ($disk.Partitions -eq "0")
        {
            $drivenumber = $disk.DeviceID -replace '[\\\\\.\\physicaldrive]',''
    
            If ($OSversion -eq "5")
            {
                $script = @"
                select disk $drivenumber
                online noerr
                create partition primary noerr
"@
            }
            ElseIf ($OSversion -eq "6")
            {
                $script = @"
                select disk $drivenumber
                online disk noerr
                attributes disk clear readonly noerr
                create partition primary noerr
                format quick
"@
            }
        }

        $drivenumber = $Null
        $scriptdisk += $script + "`n"
    }

    $scriptdisk | diskpart
}
Function LetterAndLabelDrives {
    #(http://powershell.com/cs/blogs/tips/archive/2009/01/15/enumerating-drive-letters.aspx)
    $volumes = gwmi Win32_volume | where {$_.BootVolume -ne $True -and $_.SystemVolume -ne $True}
    $letters = 68..89 | ForEach-Object { ([char]$_)+":" }
    $freeletters = $letters | Where-Object { 
      (New-Object System.IO.DriveInfo($_)).DriveType -eq 'NoRootDirectory'
    }
    foreach ($volume in $volumes){
        if ($volume.DriveLetter -eq $Null){
            If ($OSVersion -eq "5"){
              mountvol $freeletters[0] $volume.DeviceID
              format $freeletters[0] /FS:NTFS /q /y
            }
            Else {
                mountvol $freeletters[0] $volume.DeviceID    
            }    
        }
    $freeletters = $letters | Where-Object { 
        (New-Object System.IO.DriveInfo($_)).DriveType -eq 'NoRootDirectory'
    }
    } 
}
Function Create-LogFolderOnDriveD {
    Write-Host "Creating Logs folder on the D drive" -Fore Yellow -NoNewLine
    $drivepath = Test-Path d:\logs
    If ($drivepath -eq "True") 
    {
        Write-Host " ...Folder already in place"  -Fore Cyan
    }
    Else 
    {
        CreateDLogsFolder | out-null 
    }
}
Function Load-ConfigurationFromRegistry {
}
Function PostScripts {


# ================================================================================================================================== #
# Initializing Roles and Features
# ================================================================================================================================== #

Write-Host "`n*----  Installation of Roles and Features  ----*`n" -Fore Magenta;start-Sleep -Seconds 0
LogWrite = "Calling C:\Scripts\Provisioning\12_RolesFeatures\RolesAndFeatures.ps1"
powershell -File "D:\Scripts\Provisioning\RemoteFunctions\rCmd+.ps1" -UseAdmin -UseHTTP -ComputerName $targetComputer -ScriptBlock "C:\Scripts\Provisioning\12_RolesFeatures\RolesAndFeatures.ps1 -ServerType $servertype" 
LogWrite "Roles and Features Complete"

# ================================================================================================================================== #
# Setting PageFile & Basic Drive Permissions if "base" or "sql"
# ================================================================================================================================== #

If (($servertype -eq "base") -or ($servertype -eq "sql")){
	Write-Host "`n*----  Setting PageFile & Basic Drive Permissions  ----*`n" -Fore Magenta;start-Sleep -Seconds 3 
	LogWrite "Calling C:\Scripts\Provisioning\1_W2k8_PostTemplate\Master_Powershell_Base.ps1"
	powershell -File "D:\Scripts\Provisioning\RemoteFunctions\rCmd+.ps1" -UseAdmin -UseHTTP -ComputerName $targetComputer -ScriptBlock "C:\Scripts\Provisioning\1_W2k8_PostTemplate\Master_Powershell_Base.ps1"  
	LogWrite "[ Setting PageFile & Basic Drive Permissions ] Complete"
    Write-Host " ...Complete" -Fore Green;start-Sleep -Seconds 0
}

# ================================================================================================================================== #
# Setting PageFile & Basic Drive Permissions if "web"
# ================================================================================================================================== #

ElseIf ($servertype -eq "web") {
	Write-Host "`n*----  Installing IIS since the Web role was selected  ----*`n" -Fore Magenta;start-Sleep -Seconds 3 
    LogWrite "Calling C:\Scripts\Provisioning\1_W2k8_PostTemplate\Master_Powershell_IIS.ps1"
    powershell -File "D:\Scripts\Provisioning\RemoteFunctions\rCmd+.ps1" -UseAdmin -UseHTTP -ComputerName $targetComputer -ScriptBlock "C:\Scripts\Provisioning\1_W2k8_PostTemplate\Master_Powershell_IIS.ps1" 
    LogWrite "[ IIS Full installation ] Complete"
    Write-Host "`n...IIS Role installed" -Fore Green;start-Sleep -Seconds 0
}
Else {
}

# ================================================================================================================================== #
# Configuring Nic(s)
# ================================================================================================================================== #

Write-Host "`n*----  Configuring Networking on [ $targetComputer ]  ----*`n" -Fore Magenta;start-Sleep -Seconds 3 
LogWrite "Calling D:\Scripts\Provisioning\2_NetworkConfig\NicConfig.ps1"
powershell -File "D:\Scripts\Provisioning\RemoteFunctions\rScript+.ps1" -UseAdmin -UseHTTP -ComputerName $targetComputer -FilePath D:\Scripts\Provisioning\2_NetworkConfig\NicConfig.ps1 -ArgumentList $PrivateIP 
LogWrite "[ Configuring Networking ] Complete"

# ================================================================================================================================== #
# Joining Domain
# ================================================================================================================================== #

Write-Host "`n*----  Joining the [ $Domain ] Domain  ----*`n" -Fore Magenta;start-Sleep -Seconds 3 
LogWrite "Calling C:\Scripts\Provisioning\4_JoinDomain\JoinDomain.ps1"
powershell -File "D:\Scripts\Provisioning\RemoteFunctions\rCmd+.ps1" -UseAdmin -UseHTTP -ComputerName $targetComputer -ScriptBlock "C:\Scripts\Provisioning\4_JoinDomain\JoinDomain.ps1 -Domain $Domain -OU $OU" 
LogWrite "[ Joining %Domain Domain ] Complete"

# ================================================================================================================================== #
# Reboot Computer
# ================================================================================================================================== #

Write-Host "`n*----  Rebooting [ $targetComputer ]  ----*`n" -Fore Magenta;start-Sleep -Seconds 3 
LogWrite "Restarting Remote Server"
powershell -File "D:\Scripts\Provisioning\RemoteFunctions\rCmd+.ps1" -UseAdmin -UseHTTP -ComputerName $targetComputer -ScriptBlock 'Restart-Computer -Confirm:$False -Force' 
Write-Host "`nRebooting Server" -Fore Yellow -nonewline;start-Sleep -Seconds 0
Do {Start-Sleep -s 30}
Until (test-connection $targetComputer -quiet)
Write-Host " ...Complete" -Fore Green;start-Sleep -Seconds 0
LogWrite "Restart Complete"

# ================================================================================================================================== #
# Install Base SQL config
# ================================================================================================================================== #
If ($servertype -eq "sql") {
Write-Host "`n*----  Installation Sql Base Config  ----*`n" -Fore Magenta;start-Sleep -Seconds 0
LogWrite = "Calling C:\Scripts\Provisioning\SQL\Base_Sql_Config.ps1"
powershell -File "D:\Scripts\Provisioning\RemoteFunctions\rCmd+.ps1" -UseAdmin -UseHTTP -ComputerName $targetComputer -ScriptBlock "C:\Scripts\Provisioning\SQL\Base_Sql_Config.ps1" 
LogWrite "Base Sql Config Complete"
}
Else {}

# ================================================================================================================================== #
# Adding Server Ops Security
# ================================================================================================================================== #

Write-Host "`n*----  Adding Server_Ops Security to [ $targetComputer ] ----*`n" -Fore Magenta;start-Sleep -Seconds 0
LogWrite "Calling D:\Scripts\Provisioning\5_AddServerOps\AddServerOps.ps1"
powershell -File "D:\Scripts\Provisioning\RemoteFunctions\rScript+.ps1" -UseAdmin -UseHTTP -ComputerName $targetComputer -FilePath D:\Scripts\Provisioning\5_AddServerOps\AddServerOps.ps1 
LogWrite "[ Adding Server_Ops Security ] Complete"

# ================================================================================================================================== #
# Reboot Computer
# ================================================================================================================================== #

Write-Host "`n*----  Rebooting [ $targetComputer ]  ----*`n" -Fore Magenta;start-Sleep -Seconds 0 
LogWrite "Restarting Remote Server"
Write-Host "`nRebooting Server" -Fore Yellow -nonewline;start-Sleep -Seconds 0
Restart-Computer -Computername "$targetComputer" -Wait -For Wmi
Write-Host " ...Complete" -Fore Green;start-Sleep -Seconds 0
LogWrite "Restart Complete"

# ================================================================================================================================== #
# Updating Windows
# ================================================================================================================================== #

Write-Host "`n*----  Performing Windows Updates on [ $targetComputer ] ----*`n" -Fore Magenta;start-Sleep -Seconds 0 
LogWrite "Calling C:\Scripts\Provisioning\WinUpdates\launch.ps1"
powershell -File "D:\Scripts\Provisioning\RemoteFunctions\rCmd+.ps1" -UseAdmin -UseHTTP -ComputerName $targetComputer -ScriptBlock "C:\Scripts\Provisioning\WinUpdates\launch.ps1" 
LogWrite "[ Windows Update ] Complete"

# ================================================================================================================================== #
# Reboot Computer
# ================================================================================================================================== #

Write-Host "`n*----  Rebooting [ $targetComputer ]  ----*`n" -Fore Magenta;start-Sleep -Seconds 0 
LogWrite "Restarting Remote Server"
Write-Host "`nRebooting Server" -Fore Yellow -nonewline;start-Sleep -Seconds 0
Restart-Computer -Computername "$targetComputer" -Wait -For Wmi
Write-Host " ...Complete" -Fore Green;start-Sleep -Seconds 0
LogWrite "Restart Complete"

# ================================================================================================================================== #
# Updating Windows
# ================================================================================================================================== #

Write-Host "`n*----  Performing Windows Updates on [ $targetComputer ] ----*`n" -Fore Magenta;start-Sleep -Seconds 0 
LogWrite "Calling C:\Scripts\Provisioning\WinUpdates\launch.ps1"
powershell -File "D:\Scripts\Provisioning\RemoteFunctions\rCmd+.ps1" -UseAdmin -UseHTTP -ComputerName $targetComputer -ScriptBlock "C:\Scripts\Provisioning\WinUpdates\launch.ps1" 
LogWrite "[ Windows Update ] Complete"

# ================================================================================================================================== #
# Reboot Computer
# ================================================================================================================================== #

Write-Host "`n*----  Rebooting [ $targetComputer ]  ----*`n" -Fore Magenta;start-Sleep -Seconds 0 
LogWrite "Restarting Remote Server"
Write-Host "`nRebooting Server" -Fore Yellow -nonewline;start-Sleep -Seconds 0
Restart-Computer -Computername "$targetComputer" -Wait -For Wmi
Write-Host " ...Complete" -Fore Green;start-Sleep -Seconds 0
LogWrite "Restart Complete"

# ================================================================================================================================== #
# Wincollect Installation
# ================================================================================================================================== #

If ($wincollect -eq "yes") {
Write-Host "`n*----  Installing Wincollect on [ $targetComputer ]  ----*`n" -Fore Magenta;start-Sleep -Seconds 0
LogWrite "Calling C:\Scripts\Provisioning\WinCollect\InstallWincollect.ps1"
powershell -File "D:\Scripts\Provisioning\RemoteFunctions\rCmd+.ps1" -UseAdmin -UseHTTP -ComputerName $targetComputer -ScriptBlock "C:\Scripts\Provisioning\WinCollect\InstallWincollect.ps1"
LogWrite "[ Installing Wincollect ] Complete"
}
Else {
}

# ================================================================================================================================== #
# Certification Request and Import
# ================================================================================================================================== #

Write-Host "`n*----  Requesting and Importing Certs for [ $targetComputer ]  ----*`n" -Fore Magenta;start-Sleep -Seconds 0
Logwrite "Calling D:\Scripts\Provisioning\6_CertRequest\ServerCertRequest.ps1"
powershell -File "D:\Scripts\Provisioning\6_CertRequest\ServerCertRequest.ps1" -ComputerName $targetComputer 
LogWrite "[ Requesting Cert & Importing ] Complete"
Write-Host "...Cert Work Complete" -Fore Green;start-Sleep -Seconds 0

# ================================================================================================================================== #
# Enabling Powershell over HTTPS
# ================================================================================================================================== #

Write-Host "`n*----  Enabling Powershell over HTTPS on [ $targetComputer ]  ----*`n" -Fore Magenta;start-Sleep -Seconds 0
LogWrite "Calling C:\Scripts\Provisioning\7_WinRMHTTPS\ScheduleENABLE.ps1"
powershell -File "D:\Scripts\Provisioning\RemoteFunctions\rCmd+.ps1" -UseAdmin -UseHTTP -ComputerName $targetComputer -ScriptBlock "C:\Scripts\Provisioning\7_WinRMHTTPS\ScheduleENABLE.ps1" 
LogWrite "[ Enable Powershell Remoting over HTTPS ] Complete"

# ================================================================================================================================== #
# Disabling Powershell Remoting over HTTP
# ================================================================================================================================== #

Write-Host "`n*----  Disabling Powershell Remoting over HTTP on [ $targetComputer ]  ----*`n" -Fore Magenta;start-Sleep -Seconds 0
LogWrite "Calling C:\Scripts\Provisioning\7_WinRMHTTPS\ScheduleDISABLE.ps1"
powershell -File "D:\Scripts\Provisioning\RemoteFunctions\rCmd+.ps1" -UseRunBook -ComputerName $targetComputer -ScriptBlock "C:\Scripts\Provisioning\7_WinRMHTTPS\ScheduleDISABLE.ps1" 
LogWrite "[ Disabling Powershell Remoting over HTTP ] Complete"

# ================================================================================================================================== #
# Performing FTP procedures if "ftp" or "web"
# ================================================================================================================================== #

If (($servertype -eq "ftp") -or ($servertype -eq "web")) {
Write-Host "`n*----  Performing FTPIP Procedures on [ $targetComputer ]  ----*`n" -Fore Magenta;start-Sleep -Seconds 0
LogWrite "Calling D:\Scripts\Provisioning\9_BaseFTPSite\BaseFTPSite.ps1"
powershell -File "D:\Scripts\Provisioning\RemoteFunctions\rScript+.ps1" -UseRunBook -ComputerName $targetComputer -FilePath D:\Scripts\Provisioning\9_BaseFTPSite\BaseFTPSite.ps1 -ArgumentList $ftpIP 
LogWrite "[ If FTP add FTPIP procedure ] Complete"
Write-Host "`n...FTPIP Procedure complete" -Fore Green;start-Sleep -Seconds 0
}
Else {
}

# ================================================================================================================================== #
# Renaming Admin and Guest Accounts
# ================================================================================================================================== #

Write-Host "`n*----  Renaming Admin & Guest Accounts on [ $targetComputer ]  ----*`n" -Fore Magenta;start-Sleep -Seconds 0
LogWrite "Calling C:\Scripts\Provisioning\1_W2k8_PostTemplate\LocalAccount_PS_config.ps1"
powershell -File "D:\Scripts\Provisioning\RemoteFunctions\rCmd+.ps1" -UseRunBook -ComputerName $targetComputer -ScriptBlock "C:\Scripts\Provisioning\1_W2k8_PostTemplate\LocalAccount_PS_config.ps1" 
LogWrite "[ Renaming Admin & Guest accounts ] Complete"

# ================================================================================================================================== #
# Reboot Computer
# ================================================================================================================================== #

Write-Host "`n*----  Rebooting [ $targetComputer ]  ----*`n" -Fore Magenta;start-Sleep -Seconds 0 
LogWrite "Restarting Remote Server"
Write-Host "`nRebooting Server" -Fore Yellow -nonewline;start-Sleep -Seconds 0
Restart-Computer -Computername "$targetComputer" -Wait -For Wmi
Write-Host " ...Complete" -Fore Green;start-Sleep -Seconds 0
LogWrite "Restart Complete"

# ================================================================================================================================== #
# Completion Message
# ================================================================================================================================== #

write-host "`n`t           ___________________________________________________________________________________" -fore green;start-Sleep -Seconds 0
write-host "`t  ________|                                                                                   |_______" -fore green;start-Sleep -Seconds 0
write-host "`t  \       |                    Server Installation & Provisioning is complete                 |      /" -fore green;start-Sleep -Seconds 0
write-host "`t   \      |                                                                                   |     /" -fore green;start-Sleep -Seconds 0
write-host "`t    \     |                                                                                   |    /" -fore green;start-Sleep -Seconds 0
write-host "`t    /     |     Install log for this install can be found at C:\Scripts\Logs\installlogs\     |    \" -fore green;start-Sleep -Seconds 0
write-host "`t   /      |___________________________________________________________________________________|     \" -fore green;start-Sleep -Seconds 0
write-host "`t  /__________)                                                                             (_________\" -fore green;start-Sleep -Seconds 0
write-host ""

}
Function PlaceUtilsFolder {
write-host "Placing Utils Folder" -Fore Yellow -nonewline
Copy-Item -Recurse C:\Scripts\Provisioning\dependencies\utils D:\Ops_Temp -force
write-host " ...Complete" -Fore Green
}
Function RolesandFeatures {
Import-Module servermanager
IF (($OSversion -eq "2012R2") -or ($OSversion -eq "2012")){
Switch ($ServerType) {
	"SQL" {
		Write-Host "[ 2012 Roles & Features SQL - Start]" -Fore Cyan;start-Sleep -Seconds 0
		Write-Host "Installing .NET 3.5" -Fore Yellow ;start-Sleep -Seconds 0
		Install-WindowsFeature NET-Framework-Core > $null
		Write-Host "....Complete" -Fore Green ;start-Sleep -Seconds 0 
		Write-Host "[ 2012 Roles & Features SQL - End]" -Fore Cyan;start-Sleep -Seconds 0
		}
	"WEB" { 
		Write-Host "[ 2012 Roles & Features WEB - Start ]" -Fore Cyan;start-Sleep -Seconds 0
		Write-Host "Installing Windows Feature < Web-Server >" -Fore Yellow ;start-Sleep -Seconds 0
		Install-WindowsFeature -Name Web-Server > $null
		Write-Host "....Complete`n" -Fore Green ;start-Sleep -Seconds 0 
				
		Write-Host "Installing Windows Feature < Web-Http-Redirect >" -Fore Yellow;start-Sleep -Seconds 0
		Install-WindowsFeature -Name Web-Http-Redirect > $null
		Write-Host "....Complete`n" -Fore Green ;start-Sleep -Seconds 0 
				
		Write-Host "Uninstalling Windows Feature < Web-Dir-Browsing >" -Fore Yellow;start-Sleep -Seconds 0
		Uninstall-WindowsFeature -Name Web-Dir-Browsing > $null
		Write-Host "....Complete`n" -Fore Green ;start-Sleep -Seconds 0 

		Write-Host "Installing Windows Feature < Web-Health >" -Fore Yellow;start-Sleep -Seconds 0
		Install-WindowsFeature -Name Web-Health -IncludeAllSubFeature > $null
		Write-Host "....Complete`n" -Fore Green ;start-Sleep -Seconds 0 
				
		Write-Host "Uninstalling Windows Feature < Web-Custom-Logging >" -Fore Yellow;start-Sleep -Seconds 0
		Uninstall-WindowsFeature -Name Web-Custom-Logging > $null
		Write-Host "....Complete`n" -Fore Green ;start-Sleep -Seconds 0 
				
		Write-Host "Uninstalling Windows Feature < Web-Http-Tracing >" -Fore Yellow;start-Sleep -Seconds 0
		Uninstall-WindowsFeature -Name Web-Http-Tracing > $null
		Write-Host "....Complete`n" -Fore Green ;start-Sleep -Seconds 0 
				
		Write-Host "Installing Windows Feature < Web-IP-Security >" -Fore Yellow;start-Sleep -Seconds 0
		Install-WindowsFeature -Name Web-IP-Security > $null
		Write-Host "....Complete`n" -Fore Green ;start-Sleep -Seconds 0 
				
		Write-Host "Installing Windows Feature < Web-App-Dev >" -Fore Yellow;start-Sleep -Seconds 0
		Install-WindowsFeature -Name Web-App-Dev -IncludeAllSubFeature > $null
		Write-Host "....Complete`n" -Fore Green ;start-Sleep -Seconds 0 
				
		Write-Host "Uninstalling Windows Feature < Web-AppInit >" -Fore Yellow;start-Sleep -Seconds 0
		Uninstall-WindowsFeature -Name Web-AppInit > $null
		Write-Host "....Complete`n" -Fore Green ;start-Sleep -Seconds 0 
				
		Write-Host "Uninstalling Windows Feature < Web-WebSockets >" -Fore Yellow;start-Sleep -Seconds 0
		Uninstall-WindowsFeature -Name Web-WebSockets > $null
		Write-Host "....Complete`n" -Fore Green ;start-Sleep -Seconds 0 
				
		Write-Host "Installing Windows Feature < Web-Mgmt-Tools >" -Fore Yellow;start-Sleep -Seconds 0
		Install-WindowsFeature -Name Web-Mgmt-Tools -IncludeAllSubFeature > $null
		Write-Host "....Complete`n" -Fore Green ;start-Sleep -Seconds 0 
				
		Write-Host "Installing Windows Feature < SMTP-Server >" -Fore Yellow;start-Sleep -Seconds 0
		Install-WindowsFeature -Name SMTP-Server -IncludeManagementTools > $null
		Write-Host "....Complete`n" -Fore Green ;start-Sleep -Seconds 0 
		
		Write-Host "Installing Windows Feature < Web-Ftp-Service >" -Fore Yellow ;start-Sleep -Seconds 0
		Install-WindowsFeature -name Web-Ftp-Service > $null
		Write-Host "....Complete`n" -Fore Green ;start-Sleep -Seconds 0
		
		Write-Host "Installing Windows Feature < Web-Mgmt-Tools >" -Fore Yellow ;start-Sleep -Seconds 0
		Install-WindowsFeature -Name Web-Mgmt-Tools -IncludeAllSubFeature > $null
		Write-Host "....Complete`n" -Fore Green ;start-Sleep -Seconds 0
		
		Write-Host "Installing Windows Feature < Web-Ftp-Service >" -Fore Yellow ;start-Sleep -Seconds 0
		Install-WindowsFeature -name Web-Ftp-Service > $null
		Write-Host "....Complete`n" -Fore Green ;start-Sleep -Seconds 0
		
		Write-Host "Installing Windows Feature < Web-Mgmt-Tools >" -Fore Yellow ;start-Sleep -Seconds 0
		Install-WindowsFeature -Name Web-Mgmt-Tools -IncludeAllSubFeature > $null
		Write-Host "....Complete`n" -Fore Green ;start-Sleep -Seconds 0
		Write-Host "[ 2012 Roles & Features WEB - End]" -Fore Cyan;start-Sleep -Seconds 0
	}
	"DC" {
		Write-Host "[ 2012 Roles & Features DC - Start ]" -Fore Cyan;start-Sleep -Seconds 0
		Write-Host "Installing Windows Feature < Ad-Domain-Services >" -Fore Yellow ;start-Sleep -Seconds 0
		Install-WindowsFeature -Name Ad-Domain-Services -IncludeManagementTools > $null
		Write-Host "....Complete`n" -Fore Green ;start-Sleep -Seconds 0
		
		Write-Host "Installing Windows Feature < DNS >" -Fore Yellow ;start-Sleep -Seconds 0		
		Install-WindowsFeature -Name DNS -IncludeManagementTools > $null
		Write-Host "....Complete`n" -Fore Green ;start-Sleep -Seconds 0
		Write-Host "[ 2012 Roles & Features DC - End ]" -Fore Cyan;start-Sleep -Seconds 0
	}  
	"PRINT" {
		Write-Host "[ 2012 Roles & Features PRINT - Start ]" -Fore Cyan;start-Sleep -Seconds 0
		Write-Host "Installing Windows Feature < Print-Server >" -Fore Yellow ;start-Sleep -Seconds 0
		Install-WindowsFeature -Name Print-Server -IncludeManagementTools > $null
		Write-Host "....Complete`n" -Fore Green ;start-Sleep -Seconds 0
		Write-Host "[ 2012 Roles & Features PRINT - End ]" -Fore Cyan;start-Sleep -Seconds 0
	}
	"FTP" {
		Write-Host "[ 2012 Roles & Features FTP - Start ]" -Fore Cyan;start-Sleep -Seconds 0
		Write-Host "Installing Windows Feature < Web-Ftp-Service >" -Fore Yellow ;start-Sleep -Seconds 0
		Install-WindowsFeature -name Web-Ftp-Service > $null
		Write-Host "....Complete`n" -Fore Green ;start-Sleep -Seconds 0
		
		Write-Host "Installing Windows Feature < Web-Mgmt-Tools >" -Fore Yellow ;start-Sleep -Seconds 0
		Install-WindowsFeature -Name Web-Mgmt-Tools -IncludeAllSubFeature > $null
		Write-Host "....Complete`n" -Fore Green ;start-Sleep -Seconds 0
		Write-Host "[ 2012 Roles & Features FTP - End ]" -Fore Cyan;start-Sleep -Seconds 0
	}
	default { 
	} 
}
}
ElseIf (($OSversion -eq "2008R2") -or ($OSversion -eq "2008")){
Switch ($ServerType) {
	"SQL" {
		Write-Host "[ 2008 Roles & Features SQL - Start ]" -Fore Cyan;start-Sleep -Seconds 0
		Write-Host "Installing .NET 3.5" -Fore Yellow -nonewline;start-Sleep -Seconds 0
		Add-WindowsFeature as-net-framework  > $null
		Write-Host "....Complete" -Fore Green ;start-Sleep -Seconds 0 
		Write-Host "[ 2008 Roles & Features SQL - End ]" -Fore Cyan;start-Sleep -Seconds 0
		}
	"WEB" { 
		Write-Host "[ 2008 Roles & Features WEB - Start ]" -Fore Cyan;start-Sleep -Seconds 0
		Write-Host "Installing Windows Feature < Web-Server >" -Fore Yellow -nonewline;start-Sleep -Seconds 0
		Add-WindowsFeature -Name Web-Server  > $null
		Write-Host "....Complete" -Fore Green ;start-Sleep -Seconds 0 
				
		Write-Host "Installing Windows Feature < Web-Http-Redirect >" -Fore Yellow -nonewline;start-Sleep -Seconds 0
		Add-WindowsFeature -Name Web-Http-Redirect  > $null
		Write-Host "....Complete" -Fore Green ;start-Sleep -Seconds 0 
				
		Write-Host "Uninstalling Windows Feature < Web-Dir-Browsing >" -Fore Yellow -nonewline;start-Sleep -Seconds 0
		Remove-WindowsFeature -Name Web-Dir-Browsing  > $null
		Write-Host "....Complete" -Fore Green ;start-Sleep -Seconds 0 

		Write-Host "Installing Windows Feature < Web-Health >" -Fore Yellow -nonewline;start-Sleep -Seconds 0
		Add-WindowsFeature -Name Web-Health -IncludeAllSubFeature  > $null
		Write-Host "....Complete" -Fore Green ;start-Sleep -Seconds 0 
				
		Write-Host "Uninstalling Windows Feature < Web-Custom-Logging >" -Fore Yellow -nonewline;start-Sleep -Seconds 0
		Remove-WindowsFeature -Name Web-Custom-Logging  > $null
		Write-Host "....Complete" -Fore Green ;start-Sleep -Seconds 0 
				
		Write-Host "Uninstalling Windows Feature < Web-Http-Tracing >" -Fore Yellow -nonewline;start-Sleep -Seconds 0
		Remove-WindowsFeature -Name Web-Http-Tracing  > $null
		Write-Host "....Complete" -Fore Green ;start-Sleep -Seconds 0 
				
		Write-Host "Installing Windows Feature < Web-IP-Security >" -Fore Yellow -nonewline;start-Sleep -Seconds 0
		Add-WindowsFeature -Name Web-IP-Security  > $null
		Write-Host "....Complete" -Fore Green ;start-Sleep -Seconds 0 
				
		Write-Host "Installing Windows Feature < Web-App-Dev >" -Fore Yellow -nonewline;start-Sleep -Seconds 0
		Add-WindowsFeature -Name Web-App-Dev -IncludeAllSubFeature  > $null
		Write-Host "....Complete" -Fore Green ;start-Sleep -Seconds 0 
				
		Write-Host "Uninstalling Windows Feature < Web-AppInit >" -Fore Yellow -nonewline;start-Sleep -Seconds 0
		#Remove-WindowsFeature -Name Web-AppInit  > $null
		Write-Host "....Complete" -Fore Green ;start-Sleep -Seconds 0 
				
		Write-Host "Uninstalling Windows Feature < Web-WebSockets >" -Fore Yellow -nonewline;start-Sleep -Seconds 0
		#Remove-WindowsFeature -Name Web-WebSockets  > $null
		Write-Host "....Complete" -Fore Green ;start-Sleep -Seconds 0 
				
		Write-Host "Installing Windows Feature < Web-Mgmt-Tools >" -Fore Yellow -nonewline;start-Sleep -Seconds 0
		Add-WindowsFeature -Name Web-Mgmt-Tools -IncludeAllSubFeature  > $null
		Write-Host "....Complete" -Fore Green ;start-Sleep -Seconds 0 
				
		Write-Host "Installing Windows Feature < SMTP-Server >" -Fore Yellow -nonewline;start-Sleep -Seconds 0
		Add-WindowsFeature -Name SMTP-Server  > $null
		Write-Host "....Complete" -Fore Green ;start-Sleep -Seconds 0 
		
		Write-Host "Installing Windows Feature < Web-Ftp-Service >" -Fore Yellow -nonewline;start-Sleep -Seconds 0
		Add-WindowsFeature -name Web-Ftp-Service  > $null
		Write-Host "....Complete" -Fore Green ;start-Sleep -Seconds 0 

		Write-Host "Installing Windows Feature < Web-Mgmt-Tools >" -Fore Yellow -nonewline;start-Sleep -Seconds 0
		Add-WindowsFeature -Name Web-Mgmt-Tools -IncludeAllSubFeature  > $null
		Write-Host "....Complete" -Fore Green ;start-Sleep -Seconds 0 
		
		Write-Host "Installing Windows Feature < Web-Ftp-Service >" -Fore Yellow -nonewline;start-Sleep -Seconds 0
		Add-WindowsFeature -name Web-Ftp-Service  > $null
		Write-Host "....Complete" -Fore Green ;start-Sleep -Seconds 0 

		Write-Host "Installing Windows Feature < Web-Mgmt-Tools >" -Fore Yellow -nonewline;start-Sleep -Seconds 0
		Add-WindowsFeature -Name Web-Mgmt-Tools -IncludeAllSubFeature  > $null
		Write-Host "....Complete" -Fore Green ;start-Sleep -Seconds 0 
		Write-Host "[ 2008 Roles & Features WEB - End ]" -Fore Cyan;start-Sleep -Seconds 0
	}
	"DC" {
		Write-Host "[ 2008 Roles & Features DC - Start ]" -Fore Cyan;start-Sleep -Seconds 0
		Write-Host "Installing Windows Feature < Ad-Domain-Services >" -Fore Yellow -nonewline;start-Sleep -Seconds 0
		Add-WindowsFeature -Name Ad-Domain-Services   > $null
		Write-Host "....Complete" -Fore Green ;start-Sleep -Seconds 0 

		Write-Host "Installing Windows Feature < DNS >" -Fore Yellow -nonewline;start-Sleep -Seconds 0
		Add-WindowsFeature -Name DNS  > $null
		Write-Host "....Complete" -Fore Green ;start-Sleep -Seconds 0 
		Write-Host "[ 2008 Roles & Features DC - End ]" -Fore Cyan;start-Sleep -Seconds 0
	}  
	"PRINT" {
		Write-Host "[ 2008 Roles & Features PRINT - Start ]" -Fore Cyan;start-Sleep -Seconds 0
		Write-Host "Installing Windows Feature < Print-Server >" -Fore Yellow -nonewline;start-Sleep -Seconds 0
		Add-WindowsFeature -Name Print-Server  > $null
		Write-Host "....Complete" -Fore Green ;start-Sleep -Seconds 0 
		Write-Host "[ 2008 Roles & Features PRINT - End ]" -Fore Cyan;start-Sleep -Seconds 0
	}
	"FTP" {
		Write-Host "[ 2008 Roles & Features FTP - Start ]" -Fore Cyan;start-Sleep -Seconds 0
		Write-Host "Installing Windows Feature < Web-Ftp-Service >" -Fore Yellow -nonewline;start-Sleep -Seconds 0
		Add-WindowsFeature -name Web-Ftp-Service > $null
		Write-Host "....Complete" -Fore Green ;start-Sleep -Seconds 0 

		Write-Host "Installing Windows Feature < Web-Mgmt-Tools >" -Fore Yellow -nonewline;start-Sleep -Seconds 0
		Add-WindowsFeature -Name Web-Mgmt-Tools -IncludeAllSubFeature > $null
		Write-Host "....Complete" -Fore Green ;start-Sleep -Seconds 0 
		Write-Host "[ 2008 Roles & Features FTP - End ]" -Fore Cyan;start-Sleep -Seconds 0
	}
	default { 
	} 
}
}
Else {
}
}
Function DotNET45Install {
Write-Host "Installing .NET 4.5 " -Fore Yellow -NoNewLine
C:\Scripts\Provisioning\dependencies\DotNet45\dotNetFx45_Full_setup.exe /q /norestart | out-null
Write-Host " ...Complete" -fore Green
}
Function WindowsManagementFramework4Install {
Write-Host "Installing Windows Management Framework 4.0" -Fore Yellow -NoNewLine
wusa.exe "C:\Scripts\Provisioning\dependencies\DotNet45\Windows6.1-KB2819745-x64-MultiPkg.msu" /quiet /norestart | out-null
Write-Host " ...Complete" -fore Green
}
Function DriveRights {
Write-Host "Assigning Drive Rights" -Fore Yellow -Nonewline;start-Sleep -Seconds 0
Remove-DriveAccount "Everyone"
Remove-DriveAccount "CREATOR OWNER"
Remove-DriveAccount "Users"
Add-DriveAccount "Users"
Write-Host " ....Complete" -Fore Green ;start-Sleep -Seconds 0 
}
Function Remove-DriveAccount {
    param([string] $accountName)
    $colRights = [System.Security.AccessControl.FileSystemRights]"Read" 

    $InheritanceFlag = [System.Security.AccessControl.InheritanceFlags]::None
    $PropagationFlag = [System.Security.AccessControl.PropagationFlags]::None 

    $objType =[System.Security.AccessControl.AccessControlType]::Allow 

    $objUser = New-Object System.Security.Principal.NTAccount($accountName) 

    $objACE = New-Object System.Security.AccessControl.FileSystemAccessRule `
    ($objUser, $colRights, $InheritanceFlag, $PropagationFlag, $objType) 

    $objACL = Get-ACL "D:\" 
    $objACL.RemoveAccessRuleAll($objACE) 

    Set-ACL "D:\" $objACL
}
Function Add-DriveAccount {
    param([string] $accountName)
    
    $colRights = [System.Security.AccessControl.FileSystemRights]"ListDirectory, `
    ReadAndExecute, ReadAttributes, ReadExtendedAttributes, ReadPermissions, Traverse"
    $InheritanceFlag = [System.Security.AccessControl.InheritanceFlags]"ContainerInherit, ObjectInherit"
    $PropagationFlag = [System.Security.AccessControl.PropagationFlags]::None 

    $objType =[System.Security.AccessControl.AccessControlType]::Allow 

    $objUser = New-Object System.Security.Principal.NTAccount($accountName) 

    $objACE = New-Object System.Security.AccessControl.FileSystemAccessRule `
    ($objUser, $colRights, $InheritanceFlag, $PropagationFlag, $objType) 

    $objACL = Get-ACL "D:\" 
    $objACL.AddAccessRule($objACE) 

    Set-ACL "D:\" $objACL
}
Function PageFile {
Write-Host "Configuring Page File" -Fore Yellow -Nonewline;start-Sleep -Seconds 0
# Set up necessary variables to access WMI object.
$computer = "LocalHost" 
$namespace = "root\CIMV2" 
$Win32CompSys = Get-WmiObject -class Win32_ComputerSystem -computername $computer -namespace $namespace
$memory = [int]$($Win32CompSys.TotalPhysicalMemory/1mb)

# Limit max pagefile size to 16GB
If ($memory -gt 16384) {$memory = 16384}

# Set up necessary variables for registry access.
$RegKey = "HKLM:\HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\Control\Session Manager\Memory Management"
$KeyName = "PagingFiles"
$CMin = "200"
$CMax = "200"
$DMin = $memory
$DMax = $memory 
$Value = "C:\Pagefile.sys $Cmin $CMax","D:\Pagefile.sys $DMin $DMax"

# Set pagefile.
Set-ItemProperty -Path $RegKey -Name $KeyName -Value $Value
Write-Host " ....Complete" -Fore Green ;start-Sleep -Seconds 0 
}
Function IIS6_PS_config {
Write-Host "Applying IIS6 Config" -Fore Yellow -Nonewline;start-Sleep -Seconds 0
# Set up necessary variables and access WMI object.
$computer = "LocalHost"
$namespace = "root\MicrosoftIISv2"
$SMTPserver = "SmtpSvc/1"
$SmtpSvc1 = Get-WmiObject -Class IIsSmtpServerSetting -ComputerName $computer `
-Namespace $namespace -Filter "name = '$SMTPserver'"

# Enable logging.
$SmtpSvc1.LogType = "1"

# Set new log schedule.
$SmtpSvc1.LogFilePeriod = "1"

# Set log file directory.
$SmtpSvc1.LogFileDirectory = "D:\Logs"

# Set extended logging settings.
$SmtpSvc1.LogExtFileBytesRecv ="True"
$SmtpSvc1.LogExtFileBytesSent ="True"
$SmtpSvc1.LogExtFileClientIp ="True"
$SmtpSvc1.LogExtFileComputerName ="True"
$SmtpSvc1.LogExtFileCookie ="True"
$SmtpSvc1.LogExtFileDate ="True"
$SmtpSvc1.LogExtFileHost ="True"
$SmtpSvc1.LogExtFileHttpStatus ="True"
$SmtpSvc1.LogExtFileHttpSubStatus ="True"
$SmtpSvc1.LogExtFileMethod ="True"
$SmtpSvc1.LogExtFileProtocolVersion ="True"
$SmtpSvc1.LogExtFileReferer ="True"
$SmtpSvc1.LogExtFileServerIp ="True"
$SmtpSvc1.LogExtFileServerPort ="True"
$SmtpSvc1.LogExtFileSiteName ="True"
$SmtpSvc1.LogExtFileTime ="True"
$SmtpSvc1.LogExtFileTimeTaken ="True"
$SmtpSvc1.LogExtFileUriQuery ="True"
$SmtpSvc1.LogExtFileUriStem ="True"
$SmtpSvc1.LogExtFileUserAgent ="True"
$SmtpSvc1.LogExtFileUserName ="True"
$SmtpSvc1.LogExtFileWin32Status ="True"

# Apply above changes.
$SmtpSvc1.Put() > $null

Write-Host " ....Complete" -Fore Green ;start-Sleep -Seconds 0 
}
Function netsvc_PS_config {
Write-Host "Applying netsvc Config" -Fore Yellow -Nonewline;start-Sleep -Seconds 0
Copy-Item -Path "C:\Scripts\Provisioning\dependencies\netsvc" -Destination "C:\inetpub" -Recurse -Force

# Set up necessary variables to retrieve server name via WMI object.
$computer = "LocalHost" 
$namespace = "root\CIMV2" 
$CompSystem = Get-WmiObject -Class Win32_ComputerSystem -ComputerName $computer -Namespace $namespace
$ServerName = $CompSystem.Name

# Set up necessary variables for filepaths and text removal.
$aspcheck = "C:\inetpub\netsvc\aspcheck.asp"
$htmcheck = "C:\inetpub\netsvc\htmcheck.htm"
$pattern = "!servername!"

#Call replace string function for aspcheck.asp and htmcheck.htm.
Replace-String $aspcheck $pattern $ServerName 
Replace-String $htmcheck $pattern $ServerName 

Write-Host " ....Complete" -Fore Green ;start-Sleep -Seconds 0 
}
Function SmartHost_PS_config {
Write-Host "Applying SmartHost Config" -Fore Yellow -Nonewline;start-Sleep -Seconds 0

# Set up necessary variables and access WMI object.
$computer = "LocalHost"
$namespace = "root\MicrosoftIISv2"
$SMTPserver = "SmtpSvc/1"
$SmtpSvc1 = Get-WmiObject -Class IIsSmtpServerSetting -ComputerName $computer `
-Namespace $namespace -Filter "name = '$SMTPserver'"

# Set smart host. 
$SmtpSvc1.SmartHost = "mifenmail99.maritz.com"
$SmtpSvc1.SmartHostType = "2"

# Apply above changes.
$SmtpSvc1.Put() > $null
Write-Host " ....Complete" -Fore Green ;start-Sleep -Seconds 0 
}
Function Replace-String {
    param([string]$FilePath, [string]$pattern, [string]$replacement)
    
    $text = Get-Content -Path $FilePath
    if($text -match $pattern)
    {
    $text -replace $pattern, $replacement | out-file -encoding ascii $FilePath
    }
}
Function LMHOST {
$wmiNACfg = [wmiclass]'Win32_NetworkAdapterConfiguration'
$wmiNACfg.enablewins($false,$false)
}
Function NETBIOS {
$nics = gwmi Win32_NetworkAdapterConfiguration | where {$_.IPEnabled -eq $true}
foreach ($nic in $nics) {
  $nic.settcpipnetbios(1)
  $nic.SetDynamicDNSRegistration($TRUE)
  }
}
Function NICRENAME2008 {
$nic1 = Get-WmiObject -class win32_networkadapter -filter "NetConnectionStatus = 2" | Select -First 1
$nic2 = Get-WmiObject -class win32_networkadapter -filter "NetConnectionStatus = 2" | Select -Last 1

If ($nic1.DeviceID -eq $nic2.DeviceID) {
Write-host " | 1 NIC detected | " -Fore White -nonewline;start-Sleep -Seconds 0
$newname1 = "Private"
$nic1.NetConnectionID = $newname1
$nic1.Put()
}
ElseIf ($nic1.DeviceID -ne $nic2.DeviceID) {
Write-host " | 2 NICs detected | " -Fore White -nonewline;start-Sleep -Seconds 0
$newname1 = "Private"
$nic1.NetConnectionID = $newname1
$nic1.Put()
$newname2 = "Public"
$nic2.NetConnectionID = $newname2
$nic2.Put()
}
Else {
}
}
Function NICRENAME2012 {
$nic1 = Get-NetAdapterHardwareInfo | Sort-Object Bus,Function | Select -First 1
$nic2 = Get-NetAdapterHardwareInfo | Sort-Object Bus,Function | Select -Last 1
If ($nic1.name -eq $nic2.name) {
Write-host " | 1 NIC detected | " -Fore White -nonewline;start-Sleep -Seconds 0
Get-NetAdapter | Select -First 1 | Rename-NetAdapter -NewName Private
}
ElseIf ($nic1.name -ne $nic2.name) {
Write-host " | 2 NICs detected | " -Fore White -nonewline;start-Sleep -Seconds 0
Get-NetAdapter | Select -First 1 | Rename-NetAdapter -NewName Private
Get-NetAdapter | Select -Last 1 | Rename-NetAdapter -NewName Public
}
Else {
}
}
Function NIC2008 {
Write-Host "[ 2008 NIC Config - Start]" -Fore Cyan;start-Sleep -Seconds 0
Write-Host "Turning off LMHost" -Fore Yellow -nonewline;start-Sleep -Seconds 0
LMHOST | out-null
Write-Host " ...Complete" -Fore Green;start-Sleep -Seconds 0
Write-Host "Enable NetBIOS and Dynamic DNS Registration" -Fore Yellow -nonewline;start-Sleep -Seconds 0
NETBIOS | out-null
Write-Host " ...Complete" -Fore Green;start-Sleep -Seconds 0
Write-Host "Renaming NIC" -Fore Yellow -nonewline;start-Sleep -Seconds 0
NICRENAME2008 | out-null
Write-Host " ...Complete" -Fore Green;start-Sleep -Seconds 0

Switch -wildcard ($PrivateIP) {
	"10.32.12[8-9].*" { $DNSp = "156.45.65.61"; $DNSs = "156.45.65.59"; $AWSdomain = "US" }
	"10.32.13[0-3].*" { $DNSp = "156.45.65.61"; $DNSs = "156.45.65.59"; $AWSdomain = "US" }
	"10.32.136.*" { $DNSp = "156.45.65.61"; $DNSs = "156.45.65.59"; $AWSdomain = "US" }
	"10.32.138.*" { $DNSp = "156.45.65.61"; $DNSs = "156.45.65.59"; $AWSdomain = "US" }
	"10.34.0.*" { $DNSp = "172.19.13.251"; $DNSs = "172.19.13.252"; $AWSdomain = "MNETI"  }  
	"10.34.[1-5].*" { $DNSp = "10.34.5.99"; $DNSs = "156.45.65.59"; $AWSdomain = "US" }
	"10.36.0.*" { $DNSp = "172.19.13.251"; $DNSs = "172.19.13.252"; $AWSdomain = "MNETI"  }
	"10.36.[1-5].*" { $DNSp = "10.36.5.99"; $DNSs = "156.45.65.59"; $AWSdomain = "US" }
	"10.99.13.*" { $DNSp = "10.99.13.215"; $DNSs = "10.99.13.252" }
	"156.45.*" { $DNSp = "156.45.65.59"; $DNSs = "156.45.65.61" }
	"156.45.59.*" { $DNSp = "156.45.59.121"; $DNSs = "156.45.59.122" }
	"156.45.69.*" { $DNSp = "156.45.69.251"; $DNSs = "156.45.69.251" }
	"172.17.*" { $DNSp = "10.99.13.251"; $DNSs = "10.99.13.252" }
	"172.18.*" { $DNSp = "156.45.65.59"; $DNSs = "156.45.65.61" }
	"172.19.*" { $DNSp = "172.19.1.21"; $DNSs = "172.19.1.22" }
	"192.168.1[0-2].*" { $DNSp = "172.19.13.251"; $DNSs = "172.19.13.252" }
	"192.168.2[0-1].*" { $DNSp = "172.19.13.251"; $DNSs = "172.19.13.252" }
	"192.168.238.*" { $DNSp = "192.168.238.251"; $DNSs = "192.168.238.252" }
	default { $DNS = $NULL }
}

If (($DNSp) -and ($DNSs)) {
	Write-Host "Setting DNS" -Fore Yellow -nonewline;start-Sleep -Seconds 0
	DNS2008 | out-null
	Write-Host "...Complete" -Fore Green;start-Sleep -Seconds 0 
	#Write-Host "DNS has been changed to:`n" -Fore Yellow -nonewline;start-Sleep -Seconds 0	
	#Confirmdns
	
	# If AWS Segment - Update the DNS Suffix Search Order
	If ($AWSdomain) {
		$currentDNSSuffix = $privateNACfg.DNSDomainSuffixSearchOrder
		$newDNSSuffix = New-Object 'System.Collections.Generic.List[String]'
		Switch ($AWSdomain) {
			"US" {
				$newDNSSuffix.Add('us.maritz.net')
				$newDNSSuffix.Add('maritz.net')
				ForEach ($Suffix in $currentDNSsuffix) { If ($Suffix -notlike "*maritz.net") {$newDNSSuffix.Add($Suffix) }}
			}
			"MNETI" {
				$newDNSSuffix.Add('mneti.local')
				ForEach ($Suffix in $currentDNSsuffix) { If ($Suffix -notlike "mneti.local") {$newDNSSuffix.Add($Suffix) }}
			}
			default { 
				Write-Host -backgroundcolor black -foregroundcolor red "ERROR: Unable to update AWS Suffix Search Order.  Manual intervention required."
				Exit 1
			}
		}
		$privateWMINAC = [wmiclass]"Win32_NetworkAdapterConfiguration"
		$privateWMINAC.SetDNSSuffixSearchOrder($newDNSSuffix)
		Write-Host "SUCCESS: Updated DNS Suffix Search Order"
	}		
}
Else {
	Write-Host -backgroundcolor black -foregroundcolor red "`nERROR: No DNS settings found for the segment.  Manual intervention required."
	Exit 1
}
Write-Host "[ 2008 NIC Config - End]" -Fore Cyan;start-Sleep -Seconds 0 
}
Function NIC2012 {
Write-Host "[ 2012 NIC Config - Start]" -Fore Cyan;start-Sleep -Seconds 0
Write-Host "Turning off LMHost" -Fore Yellow -nonewline;start-Sleep -Seconds 0
LMHOST | out-null
Write-Host " ...Complete" -Fore Green;start-Sleep -Seconds 0
Write-Host "Enable NetBIOS and Dynamic DNS Registration" -Fore Yellow -nonewline;start-Sleep -Seconds 0
NETBIOS | out-null
Write-Host " ...Complete" -Fore Green;start-Sleep -Seconds 0
Write-Host "Renaming NIC" -Fore Yellow -nonewline;start-Sleep -Seconds 0
NICRENAME2012 | out-null
Write-Host " ...Complete" -Fore Green;start-Sleep -Seconds 0

Switch -wildcard ($PrivateIP) {
	"10.32.12[8-9].*" { $DNS = "156.45.65.61","156.45.65.59"; $AWSdomain = "US" }
	"10.32.13[0-3].*" { $DNS = "156.45.65.61","156.45.65.59"; $AWSdomain = "US" }
	"10.32.136.*" { $DNS = "156.45.65.61","156.45.65.59"; $AWSdomain = "US" }
	"10.32.138.*" { $DNS = "156.45.65.61","156.45.65.59"; $AWSdomain = "US" }
	"10.34.0.*" { $DNS = "172.19.13.251","172.19.13.252"; $AWSdomain = "MNETI"  }  
	"10.34.[1-5].*" { $DNS = "10.34.5.99","156.45.65.59"; $AWSdomain = "US" }
	"10.36.0.*" { $DNS = "172.19.13.251","172.19.13.252"; $AWSdomain = "MNETI"  }
	"10.36.[1-5].*" { $DNS = "10.36.5.99","156.45.65.59"; $AWSdomain = "US" }
	"10.99.13.*" { $DNS = "10.99.13.215","10.99.13.252" }
	"156.45.*" { $DNS = "156.45.65.59","156.45.65.61" }
	"156.45.59.*" { $DNS = "156.45.59.121","156.45.59.122" }
	"156.45.69.*" { $DNS = "156.45.69.251","156.45.69.251" }
	"172.17.*" { $DNS = "10.99.13.251","10.99.13.252" }
	"172.18.*" { $DNS = "156.45.65.59","156.45.65.61" }
	"172.19.*" { $DNS = "172.19.1.21","172.19.1.22" }
	"192.168.1[0-2].*" { $DNS = "172.19.13.251","172.19.13.252" }
	"192.168.2[0-1].*" { $DNS = "172.19.13.251","172.19.13.252" }
	"192.168.238.*" { $DNS = "192.168.238.251","192.168.238.252" }
	default { $DNS = $NULL }
}

If ($DNS) {
	Write-Host "Setting DNS" -Fore Yellow -nonewline;start-Sleep -Seconds 0
	Set-DNSClientServerAddress -InterfaceAlias "Private" -ServerAddresses ($DNS)
	Write-Host " ...Complete" -Fore Green;start-Sleep -Seconds 0
	#Write-Host "DNS has been changed to:" -Fore Yellow -nonewline;start-Sleep -Seconds 0	
	#Confirmdns
}
Else {
	Write-Host "`nNo DNS settings found for the segment.  Manual intervention required." -Fore Red;start-Sleep -Seconds 0
}
Write-Host "[ 2008 NIC Config - End]" -Fore Cyan;start-Sleep -Seconds 0 
}
Function net10x{
# 156.45.0.0/17
##route delete 156.45.0.0
netsh interface ipv4 add route 156.45.0.0/17 "Private" 192.168.10.5
#156.45.128.0/18
##route delete 156.45.128.0
netsh interface ipv4 add route 156.45.128.0/18 "Private" 192.168.10.5
# 156.45.220.0/23
##route delete 156.45.220.0
netsh interface ipv4 add route 156.45.220.0/23 "Private" 192.168.10.5
# 156.45.222.0/24
##route delete 156.45.222.0
netsh interface ipv4 add route 156.45.222.0/24 "Private" 192.168.10.5
# 10.0.0.0/8 net
##route delete 10.0.0.0
netsh interface ipv4 add route 10.0.0.0/8 "Private" 192.168.10.5
# 192.168.20.0/23 
##route delete 192.168.20.0
netsh interface ipv4 add route 192.168.20.0/23 "Private" 192.168.10.5
# 192.168.12.0/23
##route delete 192.168.12.0
netsh interface ipv4 add route 192.168.12.0/23 "Private" 192.168.10.5
# 192.168.30.0/24
##route delete 192.168.30.0
netsh interface ipv4 add route 192.168.30.0/24 "Private" 192.168.10.5
# 172.16.0.0/12 - Best Practices DMZs/NetSeg
##route delete 172.16.0.0
netsh interface ipv4 add route 172.16.0.0/12 "Private" 192.168.10.5
Write-Host " ...Added < 192.168.10.* > routes" -Fore Green;start-Sleep -Seconds 0 
}
Function net12x{
# 156.45.0.0/17
##route delete 156.45.0.0
netsh interface ipv4 add route 156.45.0.0/17 "Private" 192.168.12.5
# 156.45.128.0/18
##route delete 156.45.128.0
netsh interface ipv4 add route 156.45.128.0/18 "Private" 192.168.12.5
# 156.45.220.0/23
##route delete 156.45.220.0
netsh interface ipv4 add route 156.45.220.0/23 "Private" 192.168.12.5
# 156.45.222.0/24
##route delete 156.45.222.0
netsh interface ipv4 add route 156.45.222.0/24 "Private" 192.168.12.5
# 10.0.0.0/8 net
##route delete 10.0.0.0
netsh interface ipv4 add route 10.0.0.0/8 "Private" 192.168.12.5
# 192.168.20.0/23 
##route delete 192.168.20.0
netsh interface ipv4 add route 192.168.20.0/23 "Private" 192.168.12.5

# - May no longer be needed - Tom Morrison
##route delete 192.168.20.27
# netsh interface ipv4 add route 192.168.20.27/32 "Private" 192.168.12.23

# 192.168.10.0/23
##route delete 192.168.10.0
netsh interface ipv4 add route 192.168.10.0/23 "Private" 192.168.12.5
# 192.168.30.0/24
##route delete 192.168.30.0
netsh interface ipv4 add route 192.168.30.0/24 "Private" 192.168.12.5
# 172.16.0.0/12 - Best Practices DMZs/NetSeg
##route delete 172.16.0.0
netsh interface ipv4 add route 172.16.0.0/12 "Private" 192.168.12.5
Write-Host " ...Added < 192.168.12.* > routes" -Fore Green;start-Sleep -Seconds 0 
}
Function net20x {
# 156.45.0.0/17
##route delete 156.45.0.0
netsh interface ipv4 add route 156.45.0.0/17 "Private" 192.168.20.5
# 156.45.128.0/18
##route delete 156.45.128.0
netsh interface ipv4 add route 156.45.128.0/18 "Private" 192.168.20.5
# 156.45.220.0/23
##route delete 156.45.220.0
netsh interface ipv4 add route 156.45.220.0/23 "Private" 192.168.20.5
# 156.45.222.0/24
##route delete 156.45.222.0
netsh interface ipv4 add route 156.45.222.0/24 "Private" 192.168.20.5
# 10.0.0.0/8 net
##route delete 10.0.0.0
netsh interface ipv4 add route 10.0.0.0/8 "Private" 192.168.20.5
# 192.168.10.0/23
##route delete 192.168.10.0
netsh interface ipv4 add route 192.168.10.0/23 "Private" 192.168.20.5
# 192.168.12.0/23
##route delete 192.168.12.0
netsh interface ipv4 add route 192.168.12.0/23 "Private" 192.168.20.5
# 192.168.30.0/24
##route delete 192.168.30.0
netsh interface ipv4 add route 192.168.30.0/24 "Private" 192.168.20.5
# 172.16.0.0/12 - Best Practices DMZs/NetSeg
##route delete 172.16.0.0
netsh interface ipv4 add route 172.16.0.0/12 "Private" 192.168.20.5
Write-Host " ...Added < 192.168.20.* > routes" -Fore Green;start-Sleep -Seconds 0 
}
Function net30x {
# 156.45.0.0/17
##route delete 156.45.0.0
netsh interface ipv4 add route 156.45.0.0/17 "Private" 192.168.30.1
# 156.45.128.0/18
##route delete 156.45.128.0
netsh interface ipv4 add route 156.45.128.0/18 "Private" 192.168.30.1
# 156.45.220.0/23
##route delete 156.45.220.0
netsh interface ipv4 add route 156.45.220.0/23 "Private" 192.168.30.1
# 156.45.222.0/24
##route delete 156.45.222.0
netsh interface ipv4 add route 156.45.222.0/24 "Private" 192.168.30.1
# 10.0.0.0/8 net
##route delete 10.0.0.0
netsh interface ipv4 add route 10.0.0.0/8 "Private" 192.168.30.1
# 192.168.20.0/23 
##route delete 192.168.20.0
netsh interface ipv4 add route 192.168.20.0/23 "Private" 192.168.30.1
# 192.168.10.0/23
##route delete 192.168.10.0
netsh interface ipv4 add route 192.168.10.0/23 "Private" 192.168.30.1
# 192.168.12.0/23
##route delete 192.168.12.0
netsh interface ipv4 add route 192.168.12.0/23 "Private" 192.168.30.1
# 192.168.32.0/24
##route delete 192.168.32.0
netsh interface ipv4 add route 192.168.32.0/24 "Private" 192.168.30.1
# 172.16.0.0/12 - Best Practices DMZs/NetSeg
##route delete 172.16.0.0
netsh interface ipv4 add route 172.16.0.0/12 "Private" 192.168.30.1
Write-Host " ...Added < 192.168.30.* > routes" -Fore Green;start-Sleep -Seconds 0 
}
Function net193x {
# 156.45.0.0/17
##route delete 156.45.0.0
netsh interface ipv4 add route 156.45.0.0/17 "Private" 192.168.193.1
# 156.45.128.0/18
##route delete 156.45.128.0
netsh interface ipv4 add route 156.45.128.0/18 "Private" 192.168.193.1
# 10.0.0.0/9 net
##route delete 10.0.0.0
netsh interface ipv4 add route 10.0.0.0/9 "Private" 192.168.193.1
# 172.27.0.0/12 net - BestPractice/NetSeg
# older/smaller segment #route delete 172.27.0.0
#route delete 172.16.0.0
netsh interface ipv4 add route 172.16.0.0/12 "Private" 192.168.193.1
Write-Host " ...Added < 192.168.193.* > routes" -Fore Green;start-Sleep -Seconds 0 
}
Function net194x {
# 156.45.0.0/17
#route delete 156.45.0.0
netsh interface ipv4 add route 156.45.0.0/17 "Private" 192.168.194.1
# 156.45.128.0/18
#route delete 156.45.128.0
netsh interface ipv4 add route 156.45.128.0/18 "Private" 192.168.194.1
# 10.0.0.0/8 net
#route delete 10.0.0.0
netsh interface ipv4 add route 10.0.0.0/8 "Private" 192.168.194.1
# 172.27.0.0/12 net - BestPractice/NetSeg
# older/smaller segment #route delete 172.27.0.0
#route delete 172.16.0.0
netsh interface ipv4 add route 172.16.0.0/12 "Private" 192.168.194.1
Write-Host " ...Added < 192.168.194.* > routes" -Fore Green;start-Sleep -Seconds 0 
}
Function net238x {
# 156.45.0.0/17
#route delete 156.45.0.0
netsh interface ipv4 add route 156.45.0.0/17 "Private" 192.168.238.1
# 156.45.128.0/18
#route delete 156.45.128.0
netsh interface ipv4 add route 156.45.128.0/18 "Private" 192.168.238.1
# 156.45.220.0/23
#route delete 156.45.220.0
netsh interface ipv4 add route 156.45.220.0/23 "Private" 192.168.238.1
# 156.45.222.0/24
#route delete 156.45.222.0
netsh interface ipv4 add route 156.45.222.0/24 "Private" 192.168.238.1
# 10.0.0.0/8 net
#route delete 10.0.0.0
netsh interface ipv4 add route 10.0.0.0/8 "Private" 192.168.238.1
# 172.17.0.0 net - PCI Private DMZ internal/Best Pract/NetSeg
# older/smaller segment #route delete 172.17.0.0
#route delete 172.16.0.0
netsh interface ipv4 add route 172.16.0.0/12 "Private" 192.168.238.1
Write-Host " ...Added < 192.168.238.* > routes" -Fore Green;start-Sleep -Seconds 0 
}
Function net156_45_69_x {
# 156.45.0.0/17
#route delete 156.45.0.0
netsh interface ipv4 add route 156.45.0.0/17 "Private" 156.45.69.3
# 156.45.128.0/18
#route delete 156.45.128.0
netsh interface ipv4 add route 156.45.128.0/18 "Private" 156.45.69.3
# 156.45.220.0/23
#route delete 156.45.220.0
netsh interface ipv4 add route 156.45.220.0/23 "Private" 156.45.69.3
# 156.45.222.0/24
#route delete 156.45.222.0
netsh interface ipv4 add route 156.45.222.0/24 "Private" 156.45.69.3
# 10.0.0.0/8 net
#route delete 10.0.0.0
netsh interface ipv4 add route 10.0.0.0/8 "Private" 156.45.69.3
# 172.16.0.0/12 network - PCI Private/Best Practice and NetSegs - new 10/2009
# replaces the 172.17.0.0 an dthe 172.18.0.0 (both 255.255.0.0 nets before)
#route delete 172.16.0.0
netsh interface ipv4 add route 172.16.0.0/12 "Private" 156.45.69.3

# 156.45.60.0/24 net - PCI extranet public area for client IP connections
# this goes out of Extranet and not to intranet so has to go back default route
# this is extranet public private type segment IP's
# the AGI IVR box on Maritz Campus is on the network 
#route delete 156.45.60.0
netsh interface ipv4 add route 156.45.60.0/24 "Private" 156.45.69.1	
Write-Host " ...Added < 156.45.69.* > routes" -Fore Green;start-Sleep -Seconds 0 
}
Function Routes {
Write-Host "Applying routes if applicable:" -Fore Yellow -Nonewline;start-Sleep -Seconds 0
Switch -wildcard ($PrivateIP) {
	"192.168.10.*" {
net10x | out-null
	}
	"192.168.12.*" {
net12x | out-null
}
	"192.168.20.*" {
net20x | out-null
}
	"192.168.30.*" {
net30x | out-null
}
	"192.168.193.*" {
net193x | out-null
}
	"192.168.194.*" {
net194x | out-null
}
	"192.168.238.*" {
net238x | out-null
}
	"156.45.69.*" {
net156_45_69_x | out-null
}
default { 
$DNS = $NULL 
Write-Host " ...No Routes Added" -Fore Red;start-Sleep -Seconds 0 
}
}
}
Function JoinDomain {
$scriptPath = "C:\Scripts\Provisioning\dependencies\RemoteFunctions\New-RemoteSession"
Switch ($Domain){
	"US" {
		# Create the secure credential
		$strDomain = "US.maritz.net"
		$svcAcctUsername = "s_ServiceNowRB_US"
		$svcAcctDomain = "US"
		$svcAcctID = "$svcAcctDomain\$svcAcctUsername"
		$encPW = get-content "$scriptPath\s_ServiceNowRB_US.cred"
		$pi = get-content "$scriptPath\PI.key"
		$ssPW = ConvertTo-SecureString $encPW -key $pi
		$userCred = New-Object System.Management.Automation.PSCredential $svcAcctID,$ssPW
		
		# Determine Correct Target OU
		Switch ($OU) {
			"APP" { $targetOU = "OU=Prod App,OU=Servers,DC=us,DC=maritz,DC=net" }
			"CLOUD" { $targetOU = "OU=Cloud,OU=Servers,DC=us,DC=maritz,DC=net" }
			"FTP" { $targetOU = "OU=FTP,OU=Servers,DC=us,DC=maritz,DC=net" }
			"SQL" { $targetOU = "OU=SQL,OU=Servers,DC=us,DC=maritz,DC=net" }
			"WAP" { $targetOU = "OU=Web,OU=Servers,DC=us,DC=maritz,DC=net" }
			"WEB" { $targetOU = "OU=Web,OU=Servers,DC=us,DC=maritz,DC=net" }
			"ADFS" { $targetOU = "OU=ADFS,OU=Servers,DC=us,DC=maritz,DC=net" }
			"TERMINAL" { $targetOU = "OU=ADFS,OU=Servers,DC=us,DC=maritz,DC=net" }
			default { $targetOU = "INVALID" }
		}
	}
	"MNETI" {
		# Create the secure credential
		$strDomain = "MNETI.local"
		$svcAcctUsername = "s_ServiceNowRB_MNETi"
		$svcAcctDomain = "MNETI"
		$svcAcctID = "$svcAcctDomain\$svcAcctUsername"
		$encPW = get-content "$scriptPath\s_ServiceNowRB_MNETi.cred"
		$pi = get-content "$scriptPath\PI.key"
		$ssPW = ConvertTo-SecureString $encPW -key $pi
		$userCred = New-Object System.Management.Automation.PSCredential $svcAcctID,$ssPW
		
		# Determine Correct Target OU
		Switch ($OU) {
			"CLOUD" { $targetOU = "OU=Cloud,OU=Servers,DC=mneti,DC=local" }
			"FTP" { $targetOU = "OU=FTP,OU=Servers,DC=mneti,DC=local" }
			"WAP" { $targetOU = "OU=Wap,OU=Servers,DC=mneti,DC=local" }
			"WEB" { $targetOU = "OU=Web,OU=Servers,DC=mneti,DC=local" }
			default { $targetOU = "INVALID" }
		}
	}
	"MNETE" {
		# Create the secure credential
		$strDomain = "MNETE.local"
		$svcAcctUsername = "s_ServiceNowRB_MNETe"
		$svcAcctDomain = "MNETE"
		$svcAcctID = "$svcAcctDomain\$svcAcctUsername"
		$encPW = get-content "$scriptPath\s_ServiceNowRB_MNETe.cred"
		$pi = get-content "$scriptPath\PI.key"
		$ssPW = ConvertTo-SecureString $encPW -key $pi
		$userCred = New-Object System.Management.Automation.PSCredential $svcAcctID,$ssPW
		
		# Determine Correct Target OU
		Switch ($OU) {
			"FTP" { $targetOU = "OU=FTP,OU=Servers,DC=mnete,DC=local" }
			"WAP" { $targetOU = "OU=Wap,OU=Servers,DC=mnete,DC=local" }
			"WEB" { $targetOU = "OU=Web,OU=Servers,DC=mnete,DC=local" }
			default { $targetOU = "INVALID" }
		}
	}
	"LAB" {
		# Create the secure credential
		$strDomain = "US.mgtslab.net"
		$svcAcctUsername = "s_ServiceNowPS"
		$svcAcctDomain = "US"
		$svcAcctID = "$svcAcctDomain\$svcAcctUsername"
		$encPW = get-content "$scriptPath\s_ServiceNowPS.cred"
		$pi = get-content "$scriptPath\PI.key"
		$ssPW = ConvertTo-SecureString $encPW -key $pi
		$userCred = New-Object System.Management.Automation.PSCredential $svcAcctID,$ssPW
		
		# Determine Correct Target OU
		Switch ($OU) {
			"APP" { $targetOU = "OU=Prod App,OU=Servers,DC=us,DC=mgtslab,DC=net" }
			"FTP" { $targetOU = "OU=FTP,OU=Servers,DC=us,DC=mgtslab,DC=net" }
			"SQL" { $targetOU = "OU=SQL,OU=Servers,DC=us,DC=mgtslab,DC=net" }
			"WAP" { $targetOU = "OU=Web,OU=Servers,DC=us,DC=mgtslab,DC=net" }
			"WEB" { $targetOU = "OU=Web,OU=Servers,DC=us,DC=mgtslab,DC=net" }
			default { $targetOU = "INVALID" }
		}
	}
	default { $strDomain = "INVALID" }
}

# Add the server to the domain
If ($strDomain -eq "INVALID") {
	Write-Host "ERROR: Domain $Domain is not a valid domain selection."
}
Else {
	If ($targetOU -eq "INVALID") {
		Write-Host "`nINFO: OU `"$OU`" unspecified or not found."
		Write-Host "INFO: Adding server to the $Domain Domain in the default computer OU`n" -Fore Yellow;start-Sleep -Seconds 0
		Add-Computer -DomainName $strDomain -Credential $userCred -WarningAction SilentlyContinue
		Write-Host " ...Complete" -Fore Green;start-Sleep -Seconds 0
	}
	Else {
	Write-Host "Adding server to the $Domain Domain in the $OU OU" -Fore Yellow -nonewline;start-Sleep -Seconds 0
	Add-Computer -DomainName $strDomain -Credential $userCred -OUPath $targetOU -WarningAction SilentlyContinue
	Write-Host " ...Complete" -Fore Green;start-Sleep -Seconds 0
	}
}

}
Function RebootTargetComputer {
Restart-Computer -Confirm:$False -Force
}

#-----------------------#
#
#  Phase 2 Functions
#
#-----------------------#

Function ImportCarbon {
# This Carbon Module enables Install-SmbShare to work later in the script.
Write-host "`nImporting Carbon Module.." -fore yellow -nonewline
invoke-expression -Command C:\Scripts\Provisioning\SQL\Carbon\Carbon\Import-Carbon.ps1 | out-null
write-host " ...Complete" -fore green
}
Function DerivingSqlServiceAccount {
$script:Domain = (Get-WmiObject -Class Win32_ComputerSystem).domain
$script:shortDomain = ($Domain.split('.')[0]).ToUpper()
#Write-Host "`n*----  Performing SQL specific operations on [ $targetComputer ] ----*`n" -Fore Magenta;start-Sleep -Seconds 0

#-----------------------------------------------------------------------------
# Deriving SQL SERVICE ACCOUNT: START
#-----------------------------------------------------------------------------

# Define local variables
$ServiceAccount = '';
$Provider = '';
$Environment = '';
$BU = '';
$Messages = @();

# Outside history utility?  Use built-in logging
if (-not (Test-Path function:Write-History)) { Set-Alias Write-History Write-Host;}
if (-not (Test-Path function:Write-HistoryWarning)) { Set-Alias Write-HistoryWarning Write-Warning;}
if (-not (Test-Path function:Write-HistoryError)) { Set-Alias Write-HistoryError Write-Error;}
if (-not (Test-Path function:Write-HistoryVerbose)) { Set-Alias Write-HistoryVerbose Write-Verbose;}

# Optional parameters?
if ($ComputerName -eq $null -or $ComputerName -eq '')
{
	$ComputerName = ($env:ComputerName);
	Write-HistoryVerbose('Assuming local host {0}' -f $ComputerName);
}
$ComputerName = $ComputerName.ToLower();

#-----------------------------------------------------------------------------
# Main

# Provider?  Only some providers have specific service accounts
switch -wildcard ($ComputerName)
{
	# Amazon
	'aws*' {$Provider = 'aws';}

	# Azure
	'azu*' {$Provider = 'azu';}

	# Maritz/anything else has no specific provider
	default {$Provider = '';}
}

# Location? Ignore because we do not have location-specific service accounts
# Function? Assume SQL

# Environment?  Should be last letter before last numbers.
# Some Maritz locations have site codes in names (MAU001, XEU006) that are not the server numbers
switch -regex ($ComputerName)
{
	'd\d+$' {$Environment = 'd';}
	't\d+$' {$Environment = 'd';}

	# Staging and production share the same service account
	'r\d+$' {$Environment = 'p';}
	's\d+$' {$Environment = 'p';}
	'p\d+$' {$Environment = 'p';}

	# Unknown?
	default
	{
		Write-HistoryVerbose ('Could not determine dev/staging/prod environment from computer name.  Assuming production.');
		$Environment = 'p';
	}
}

# BU? Should be two letters before environment
switch -wildcard ($ComputerName)
{
	'*sqlmr*' {$BusinessUnit = 'mr';}
	'*sqlmm*' {$BusinessUnit = 'mm';}
	'*sqlmg*' {$BusinessUnit = 'mg';}
	'*sqlmt*' {$BusinessUnit = 'mt';}
	'*sqlss*' {$BusinessUnit = 'ss';}
	'*sqlmc*' {$BusinessUnit = 'mc';}
	'*sqlcs*' {$BusinessUnit = 'cs';}

	# Unknown?
	default
	{
		Write-HistoryVerbose('Could not determine BU from computer name.  Assuming MGTS.');
		$BusinessUnit = 'mg';
	}
}

if ($Browser -eq $true)
{
	# Only one browser account per provider
	$ServiceAccount = 's_sqlbrowser{0}' -f $Provider;
}
else
{
	$ServiceAccount = 's_sqlservice{0}{1}{2}' -f $Provider, $BusinessUnit, $Environment;
}
Write-HistoryVerbose('Service account: {0}' -f $ServiceAccount);

#-----------------------------------------------------------------------------
# Cleanup

# Pipe out the information
$ResultInfo = New-Object -typename PSObject |
	Add-Member -MemberType NoteProperty -Name Name -Value $ServiceAccount -PassThru |
	Add-Member -MemberType NoteProperty -Name IsSuccess -Value $true -PassThru |
	Add-Member -MemberType NoteProperty -Name Messages -Value $Messages -PassThru;

#write-host "$ServiceAccount" -fore yellow
#write-host "$shortDomain\$ServiceAccount" -fore green	

#-----------------------------------------------------------------------------
# Deriving SQL SERVICE ACCOUNT: STOP
#-----------------------------------------------------------------------------
}
Function SqlPrep {

#Write-Host "Grabbing appropriate domain group" -Fore Yellow -NoNewline;start-Sleep -Seconds 0
switch -wildcard ($Domain) {
	"us*" { $sqlGroup = "US\USo_ProdSQL2005" }
	"mneti*" { $sqlGroup = "MNETI\MNETIo_ProdSQL2005" }
	"mnete*" { $sqlGroup = "MNETE\MNETEo_ProdSQL2005" }
	"mpn*" { $sqlGroup = "MPN\MPNo_ProdSQL2005" }
	default { $sqlGroup = $NULL }
}
#Write-Host " ...Complete" -Fore Green;start-Sleep -Seconds 0

# ======================================================================================= #
# Create four directories on H (if H exists) or D (if H does not exist)
# ======================================================================================= #
If (Test-Path h:)
{
New-Item H:\SFTP -type directory
New-Item H:\DATA -type directory
New-Item H:\SSISPackages -type directory
New-Item H:\DBA -type directory
New-Item D:\InstallFiles -type directory

# ======================================================================================= #
# Share these four folders and permission it for Full Access to Everyone
# ======================================================================================= #
Install-SmbShare -Name "SFTP" -Path "H:\SFTP" -FullAccess Everyone
Install-SmbShare -Name "DATA" -Path "H:\DATA" -FullAccess Everyone
Install-SmbShare -Name "SSISPackages" -Path "H:\SSISPackages" -FullAccess Everyone
Install-SmbShare -Name "DBA" -Path "H:\DBA" -FullAccess Everyone
}
Elseif (Test-Path D:) 
{
New-Item D:\SFTP -type directory
New-Item D:\DATA -type directory
New-Item D:\SSISPackages -type directory
New-Item D:\DBA -type directory
New-Item D:\InstallFiles -type directory

# ======================================================================================= #
# Share these four folders and permission it for Full Access to Everyone
# ======================================================================================= #
Install-SmbShare -Name "SFTP" -Path "D:\SFTP" -FullAccess Everyone
Install-SmbShare -Name "DATA" -Path "D:\DATA" -FullAccess Everyone
Install-SmbShare -Name "SSISPackages" -Path "D:\SSISPackages" -FullAccess Everyone
Install-SmbShare -Name "DBA" -Path "D:\DBA" -FullAccess Everyone
}
Else {
}

$DmnServiceAccount = "$shortDomain\$ServiceAccount"

write-host " SQL Service Account is: $DmnServiceAccount" -fore yellow

# Setup local security policy items for the SQL Service account
C:\Scripts\Provisioning\SQL\ntrights.exe -u "$DmnServiceAccount" +r SeTcbPrivilege  
C:\Scripts\Provisioning\SQL\ntrights.exe -u "$DmnServiceAccount" +r SeChangeNotifyPrivilege
C:\Scripts\Provisioning\SQL\ntrights.exe -u "$DmnServiceAccount" +r SeLockMemoryPrivilege  
C:\Scripts\Provisioning\SQL\ntrights.exe -u "$DmnServiceAccount" +r SeBatchLogonRight
C:\Scripts\Provisioning\SQL\ntrights.exe -u "$DmnServiceAccount" +r SeAssignPrimaryTokenPrivilege
C:\Scripts\Provisioning\SQL\ntrights.exe -u "$DmnServiceAccount" +r SeServiceLogonRight
C:\Scripts\Provisioning\SQL\ntrights.exe -u "$DmnServiceAccount" +r SeManageVolumePrivilege
C:\Scripts\Provisioning\SQL\ntrights.exe -u "$DmnServiceAccount" +r SeIncreaseQuotaPrivilege

# Permission service account to the root of SAN each drive
C:\Scripts\Provisioning\SQL\icacls.exe d: /grant "$DmnServiceAccount"":(OI)(CI)(F)"
If (Test-Path e:){
C:\Scripts\Provisioning\SQL\icacls.exe e: /grant "$DmnServiceAccount"":(OI)(CI)(F)"
}
Else {}
If (Test-Path f:){
C:\Scripts\Provisioning\SQL\icacls.exe f: /grant "$DmnServiceAccount"":(OI)(CI)(F)"
}
Else {}
If (Test-Path g:){
C:\Scripts\Provisioning\SQL\icacls.exe g: /grant "$DmnServiceAccount"":(OI)(CI)(F)"
}
Else {}
If (Test-Path h:){
C:\Scripts\Provisioning\SQL\icacls.exe h: /grant "$DmnServiceAccount"":(OI)(CI)(F)"
}
Else {}

# Take ownership of all the files in the MachineKeys folder.
takeown.exe /f "C:\Documents and Settings\All Users\Application Data\Microsoft\Crypto\RSA\MachineKeys\*" > $null

# Permission Service Account to MachineKey folder
C:\Scripts\Provisioning\SQL\icacls.exe "C:\Documents and Settings\All Users\Application Data\Microsoft\Crypto\RSA\MachineKeys" /grant "$DmnServiceAccount"":(OI)(CI)(R)"
C:\Scripts\Provisioning\SQL\icacls.exe "C:\Documents and Settings\All Users\Application Data\Microsoft\Crypto\RSA\MachineKeys\*.*" /grant "$DmnServiceAccount"":(OI)(CI)(R)"

C:\Scripts\Provisioning\SQL\ntrights.exe -u administrators +r SeDebugPrivilege

IF($shortDomain -eq "US"){
If (Test-Path h:){
C:\Scripts\Provisioning\SQL\icacls.exe H:\SFTP /grant 'us\s_controlmagent:(OI)(CI)(M)'
C:\Scripts\Provisioning\SQL\icacls.exe H:\DBA /grant 'US\Uso_ProdSQL2005:(OI)(CI)(M)'
C:\Scripts\Provisioning\SQL\icacls.exe H:\SFTP /grant 'US\Uso_ProdSQL2005:(OI)(CI)(M)'
C:\Scripts\Provisioning\SQL\icacls.exe H:\DATA /grant 'US\Uso_ProdSQL2005:(OI)(CI)(M)'
C:\Scripts\Provisioning\SQL\icacls.exe H:\SSISPackages /grant 'US\Uso_ProdSQL2005:(OI)(CI)(M)'
C:\Scripts\Provisioning\SQL\icacls.exe D:\InstallFiles /grant 'US\Uso_ProdSQL2005:(OI)(CI)(M)'
C:\Scripts\Provisioning\SQL\icacls.exe D:\InstallFiles /grant 'US\s_SQLInstall:(OI)(CI)(M)'
}
Else {
#Need to setup inheritance for the shares created above 
C:\Scripts\Provisioning\SQL\icacls.exe D:\DBA /grant 'US\Uso_ProdSQL2005:(OI)(CI)(M)'
C:\Scripts\Provisioning\SQL\icacls.exe D:\SFTP /grant 'US\Uso_ProdSQL2005:(OI)(CI)(M)'
C:\Scripts\Provisioning\SQL\icacls.exe D:\DATA /grant 'US\Uso_ProdSQL2005:(OI)(CI)(M)'
C:\Scripts\Provisioning\SQL\icacls.exe D:\SSISPackages /grant 'US\Uso_ProdSQL2005:(OI)(CI)(M)'
C:\Scripts\Provisioning\SQL\icacls.exe D:\InstallFiles /grant 'US\Uso_ProdSQL2005:(OI)(CI)(M)'
C:\Scripts\Provisioning\SQL\icacls.exe D:\InstallFiles /grant 'US\s_SQLInstall:(OI)(CI)(M)'
C:\Scripts\Provisioning\SQL\icacls.exe D:\SFTP /grant 'us\s_controlmagent:(OI)(CI)(M)'
}
#More local security policy stuff
C:\Scripts\Provisioning\SQL\ntrights.exe -u us\s_sqlinstall +r SeDebugPrivilege
C:\Scripts\Provisioning\SQL\ntrights.exe -u us\s_sqlbrowser +r SeDenyBatchLogonRight
C:\Scripts\Provisioning\SQL\ntrights.exe -u us\s_sqlbrowser +r SeDenyInteractiveLogonRight
C:\Scripts\Provisioning\SQL\ntrights.exe -u us\s_sqlbrowser +r SeDenyRemoteInteractiveLogonRight
#DBA Administrator access on the SQL Servers:
net localgroup Administrators /ADD us\uso_prodsql2005
}
Else {
}

IF($shortDomain -eq "MPN"){
If (Test-Path h:){
C:\Scripts\Provisioning\SQL\icacls.exe H:\SFTP /grant 'MPN\s_controlmagent:(OI)(CI)(M)'
}
Else {
#Need to setup inheritance for the shares created above 
C:\Scripts\Provisioning\SQL\icacls.exe D:\SFTP /grant 'MPN\s_controlmagent:(OI)(CI)(M)'
}

#More local security policy stuff
C:\Scripts\Provisioning\SQL\ntrights.exe -u mpn\s_sqlinstall +r SeDebugPrivilege
C:\Scripts\Provisioning\SQL\ntrights.exe -u mpn\s_sqlbrowser +r SeDenyBatchLogonRight
C:\Scripts\Provisioning\SQL\ntrights.exe -u mpn\s_sqlbrowser +r SeDenyInteractiveLogonRight
C:\Scripts\Provisioning\SQL\ntrights.exe -u mpn\s_sqlbrowser +r SeDenyRemoteInteractiveLogonRight
#DBA Administrator access on the SQL Servers:
net localgroup Administrators /ADD mpn\mpno_prodsql2005
}
Else {
}

Write-host " ...Complete"  -fore green
}
Function Add-DriveAccount {
    param(
		[string] $accountName,
		[string] $drivePath
	)
    
    $colRights = [System.Security.AccessControl.FileSystemRights]"FullControl"
    $InheritanceFlag = [System.Security.AccessControl.InheritanceFlags]"ContainerInherit, ObjectInherit"
    $PropagationFlag = [System.Security.AccessControl.PropagationFlags]::None 
    $objType =[System.Security.AccessControl.AccessControlType]::Allow 

    $objUser = New-Object System.Security.Principal.NTAccount($accountName) 

    $objACE = New-Object System.Security.AccessControl.FileSystemAccessRule `
    ($objUser, $colRights, $InheritanceFlag, $PropagationFlag, $objType) 

    $objACL = Get-ACL $drivePath 
    $objACL.AddAccessRule($objACE) 

    Set-ACL $drivePath $objACL
}
Function AddServerOps {
$script:computer = Get-WmiObject -Class Win32_ComputerSystem
$script:domain = $computer.domain

$script:driveRoots = gwmi win32_logicaldisk -Filter "DriveType='3'" | `
	Where-Object { $_.DeviceID -notmatch "[abc]:"} | ForEach-Object { $_.DeviceID + "\" }

Write-Host "Adding Server_Ops Security" -Fore Yellow -NoNewline;start-Sleep -Seconds 0
	
If ($driveRoots -ne $NULL) {
	switch -wildcard ($domain) {
		"us*" {
			If (Test-Path "D:\Ops_Temp") {
				Add-DriveAccount -accountName "US\USo_Win_Server_Ops" -drivePath "D:\Ops_Temp\"
			}
			If (Test-Path "C:\Scripts") {
				Add-DriveAccount -accountName "US\USo_Win_Server_Ops" -drivePath "C:\Scripts\"
			}
			$driveRoots | ForEach-Object { Add-DriveAccount -accountName "US\USo_Win_Server_Ops" -drivePath $_ }
		}
		"mneti*" {
			If (Test-Path "D:\Ops_Temp") {
				Add-DriveAccount -accountName "MNETI\MNETIo_Win_Server_Ops" -drivePath "D:\Ops_Temp\"
			}
			If (Test-Path "C:\Scripts") {
				Add-DriveAccount -accountName "MNETI\MNETIo_Win_Server_Ops" -drivePath "C:\Scripts\"
			}
			$driveRoots | ForEach-Object { Add-DriveAccount -accountName "MNETI\MNETIo_Win_Server_Ops" -drivePath $_ }
		}
		"mnete*" {
			If (Test-Path "D:\Ops_Temp") {
				Add-DriveAccount -accountName "MNETE\MNETEo_Win_Server_Ops" -drivePath "D:\Ops_Temp\"
			}
			If (Test-Path "C:\Scripts") {
				Add-DriveAccount -accountName "MNETE\MNETEo_Win_Server_Ops" -drivePath "C:\Scripts\"
			}
			$driveRoots | ForEach-Object { Add-DriveAccount -accountName "MNETE\MNETEo_Win_Server_Ops" -drivePath $_ }
		}
		default {}
	}
}

Write-Host " ...Complete" -Fore Green;start-Sleep -Seconds 0
}
<#
#----------------------------  WinCollect Specific Start  ----------------------------#
####################
#LogEvent Routines
#
#Code and Concepts by Chris Gillham, Andy Wolfe, George Harms, Kyle Gatewood
#Web service and site by Kiran Kapoor and Mary Mueller
#Maritz 
#10/10/2014
#Updated 11/05/2014 by George Harms But for the event log item.  If we want to use this in conjunction with custom event logs, perhaps a modification (in blue below) like this will suffice?  Checks to see if it can read the passed in Logname and if not, default to the Application log.  Then we can specify if you want to use a custom event log, you need to create it ahead of time.   This way the module doesn’t have to worry about elevation of rights, etc to create the log (not that we can’t build that in later.)
#Nothing more than a rudimentary change for $urltype.
#####################
Function Retry($TargetFunction) {
    $StopTrying = 0
    $RetryCounter = 0

    Try
    {        
        & $TargetFunction
    }   
    Catch 
    {
        $RetryCounter++
        if ($RetryCounter -le 5)
        {
            & $TargetFunction
            Write-Host "Encountered Error.....Retrying $RetryCounter of 5 times"
        }
        else
        {
            Write-Host "Could not download install files. Giving up" 
        }      
    }
}
#Get html dir listing from web server and parse files to download
Function GetDirListing {   
    $FileDict = @{}
    #Ignore SSL Cert trust issues
    [Net.ServicePointManager]::ServerCertificateValidationCallback = {$true}
    $client = new-object System.Net.WebClient

    #Get directory listing (html)
    $webstring = $client.DownloadString($Source)     

    $lines = [Regex]::Split($webString, "<br>")
    # Parse each line, looking for files and folders

    #We expect one AGENT file on the source web server. 
    #If > 1, fail since we don't want to install old bits
    $AgentCounter = 0
    $ConfigConsoleCounter = 0

    foreach ($line in $lines) 
    {                
        if ($line.ToUpper().Contains("HREF")) 
        {
            # File or Folder
            if (!$line.ToUpper().Contains("[TO PARENT DIRECTORY]")) 
            {
                # Not Parent Folder entry
                $items =[Regex]::Split($line, """")
                $items = [Regex]::Split($items[2], "(>|<)")
                $item = $items[2]
                
                $global:AgentFilename = $item | select-string -Pattern "AGENT_x64_WinCollect-[\d\.]+-setup.exe" 
                Write-Verbose "AgentFilename: $global:AgentFilename"
                $ConfigConsoleFilename = $item | select-string -Pattern "WinCollect_Configuration_Console_Setup[_\d]+.exe"  
              
                if ($global:AgentFilename)
                {                                                                 
                    $AgentCounter++                                   
                    $FileDict.Add("AGENT" , $AgentFilename)
                }              
                if ($ConfigConsoleFilename)
                {            
                    $ConfigConsoleCounter++
                    $FileDict.Add("ConfigConsole" , $ConfigConsoleFilename)
                }                                                     
            }
        }
    }
    if ( $AgentCounter -ne 1 -or $ConfigConsoleCounter -ne 1)
    {
        if ( $AgentCounter -ne 1)
        {
            Write-Host "Found $AgentCounter Agent files in $source`nExpected 1."
        }
        if ($ConfigConsoleCounter -ne 1)
        {
            Write-Host "Found $ConfigConsoleCounter Configuration Console files in $source`nExpected 1."            
        }
        break      
    }      
    return $FileDict  
}
#Download source files from remote web server to distribution host
Function DownloadSourceFiles ($PaulDict) { 
   Write-Host "Downloading:" $PaulDict.Get_Item("AGENT") + "-> D:\ops_temp"
  # $Message = "Downloading:" + $PaulDict.Get_Item("AGENT") + "-> D:\ops_temp"
 #  #LogEventtoWebService -MessageType "Notification" -Message $Message -ScriptFilePath $CurrentScriptFilePath -ScriptFileLastModified $CurrentScriptLastModifiedDateTime -UrlType "Internal" -AppName $AppName -AppKey $AppID -ApiKey $ApiKey 
   
   Write-Host "Downloading:" $PaulDict.Get_Item("ConfigConsole") + "-> D:\ops_temp"
  # $Message = "Downloading:" + $PaulDict.Get_Item("ConfigConsole") + "-> D:\ops_temp"
   #LogEventtoWebService -MessageType "Notification" -Message $Message -ScriptFilePath $CurrentScriptFilePath -ScriptFileLastModified $CurrentScriptLastModifiedDateTime -UrlType "Internal" -AppName $AppName -AppKey $AppID -ApiKey $ApiKey 

    #We expect two files, if more throw an error
    if ($PaulDict.Count -eq 2)
    {        
        #Download files needed for WinCollect install/upgrade/configuration
        Try
        {
            foreach ($file in $PaulDict.GetEnumerator())
            {    
                $FileUrl = $Source + $file.Value                
                $Destination = "D:\ops_temp\" + $file.Value                
                #Ignore SSL Cert trust issues
                [Net.ServicePointManager]::ServerCertificateValidationCallback = {$true}
             #   $wc = New-Object System.Net.WebClient
             #   $wc.DownloadFile($FileUrl, $Destination)                                
            }        
         }
         Catch
         {
             [system.exception]
              "System Exception: Could not download source files from " + $Source
              Write-Verbose $_    
         }
     }
    else
    {
        Write-Host "Got $PaulDict.Count files to download and expected 2`n"        
        Break
    } 
 }   
Function UninstallALE {    
    # ----Uninstall ALE -----
    #Expect uninstaller to be named unins000.exe or unins001.exe
    $ALEUninstaller = "\" + "unins00[0-1].exe"
    
    if (Test-Path -Path ($ALEInstallPath + $ALEUninstaller) )
    {  
        #Stop the ALE Service    
        $objService = Get-Service $ALEService
        If ($objService.Status -ne "Stopped") 
        {
    	    $objService.Stop()
	        While ((Get-Service $ALEService).Status -ne "Stopped")	
            { 
		        Write-Host -foregroundcolor yellow  "Waiting for $ALEService to stop."
		        Start-Sleep 5
	        }

	    Write-Host "$ALEService has stopped."
        }

        #This is fairly harsh, but is sometimes needed
        #kill PID is process get stuck in 'Stopping' or 'StopPending'
        $ALEService = "AdaptiveLogExporterService"
        If (((Get-Service $ALEService).Status -eq "Stopping") -OR ((Get-Service $ALEService).Status -eq "StopPending"))
        {
            Write-Host "Killing " + $ALEService + " process because it's stuck in Stopping or StopPending status"
            $ServiceNamePID = Get-Service  | where { ($_.Status -eq 'StopPending' -or $_.Status -eq 'Stopping') -and $_.Name -eq $ALEService}
            $ServicePID = (get-wmiobject win32_Service | Where { $_.Name -eq $ServiceNamePID.Name }).ProcessID 
            Stop-Process $ServicePID -force
        }      
          
        Write-Verbose "Uninstalling ALE"
        $ALEUninstall = $ALEInstallPath + $ALEUninstaller    
        $ALEuninstallArgs = ' ' , '/SILENT' , '/VERYSILENT'      
        & $ALEUninstall $ALEuninstallArgs   
        
        while (ps | ? {$_.path -like ($ALEInstallPath+$ALEUninstaller)})
        {           
           Write-Verbose "ALE Uninstaller is running. Sleeping for 5 seconds"
           sleep 5
        }
    }
    else
    {
        Write-Verbose "ALE is not installed. Skipping Uninstaller."
    }
    #$Message = "Uninstalled QRadar ALE from $global:fqdn"
    #LogEventtoWebService -MessageType "Notification" -Message $Message -ScriptFilePath $CurrentScriptFilePath -ScriptFileLastModified $CurrentScriptLastModifiedDateTime -UrlType "Internal" -AppName $AppName -AppKey $AppID -ApiKey $ApiKey 

}
Function UninstallWinCollect {
    # ----Uninstall WinCollect -----
    if ( Get-WmiObject -Class Win32_Service -Filter "Name='$WincollectService'" ) {
        $Return = $True
    }

    #If WinCollect service is installed
    if ( Get-WmiObject -Class Win32_Service -Filter "Name='$WincollectService'")    
    {  
        Write-Verbose "WinCollect service is installed. Launching Uninstaller."
        #Stop the WinCollect Service    
        $objService = Get-Service $WincollectService

        While ((Get-Service $WincollectService).Status -eq "StopPending" -or (Get-Service $WincollectService).Status -eq "StartPending")	
        {                
            $CurrentStatus = (Get-Service $WincollectService).Status
		    Write-Host -foregroundcolor yellow "Waiting for $WincollectService service to transition from" (Get-Service $WincollectService).Status
		    Start-Sleep 5
	    }

        If ($objService.Status -ne "Stopped") 
        {
            Write-Host "WinCollect Service Status:" (Get-Service $WincollectService).Status
    	    $objService.Stop()
            #Get-Service $objService.Status
	        While ((Get-Service $WincollectService).Status -ne "Stopped")	
            {                
                Write-Host "WinCollect Service Status:" (Get-Service $WincollectService).Status
		        Write-Host -foregroundcolor yellow  "Waiting for $WincollectService service to stop."
		        Start-Sleep 5
	        }
	        Write-Host "$WincollectService has stopped."
        }

        #This is fairly harsh, but is sometimes needed
        #kill PID is process get stuck in 'Stopping' or 'StopPending'        
        If (((Get-Service $WincollectService).Status -eq "Stopping") -OR ((Get-Service $WincollectService).Status -eq "StopPending"))
        {
            Write-Host "Killing " + $WincollectService + " process because it's stuck in Stopping or StopPending status"
            $ServiceNamePID = Get-Service  | where { ($_.Status -eq 'StopPending' -or $_.Status -eq 'Stopping') -and $_.Name -eq $WincollectService}
            $ServicePID = (get-wmiobject win32_Service | Where { $_.Name -eq $ServiceNamePID.Name }).ProcessID 
            Stop-Process $ServicePID -force
        }      
          
        #'Uninstalling WinCollect'
        $Uninstall = "msiexec"
        $uninstallArgs = ' ' , '/x{1E933549-2407-4A06-8EC5-83313513AE4B}', '/norestart', '/qn'       
       
        & $Uninstall $uninstallArgs   
       
        $Counter = 0
        while ((Get-Process $Uninstall -ErrorAction SilentlyContinue) -and ($Counter -lt 5))
        {
           $Counter++
           sleep 5
           Write-Verbose "WinCollect uninstaller is running. Sleeping for 5 seconds"
        }               

        #If WinCollect service is installed
        while ( Get-WmiObject -Class Win32_Service -Filter "Name='$WincollectService'")
        {
            Write-Host "WinCollect Service is still installed!"
            sleep 5
        }        

        #Delete WinCollect Install Folder
        if ($env:WinCollect_Install_Dir)
        {
            if (Test-Path -Path ( $env:WinCollect_Install_Dir))
            {                                      
                Remove-Item ($env:WinCollect_Install_Dir) -recurse -ErrorAction SilentlyContinue
            }
        }
    }
    else
    {
        Write-Verbose "WinCollect service is not installed"
    }       
}
Function InstallWinCollect ($PaulDict) {   
    Write-Verbose "InstallWinCollect"
    if ($bot -eq $True)
    {   
        $filter = [regex] "AGENT_x64_WinCollect-[\d\.]+-setup.exe"        
        $item = Get-ChildItem -Path "D:\ops_temp" | Where-Object {$_.Name -match $filter}        
        $global:WinCollectInstallFile = $item.Name + " "   
    }
    else
    {
        $PaulDict.Get_Item("AGENT").ToString()
        $global:WinCollectInstallFile = $PaulDict.Get_Item("AGENT").ToString() + " "
    }

   $global:executable = "D:\ops_temp\" + $WinCollectInstallFile
    
   $LogSourceName = $env:COMPUTERNAME.ToUpper() + "<WindowsEventLog>&"

    $LOG_SOURCE_AUTO_CREATION_PARAMETERS = 
        "LOG_SOURCE_AUTO_CREATION_PARAMETERS=" + 
        "Component1.AgentDevice=DeviceWindowsLog&" +
        "Component1.Action=create&" +       
        "Component1.LogSourceName=$LogSourceName" +
        "Component1.LogSourceIdentifier=$global:fqdn&" +
        "Component1.Destination.Name=WinCollectdest&" +
        "Component1.CoalesceEvents=True&" +
        "Component1.StoreEventPayload=True&" +
        "Component1.Log.Application=False&" +
        "Component1.Log.Security=True&" +
        "Component1.Log.System=False&" +
        "Component1.Log.DNS+Server=False&" +
        "Component1.Log.Directory+Service=False&" +
        "Component1.Log.File+Replication+Service=False"


    $INSTALL_LOCATION = "INSTALLDIR=" + "$INSTALLDIR"

    $args = '/s' , '/v"' , '/qn', #"INSTALLDIR=$INSTALLDIR" ,
            "AUTHTOKEN=$AUTHTOKEN" ,
            'FULLCONSOLEADDRESS=10.99.10.22' ,
            "HOSTNAME=$env:COMPUTERNAME" ,
            'LOG_SOURCE_AUTO_CREATION_ENABLED=True' , 
           # "LOG_SOURCE_AUTO_CREATION_PARAMETERS=" , 
            $LOG_SOURCE_AUTO_CREATION_PARAMETERS   
            

    #Run silent installer of WinCollect Agent       
    & $executable $args  
    
   
   $AGENT_NO_EXTENSION = [io.path]::GetFileNameWithoutExtension($WinCollectInstallFile)
   $Counter = 0

    while ((Get-Process $AGENT_NO_EXTENSION  -ErrorAction SilentlyContinue) -and ($Counter -lt 5))
    {
        $Counter++
        sleep 5
        Write-Verbose "Installer is running. Sleeping for 5 seconds"
    }

    #Wait for Service to be registered
    $Counter=0
    while (!(Get-WmiObject -Class Win32_Service -Filter "Name='$WincollectService'" ) -and $Counter -lt 5)
    {
        $Counter++
        Sleep 5
        Write-Verbose "Waiting for $WincollectService to be registered. Sleeping for 5 seconds"
    }

    if ($Counter -ge 5)
    {
        Write-Verbose "Error registering $WincollectService. Manual intervention needed to determine if install completed properly!"
        $Message = "Error registering $WincollectService. Manual intervention needed on $global:fqdn to determine if install completed properly!"
        #LogEventtoWebService -MessageType "Notification" -Message $Message -ScriptFilePath $CurrentScriptFilePath -ScriptFileLastModified $CurrentScriptLastModifiedDateTime -UrlType "Internal" -AppName $AppName -AppKey $AppID -ApiKey $ApiKey             
    }
    else
    {
        Write-Host "Installation Complete!"
        Write-Host "WinCollect Service Status:"     
        Write-Host (Get-Service $WincollectService).Status

        $Message = "Installed QRadar WinCollect on $global:fqdn"
        #LogEventtoWebService -MessageType "Notification" -Message $Message -ScriptFilePath $CurrentScriptFilePath -ScriptFileLastModified $CurrentScriptLastModifiedDateTime -UrlType "Internal" -AppName $AppName -AppKey $AppID -ApiKey $ApiKey 
    
        $Status = (Get-Service $WincollectService).Status
        $Message = "QRadar WinCollect Service Status on $global:fqdn`: $Status"
        #LogEventtoWebService -MessageType "Notification" -Message $Message -ScriptFilePath $CurrentScriptFilePath -ScriptFileLastModified $CurrentScriptLastModifiedDateTime -UrlType "Internal" -AppName $AppName -AppKey $AppID -ApiKey $ApiKey        
    }
   
 }
Function RemoteMode ($RemoteHost) {
    
    Write-Verbose "RemoteHost: $RemoteHost"
    #Establish session
    $URI = "https://" + $RemoteHost.Trim() + ":5986"
    $global:session = New-PSSession -Credential $global:cred -ConnectionUri $URI -SessionOption (New-PSSessionOption -SkipRevocationCheck -SkipCACheck -SkipCNCheck -ProxyAccessType none)
   
    #Variables in scriptblock resolve remotely
    #Resolve tmp variable on remote host    
    $RemoteTmp=invoke-command –Session $session -scriptblock{$env:temp}

    #Variables in scriptblock resolve remotely
    #Resolve remote computer name
    $RemoteComputerName=invoke-command –Session $session -scriptblock{$env:COMPUTERNAME}    
    #Note: Variables in Send-File destination resolve locally  
      
    Send-File ("D:\ops_temp\AGENT_x64_WinCollect-7.2.2.959003-setup.exe") ("D:\ops_temp\AGENT_x64_WinCollect-7.2.2.959003-setup.exe") $global:session       
    Send-File $script:MyInvocation.MyCommand.Path ($script:MyInvocation.MyCommand.Path) $session        

}
Function SetupRemoteCreds {
    #There are two auth options - hard code creds (only recommended for development) or script will prompt user
    #hard code method - last line must be commented
    
    $username = "Blatanha"
    $password = "Bl@ck*Y@k!"
    $secstr = New-Object -TypeName System.Security.SecureString
    $password.ToCharArray() | ForEach-Object {$secstr.AppendChar($_)}
    $global:cred = new-object -typename System.Management.Automation.PSCredential -argumentlist $username, $secstr    
    #$sessionOption = New-PSSessionOption -SkipRevocationCheck
    #Prompt for creds (above lines must be commented)
    #$global:cred = Get-Credential 
}
Function QualifyEnvironment {
#Test for 32 bit/64 bit OS
    #64 bit
    if ( (${env:ProgramFiles(x86)} -ne $null) -and (Test-Path -Path "C:\Program Files (x86)" ))
    {
        $InstallPath = "C:\Program Files (x86)\WinCollect"
        $global:ALEInstallPath = "C:\Program Files (x86)\Adaptive Log Exporter"
        Write-Verbose "Detected a 64 bit OS"
    }
    #32 bit
    elseif ( (Test-Path -Path "C:\Program Files") -and (-NOT (Test-Path -Path "C:\Program Files (x86)")))
    {
        $InstallPath = "C:\Program Files\WinCollect"
        $global:ALEInstallPath = "C:\Program Files\Adaptive Log Exporter"
        Write-Verbose "Detected a 32 bit OS. This script only supports 64 bit. Exiting"
        break
    }
    else
    {
        Write-Error "can't tell if host is a 32 bit or 64 bit, aborting"
        Break
    }    

    #Halt execution if not an Administrator
    If ( -NOT ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole(`
        [Security.Principal.WindowsBuiltInRole] "Administrator"))
    {
        Write-Warning "You do not have Administrator rights to run this script!`nPlease re-run this script as an Administrator!"
        Break
    }
}
Function Cleanup {    
    if ($remote)
    {
        $agent1 = "D:\ops_temp\" + $PaulDict.Get_Item("AGENT")
        Remove-Item $agent1
    }    
    else
    {
        $agent2 = "D:\ops_temp\" + $global:WinCollectInstallFile.Trim()                
        Remove-Item $agent2
    }
   
    if ($bot -ne $true)
    {
        $ConfigConsole = "D:\ops_temp\" + $PaulDict.Get_Item("ConfigConsole")
        Remove-Item  $ConfigConsole
    }         
}
Function SetupEnvironment {   
    If (!$bot)
    {
        #Configure IBS Logging
        #Import-Module "$env:temp\LogEvent.psm1"
        $global:AppName = "QRadar"
        $global:AppID = "95257366-B990-4519-9542-E54920B55CA4"
        $global:ApiKey = "3F450886-625F-4D15-9701-979208EFE933"
                
        #Get the current script file fully qualified path, name, and last update datetime
        $global:CurrentScriptFilePath = $script:MyInvocation.MyCommand.Path
        $global:CurrentScriptLastModifiedDateTime = (Get-Item $script:MyInvocation.MyCommand.Path).LastWriteTime    
        #Local File Settings
        $LocalLogFileName = "D:\ops_temp\" + "$env:ComputerName-logfile.txt"
        #Windows EventViewer Settings
        $LogName = "Application"
        $LogSource = 'EventSystem'

        $global:Source = "https://qradar-ale.maritz.com/WinCollect/Current/"
        #Declare Empty Dictionary. Populated in GetDirListing
        $global:FileDict = @{}    
    }
    
    #Enable verbose output
    $global:VerbosePreference = "continue"   
   
             
    #Define Globals
    $global:WincollectService = "WinCollect"
    $global:ALEService = "AdaptiveLogExporterService"
    
    $Domain = (gwmi WIN32_ComputerSystem).Domain.ToLower().Trim()  
    $global:fqdn = $env:computername.ToLower().Trim() + "." + $Domain
    $global:INSTALLDIR = "C:\IBM\WinCollect"
    #QRadar authtoken
    $global:AUTHTOKEN="9706e3c6-277c-4c22-85d6-f28e3c50650a"
    $AgentFilename = ""
    $ConfigConsoleFilename = ""

    #Handle Remote mode
    $Architecture = (Get-WmiObject Win32_OperatingSystem -computername $ENV:ComputerName.ToLower()).OSArchitecture    
}
Function LogEvent {
	Param(
	[Parameter(Mandatory=$false)]
  	[bool]$WebService = $true,
  	[Parameter(Mandatory=$false)]
    [bool]$LocalLogFile = $false,
    [Parameter(Mandatory=$false)]
  	[string]$LocalLogFileName,
	[Parameter(Mandatory=$false)]
  	[bool]$WindowsEventViewer = $false,
  	[Parameter(Mandatory=$true)]
  	[string]$MessageType= "Notification",
    [Parameter(Mandatory=$true)]
  	[string]$Message,    
    [Parameter(Mandatory=$false)]
  	[string]$LogName = "Application",
    [Parameter(Mandatory=$false)]
  	[string]$LogSource = 'EventSystem',
    [Parameter(Mandatory=$false)]    
  	[string]$ComputerName = $env:ComputerName,
    [Parameter(Mandatory=$false)]    
  	[string]$DomainName = $env:USERDOMAIN,
    [Parameter(Mandatory=$false)]    
  	[string]$ScriptUserID = $env:USERNAME,
    [Parameter(Mandatory=$false)]    
  	[string]$ScriptFilePath = $script:MyInvocation.MyCommand.Path,
	[Parameter(Mandatory=$true)]
	[String]$UrlType,
    [Parameter(Mandatory=$false)]    
  	[string]$ScriptFileLastModified = (Get-Item $script:MyInvocation.MyCommand.Path).LastWriteTime
	)

    if ($WebService -eq $true)
    {
        LogEventtoWebService -LogSource $LogSource -MessageType $MessageType -Message $Message -ScriptFilePath $ScriptFilePath -ScriptFileLastModified $ScriptFileLastModified -UrlType $UrlType
    }
    if ($LocalLogFile -eq $true)
    {
        LogEventtoLocalDisk -LogFile $LocalLogFileName -LogSource $LogSource -MessageType $MessageType -Message $Message -ScriptFilePath $ScriptFilePath -ScriptFileLastModified $ScriptFileLastModified
    }
    if ($WindowsEventViewer -eq $true)
    {
        LogEventtoLocalEventViewer -LogName $LogName -LogSource $LogSource -MessageType $MessageType -Message $Message -ScriptFilePath $ScriptFilePath -ScriptFileLastModified $ScriptFileLastModified
    }

  }
Function LogEventtoWebService {
	Param(
	[Parameter(Mandatory=$false)]
  	[string]$AppKey = "EE6B2EB1-E05F-4393-BB1F-65CE78F9D9FA",
  	[Parameter(Mandatory=$false)]
  	[string]$AppName = "Scripting",
	[Parameter(Mandatory=$false)]
  	[string]$ApiKey = "45DC5997-EAEF-454B-80D7-273795AF0610",
  	[Parameter(Mandatory=$true)]
  	[string]$MessageType,
	[Parameter(Mandatory=$true)]
  	[string]$Message,
  	[Parameter(Mandatory=$false)]
  	[string]$LogSource = '',
    [Parameter(Mandatory=$false)]    
  	[string]$ComputerName = $env:ComputerName,
    [Parameter(Mandatory=$false)]    
  	[string]$DomainName = $env:USERDOMAIN,
    [Parameter(Mandatory=$false)]    
  	[string]$ScriptUserID = $env:USERNAME,
    [Parameter(Mandatory=$false)]    
  	[string]$ScriptFilePath = $script:MyInvocation.MyCommand.Path,
	[Parameter(Mandatory=$true)]
	[String]$UrlType,
    [Parameter(Mandatory=$false)]    
  	[string]$ScriptFileLastModified = (Get-Item $script:MyInvocation.MyCommand.Path).LastWriteTime
	)
	
    Try
    {
	    if($UrlType -like 'Dev*'){
			$URI = "http://nasdev.maritzdev.com/Logger/logger.asmx?wsdl"
		}
		if($UrlType -like 'Internal'){
			$URI = "https://nasprod.maritz.com/Logger/Logger.asmx?wsdl"
		}
		if($UrlType -like 'External'){
			$URI = "http://nas.maritz.com/LoggerRelay/loggerRelay.asmx?op=Log"
		}
		#Development $URI = "http://nasdev.maritzdev.com/Logger/logger.asmx?wsdl"
        #Production $URI = "https://nasprod.maritz.com/Logger/Logger.asmx?wsdl"
        #$URI = "https://nasprod.maritz.com/Logger/Logger.asmx?wsdl"
        $Proxy = New-WebServiceProxy -uri $URI -namespace WebServiceProxy
	    $Proxy.Log($AppKey, $AppName, $ApiKey, $MessageType, $Message, $LogSource, $ComputerName, $DomainName, $ScriptUserID, $ScriptFilePath, $ScriptFileLastModified)
    }
    catch 
    {
        Write-Host "Error (Webservice)" -ForegroundColor Red
    }
}
Function LogEventtoLocalDisk {
Param (
    [Parameter(Mandatory=$true)]
  	[string]$LogFile,    
    [Parameter(Mandatory=$true)]
    [string]$MessageType,
	[Parameter(Mandatory=$true)]
  	[string]$Message,
    [Parameter(Mandatory=$false)]
  	[string]$LogSource = '',
    [Parameter(Mandatory=$false)]    
  	[string]$ComputerName = $env:ComputerName,
    [Parameter(Mandatory=$false)]    
  	[string]$DomainName = $env:USERDOMAIN,
    [Parameter(Mandatory=$false)]    
  	[string]$ScriptUserID = $env:USERNAME,
    [Parameter(Mandatory=$false)]    
  	[string]$ScriptFilePath = $script:MyInvocation.MyCommand.Path,
    [Parameter(Mandatory=$false)]    
  	[string]$ScriptFileLastModified = (Get-Item $script:MyInvocation.MyCommand.Path).LastWriteTime    
    )
    
    if (!(Test-Path -path $LogFile ))
    {
        $LogFile = New-Item -type file $LogFile
    }
       
    Try
    {
        #Write-Host $Message -ForegroundColor White
        Add-content $Logfile -value "$((Get-Date).ToString("yyyy-MM-dd HH:mm:ss.fff")), $Message, $MessageType, $LogSource, $ComputerName, $DomainName, $ScriptUserID, $ScriptFilePath, $ScriptFileLastModified"
    }
    catch [system.UnauthorizedAccessException]
    {
        Write-Host "Error (logfile): Write access denied to $LogFile" -ForegroundColor Red
    }
}
Function LogEventtoLocalEventViewer {
Param (
    [Parameter(Mandatory=$true)]
  	[string]$LogName,      
    [Parameter(Mandatory=$true)]
    [string]$MessageType,
	[Parameter(Mandatory=$true)]
  	[string]$Message,
    [Parameter(Mandatory=$true)]
  	[string]$LogSource,
    [Parameter(Mandatory=$false)]    
  	[string]$ComputerName = $env:ComputerName,
    [Parameter(Mandatory=$false)]    
  	[string]$DomainName = $env:USERDOMAIN,
    [Parameter(Mandatory=$false)]    
  	[string]$ScriptUserID = $env:USERNAME,
    [Parameter(Mandatory=$false)]    
  	[string]$ScriptFilePath = $script:MyInvocation.MyCommand.Path,
    [Parameter(Mandatory=$false)]    
  	[string]$ScriptFileLastModified = (Get-Item $script:MyInvocation.MyCommand.Path).LastWriteTime
    )     
    
    $EventMessage = "$Message, $LogSource, $ComputerName, $DomainName, $ScriptUserID, $ScriptFilePath, $ScriptFileLastModified"

    $EntryType = "Information"

    if($MessageType -eq "Notification")
    {
        $EntryType = "Information"
    }

    if($MessageType -eq "Warning")
    {
        $EntryType = "Warning"
    }

    if($MessageType -eq "Error")
    {
        $EntryType = "Error"
    }

    if($MessageType -eq "Debug")
    {
        $EntryType = "Information"
    }

    if($MessageType -eq "Generic")
    {
        $EntryType = "Information"
    }

    Try
    {
        write-eventlog -EntryType $EntryType -EventID 0001 -logname $LogName -source $LogSource -message $EventMessage

    }
    catch [system.UnauthorizedAccessException]
    {
        Write-Host "Error (EventViewer): Write access denied to $LogFile" -ForegroundColor Red
    }  

}
Function Send-File {
  param(
      ## The path on the local computer
      [Parameter(Mandatory = $true)]
      $Source,

      ## The target path on the remote computer
      [Parameter(Mandatory = $true)]
      $Destination,

      ## The session that represents the remote computer
      [Parameter(Mandatory = $true)]
      [System.Management.Automation.Runspaces.PSSession] $Session
  )

  #Set-StrictMode -Version Latest

  ## Get the source file, and then get its content
  $sourcePath = (Resolve-Path $source).Path
  $sourceBytes = [IO.File]::ReadAllBytes($sourcePath)
  $streamChunks = @()

  ## Now break it into chunks to stream
  Write-Progress -Activity "Sending $Source" -Status "Preparing file"
  $streamSize = 1MB
  for($position = 0; $position -lt $sourceBytes.Length;
      $position += $streamSize)
  {
      $remaining = $sourceBytes.Length - $position
      $remaining = [Math]::Min($remaining, $streamSize)

      $nextChunk = New-Object byte[] $remaining
      [Array]::Copy($sourcebytes, $position, $nextChunk, 0, $remaining)
      $streamChunks += ,$nextChunk
  }

  $remoteScript = {
      param($destination, $length)

      ## Convert the destination path to a full filesytem path (to support
      ## relative paths)
      $Destination = $executionContext.SessionState.`
          Path.GetUnresolvedProviderPathFromPSPath($Destination)

      ## Create a new array to hold the file content
      $destBytes = New-Object byte[] $length
      $position = 0

      ## Go through the input, and fill in the new array of file content
      foreach($chunk in $input)
      {
          Write-Progress -Activity "Writing $Destination" `
              -Status "Sending file" `
              -PercentComplete ($position / $length * 100)

          [GC]::Collect()
          [Array]::Copy($chunk, 0, $destBytes, $position, $chunk.Length)
          $position += $chunk.Length
      }

      ## Write the content to the new file
      [IO.File]::WriteAllBytes($destination, $destBytes)

      ## Show the result
      Get-Item $destination
      [GC]::Collect()
  }

  ## Stream the chunks into the remote script
  $streamChunks | Invoke-Command -Session $session $remoteScript `
      -ArgumentList $destination,$sourceBytes.Length
}    
Function WinCollect {
param (    
    [Parameter(Mandatory=$false)]    
    [string]$bot,
    [Parameter(Mandatory=$false)]
    [string]$remote
)

#Stop execution when an error is encountered
$ErrorActionPreference = "Stop"
#Throw an error if an undefined variable is referenced
Set-StrictMode -Version 2

Copy-Item C:\Scripts\Provisioning\WinCollect\AGENT_x64_WinCollect-7.2.2.959003-setup.exe -destination D:\Ops_Temp
Copy-Item C:\Scripts\Provisioning\WinCollect\WinCollect_Configuration_Console_Setup_7_2_0_1009.exe -destination D:\Ops_Temp

#Remote Mode
if ($remote)
{
    #Used for development purposes
    #Copy-Item G:\Logging-QRadar\Automation\WinCollect\WinCollectInstaller.ps1 $env:temp\WinCollectInstaller.ps1

    $VerbosePreference = "continue"        
    Write-Verbose "Preparing to remotely push WinCollect installations from $env:ComputerName"

    #Import-Module "$env:temp\Send-File.psm1"
    SetupEnvironment

    #Before Pushing WinCollect, we first need to retrieve local install files
    $PaulDict= @{}
    #$PaulDict=Retry("GetDirListing")
   # DownloadSourceFiles($PaulDict)

    SetupRemoteCreds

    #Loop through deployment targets
            $remote.Split(",") | ForEach {

        $target = $_

        Write-Host -ForegroundColor yellow "Preparing to deploy WinCollect to $target"                        

        #$Message = "User $env:userdomain\$env:username Started QRadar WinCollect Installation on $target from $global:fqdn"
        #LogEventtoWebService -MessageType "Notification" -Message $Message -ScriptFilePath $CurrentScriptFilePath -ScriptFileLastModified $CurrentScriptLastModifiedDateTime -UrlType "Internal" -AppName $AppName -AppKey $AppID -ApiKey $ApiKey         
    
        #Gets user creds, copies files to remote host, runs installer via remoting   
        Write-Host -ForegroundColor yellow "Before"                 
        RemoteMode($target)
        Write-Host -ForegroundColor yellow "After"             
        #Variables in scriptblock resolve remotely                          
        $result = Invoke-Command –Session $global:session -FilePath $global:CurrentScriptFilePath -ArgumentList $true                  
        Write-Host -ForegroundColor yellow "Exited Remote Installation on $target"
        
        #Cleanup Installer Script from Remote Target
       # $fn = Split-Path -Leaf $PSCommandPath               
       # $DeleteRemoteScript=invoke-command –Session $session -scriptblock{ param($fn) Remove-Item "D:\ops_temp\" + $fn } -ArgumentList $fn  
        
        $message = "WinCollect was installed on $target by $env:userdomain\$env:username from $global:fqdn. If ALE was deinstalled on the host, the log source must be removed from the QRadar Console. Additionally, a deploy must be performed on the QRadar Console before logs can be received."
        #Send-MailMessage -To Maritz.InformationSecurity@maritz.com -Subject "WinCollect Installed on $target" -Body $message -SmtpServer mifenmail99.maritz.com -From WinCollectAutomation@maritz.com
    }
    Cleanup
}
else 
{ 
    #Ensure a 64 bit environment and admin rights
    QualifyEnvironment
    SetupEnvironment
    #get-variable -scope local
    $VerbosePreference = "continue"
    Write-Verbose "Running in local installation mode on $env:ComputerName"    
    #Standalone local mode
    if ($bot -ne $True)
    {     
        $PaulDict=Retry("GetDirListing")
        DownloadSourceFiles($PaulDict)        
        UninstallALE 
        UninstallWinCollect
        InstallWinCollect($PaulDict)
        Cleanup
        $message = "WinCollect was installed on $global:fqdn by $env:userdomain\$env:username. If ALE was deinstalled on the host, the log source must be removed from the QRadar Console. Additionally, a deploy must be performed on the QRadar Console before logs can be received."
        Send-MailMessage -To Maritz.InformationSecurity@maritz.com -Subject "WinCollect Installed on $global:fqdn" -Body $message -SmtpServer mifenmail99.maritz.com -From WinCollectAutomation@maritz.com  
    }
    #Running on Remote Target
    else
    {       
        $PaulDict = @{}        
        UninstallALE       
        UninstallWinCollect     
        InstallWinCollect($PaulDict)         
        Cleanup   
    }     
}


}
#----------------------------  WinCollect Specific End  ----------------------------#
#>
#-----------------------#
#
#  Phase 3 Functions
#
#-----------------------#

Function EnablePsRemoting {
Write-Host "Enabling PsRemoting" -Fore Yellow -Nonewline;start-Sleep -Seconds 0
EnablePsRemoting -force > $null
Write-Host " ....Complete" -Fore Green ;start-Sleep -Seconds 0 
}
Function EnablePowershelloverHTTPS {

# Dot Source the Send-File Function
. C:\Scripts\Provisioning\dependencies\DotSource\Get-NetworkStatistics\Get-NetworkStatistics.ps1

$ComputerName = $ENV:ComputerName
$RunAsUser = "System"
$TaskName = "'Enable WinRM over HTTPS'"
$TaskRun = "'PowerShell.exe -NoLogo -File C:\Scripts\Provisioning\dependencies\EnableWinRMHTTPS.ps1'"
$Schedule = "ONCE"
$StartTime = (Get-Date).AddSeconds(70).ToString("HH:mm:ss")

$Command = "schtasks.exe /create /s $ComputerName /ru $RunAsUser /tn $TaskName /tr $TaskRun /sc $Schedule /st $StartTime /F"

Write-Host "Enabling Powershell Remoting Over HTTPS" -Fore Yellow;start-Sleep -Seconds 0

Invoke-Expression $Command

Start-Sleep -Seconds 80

$listeningPorts = Get-NetworkStatistics -State LISTENING
$listenHTTP = $listeningPorts | ForEach-Object { $_.LocalPort -Match "5985" }
$listenHTTPS = $listeningPorts | ForEach-Object { $_.LocalPort -Match "5986" }

If ($listenHTTPS -contains $True) {	Write-Host " ...Complete" -Fore Green;start-Sleep -Seconds 0 }
Else { Write-Host " ...Error" -Fore Red;start-Sleep -Seconds 0  }
}
Function DisablePowershellRemotingoverHTTP {

# Dot Source the Send-File Function
. C:\Scripts\Provisioning\dependencies\DotSource\Get-NetworkStatistics\Get-NetworkStatistics.ps1

$ComputerName = $ENV:ComputerName
$RunAsUser = "System"
$TaskName = "'Disable WinRM over HTTP'"
$TaskRun = "'PowerShell.exe -NoLogo -File C:\Scripts\Provisioning\dependencies\DisableWinRMHTTP.ps1'"
$Schedule = "ONCE"
$StartTime = (Get-Date).AddSeconds(70).ToString("HH:mm:ss")

$Command = "schtasks.exe /create /s $ComputerName /ru $RunAsUser /tn $TaskName /tr $TaskRun /sc $Schedule /st $StartTime /F"

Write-Host "`Disabling Powershell Remoting Over HTTP" -Fore Yellow;start-Sleep -Seconds 0

Invoke-Expression $Command

Start-Sleep -Seconds 80

$listeningPorts = Get-NetworkStatistics -State LISTENING
$listenHTTP = $listeningPorts | ForEach-Object { $_.LocalPort -Match "5985" }
$listenHTTPS = $listeningPorts | ForEach-Object { $_.LocalPort -Match "5986" }

If ($listenHTTP -contains $True) {	Write-Host " ...Error" -Fore Red;start-Sleep -Seconds 0 }
}
Function FtpSetup {
write-host "FTP Setup" -fore yellow -nonewline

# Set the base FTP port
Write-Host "Setting FTP port to 990" -Fore Yellow -NoNewline;start-Sleep -Seconds 0
$ftpPort = 990
Write-Host " ...Complete" -Fore Green;start-Sleep -Seconds 0

# Set the base FTP Description
Write-Host "Setting base FTP Description" -Fore Yellow -NoNewline;start-Sleep -Seconds 0
$grpDesc = "IIS Admin Group"
Write-Host " ...Complete" -Fore Green;start-Sleep -Seconds 0

# FTP authorization group
Write-Host "Setting FTP authorization group" -Fore Yellow -NoNewline;start-Sleep -Seconds 0
$groupFTP = "GRP-IISFTPAccess"
Write-Host " ...Complete" -Fore Green;start-Sleep -Seconds 0

# Import the WebAdministration Module
Write-Host "Importing the WebAdministration Module" -Fore Yellow -NoNewline;start-Sleep -Seconds 0
Import-Module WebAdministration
Write-Host " ...Complete" -Fore Green;start-Sleep -Seconds 0

# Create the Local Deployment Group
Write-Host "Creating the Local Deployment Group" -Fore Yellow -NoNewline;start-Sleep -Seconds 0
$ServerName = $Env:COMPUTERNAME
If ([ADSI]::Exists("WinNT://$ServerName/$groupFTP,group")) {
	Write-Host " ...Group $groupFTP already exists on $ServerName" -Fore Red;start-Sleep -Seconds 0
}
Else {
	$objOu = [ADSI]"WinNT://$ServerName"
	$objGroup = $objOU.Create("Group", $groupFTP)
	$objGroup.SetInfo()
	$objGroup.description = $grpDesc
	$objGroup.SetInfo()
	Write-Host " ...Complete" -Fore Green;start-Sleep -Seconds 0
}

# Create the Base FTP site
Write-Host "Creating the Base FTP site" -Fore Yellow -NoNewline;start-Sleep -Seconds 0
$baseFTPName = "FTPS - $ftpIP"
$newFTP = New-WebFtpSite -Name $baseFTPName -Port $ftpPort -IPAddress $ftpIP -PhysicalPath "C:\inetpub\ftproot"
Write-Host " ...Complete" -Fore Green;start-Sleep -Seconds 0
Write-Host "Info: FTP folder path is C:\inetpub\ftproot" -Fore Cyan;start-Sleep -Seconds 0 

# Enable Basic Authentication in the machine domain
Write-Host "Enabling Basic Authentication in the machine domain" -Fore Yellow -NoNewline;start-Sleep -Seconds 0
$Domain = (Get-WmiObject -Class Win32_ComputerSystem).domain
$shortDomain = ($Domain.split('.')[0]).ToUpper()
Set-ItemProperty $newFTP.PSPath -Name ftpServer.security.authentication.basicAuthentication.enabled -Value $true
Set-ItemProperty $newFTP.PSPath -Name ftpServer.security.authentication.basicAuthentication.defaultLogonDomain -Value $Domain
Write-Host " ...Complete" -Fore Green;start-Sleep -Seconds 0

# Set the site for SSL required and select the certificate
Write-Host "Setting the site for SSL required and select the certificate" -Fore Yellow -NoNewline;start-Sleep -Seconds 0
$Hostname = [System.Net.DNS]::GetHostByName('').HostName
$Cert = dir cert:\localmachine\my | Where-Object {$_.Subject -like '*' + $Hostname + '*' }
$Thumb = $Cert.Thumbprint.ToString()  
Set-ItemProperty $newFTP.PSPath -Name  ftpServer.security.ssl.serverCertHash -Value $Thumb
Set-ItemProperty $newFTP.PSPath -Name ftpServer.security.ssl.controlChannelPolicy -Value 1   # 1: SSLRequire   0: SSLAllow
Set-ItemProperty $newFTP.PSPath -Name ftpServer.security.ssl.dataChannelPolicy -Value 1   # 1: SSLRequire   0: SSLAllow
Write-Host " ...Complete" -Fore Green;start-Sleep -Seconds 0

# Set the FTP authorization group to READ on the base site
Write-Host "Setting the FTP authorization group to READ on the base site" -Fore Yellow -NoNewline;start-Sleep -Seconds 0
Clear-WebConfiguration -Filter /System.FtpServer/Security/Authorization -PSPath IIS: -Location $newFTP.name
Add-WebConfiguration -Filter /System.FtpServer/Security/Authorization -Value (@{AccessType="Allow"; Roles=$groupFTP ; Permissions="Read"}) -PSPath IIS: -Location $newFTP.name
Write-Host " ...Complete" -Fore Green;start-Sleep -Seconds 0

# Enable FTP Directory Browsing - Virtual Directories
#  2: LongDate - Specifies whether to show long dates or short dates.
#  4: StyleUnix - Specifies whether to display UNIX-style directory listings; otherwise, displays MSDOS-style listings.
# 16: DisplayAvailableBytes - Specifies whether to display the available bytes in directory listings.
# 32: DisplayVirtualDirectories - Specifies whether to display virtual directories if set; otherwise, virtual directories are hidden.
# 64: UseGmtTime - Specifies whether to display dates and times in GMT.
Write-Host "Enabling FTP Directory Browsing - Virtual Directories" -Fore Yellow -NoNewline;start-Sleep -Seconds 0
Set-ItemProperty $newFTP.PSPath -Name  ftpServer.directoryBrowse.showFlags -Value 32
Write-Host " ...Complete" -Fore Green;start-Sleep -Seconds 0

If ($newFTP) { Write-Host "FTP Site has been created."-Fore Cyan;start-Sleep -Seconds 3 } 
Else {}

# Add Win_Server_OPS / Ops_Temp Virtual Directory
Write-Host "Adding Win_Server_OPS / Ops_Temp Virtual Directory" -Fore Yellow -NoNewline;start-Sleep -Seconds 0
switch -wildcard ($Domain) {
	"us*" { $opsGroup = "USo_Win_Server_Ops" }
	"mneti*" { $opsGroup = "MNETIo_Win_Server_Ops" }
	"mnete*" { $opsGroup = "MNETEo_Win_Server_Ops" }
	"mpn*" { $opsGroup = "MPNo_Win_Server_Ops" }
	default { $opsGroup = $NULL }
}
Write-Host " ...Complete" -Fore Green;start-Sleep -Seconds 0

# Add Win_Server_Ops to GRP-IISFTPAccess
Write-Host "Adding Win_Server_Ops to GRP-IISFTPAccess" -Fore Yellow -NoNewline;start-Sleep -Seconds 0
$localGroup = [ADSI]"WinNT://$ServerName/$groupFTP,group"
$localGroup.Members() | ForEach-Object {
	# Load member name
	$groupMember = $_.GetType().InvokeMember('AdsPath', 'GetProperty', $null, $_, $null)
	If ($groupMember -eq "WinNT://$shortDomain/$opsGroup") { 
	$acctExists = $true
	Write-Host " ...Complete" -Fore Green;start-Sleep -Seconds 0}
	Else {
	}
}
If ($acctExists) { 
Write-Verbose "Account already in group" 
}
Else { 
$localGroup.psbase.Invoke("Add",([ADSI]"WinNT://$Domain/$opsGroup").path) 
Write-Host " ...Complete" -Fore Green;start-Sleep -Seconds 0
}

# Create the Virtual Directory and apply authentication rules
Write-Host "Creating the Virtual Directory and apply authentication rules" -Fore Yellow -NoNewline;start-Sleep -Seconds 0
If (($opsGroup) -and (Test-Path "D:\Ops_Temp")) {
	# Add the Virtual Directory for the Ops_Temp folder
	$newVDOps = New-Item "IIS:\Sites\$baseFTPName\Ops_Temp" -Type VirtualDirectory -PhysicalPath "D:\Ops_Temp"
	Remove-WebConfigurationProperty -Filter /System.FtpServer/Security/Authorization -PSPath IIS: -Location "$baseFTPName/Ops_Temp" -Name Collection
	Add-WebConfiguration -Filter /System.FtpServer/Security/Authorization -Value (@{AccessType="Allow"; Roles="$shortDomain\$opsGroup" ; Permissions="Read,Write"}) -PSPath IIS: -Location "$baseFTPName/Ops_Temp"
	Write-Host " ...Complete" -Fore Green;start-Sleep -Seconds 0
}
Else {
Write-Host " ...Skipped" -Fore Red;start-Sleep -Seconds 0
}

# Set FTP Firewall Support Data Channel Port Range
$WebConfigFW = get-webconfiguration system.ftpServer/firewallSupport
$WebConfigFW.lowDataChannelPort = 20000
$WebConfigFW.highDataChannelPort = 20500
$WebConfigFW | Set-WebConfiguration system.ftpServer/firewallSupport

# Create FTPsvc folder in D:\Logs\ftpsvc if one does not exist
$FTPlogfolder = test-path d:\Logs\ftpsvc
Write-Host "Creating D:\Logs\ftpsvc folder" -Fore Yellow -NoNewline;start-Sleep -Seconds 0
If ($FTPlogfolder -like "False"){
FtpFolderCreation | Out-Null
Write-Host " ...Complete" -Fore Green 
}
Else{
Write-Host " ...Folder already in place" -Fore Red 
}

# Move Logs to D:\Logs
Write-Host "Moving Logs to D:\Logs" -Fore Yellow -NoNewline;start-Sleep -Seconds 0
Import-Module WebAdministration
Set-WebConfigurationProperty "/System.applicationhost/sites/sitedefaults" -name logfile.directory -value "D:\Logs"
Set-ItemProperty "IIS:\" .sitedefaults.ftpserver.logfile.directory "D:\Logs"
Write-Host " ...Complete" -Fore Green;start-Sleep -Seconds 0

# Adding GRP-IISFTPAccess to the D:\Logs folder
Write-Host "Adding GRP-IISFTPAccess to the D:\Logs folder" -Fore Yellow -NoNewline
$folder = "D:\Logs"
$myGroup = "GRP-IISFTPAccess"
$acl = Get-Acl $folder
$rule = New-Object System.Security.AccessControl.FileSystemAccessRule("$myGroup", "Read", "ContainerInherit, ObjectInherit", "None", "Allow")
$acl.AddAccessRule($rule)
$rule = New-Object System.Security.AccessControl.FileSystemAccessRule("$myGroup", "ReadandExecute", "ContainerInherit, ObjectInherit", "None", "Allow")
$acl.AddAccessRule($rule)
Set-Acl $folder $acl
Write-Host " ...Complete" -Fore Green

# Adding GRP-IISFTPAccess to the C:\Inetpub\ftproot
Write-Host "Adding GRP-IISFTPAccess to the C:\Inetpub\ftproot" -Fore Yellow -NoNewline
$folder = "C:\Inetpub\ftproot"
$myGroup = "GRP-IISFTPAccess"
$acl = Get-Acl $folder
$rule = New-Object System.Security.AccessControl.FileSystemAccessRule("$myGroup", "Read", "ContainerInherit, ObjectInherit", "None", "Allow")
$acl.AddAccessRule($rule)
$rule = New-Object System.Security.AccessControl.FileSystemAccessRule("$myGroup", "ReadandExecute", "ContainerInherit, ObjectInherit", "None", "Allow")
$acl.AddAccessRule($rule)
Set-Acl $folder $acl
Write-Host " ...Complete" -Fore Green
write-host " ...Complete" -fore green
}
function FtpFolderCreation {
New-Item D:\Logs\ftpsvc -type directory
}
Function RenameAdminandGuest2008 {
# Define Variables
$computer = $env:Computername
$oldAdmin = "Administrator"
$newAdmin = "blatanha"
$oldGuest = "Guest"
$newGuest = "bocefus"

$encPW = get-content "C:\Scripts\Provisioning\dependencies\RemoteFunctions\New-RemoteSession\blatanha.cred"
$pi = get-content "C:\Scripts\Provisioning\dependencies\RemoteFunctions\New-RemoteSession\PI.key"
$ssPW = ConvertTo-SecureString $encPW -key $pi
$userCred = New-Object System.Management.Automation.PSCredential $newAdmin,$ssPW
# Rename the Administrator account
Write-Host "`nRenaming Admin account to [ Blatanha ]" -Fore Yellow -NoNewline;start-Sleep -Seconds 0 
$account = ([adsi]"WinNT://$computer/$oldAdmin")
$account.psbase.rename($newAdmin)
Write-Host " ...Complete" -Fore Green;start-Sleep -Seconds 0 
# Set Administrator password to not expire
Write-Host "Setting Admin password to never expire" -Fore Yellow -NoNewline;start-Sleep -Seconds 0 
$newFlags = $account.UserFlags.value -bor $ADS_UF_DONT_EXPIRE_PASSWD
$account.UserFlags.value = $newFlags
$account.commitChanges()
Write-Host " ...Complete" -Fore Green;start-Sleep -Seconds 0 
# Reset Administrator password
Write-Host "Changing Admin password" -Fore Yellow -NoNewline;start-Sleep -Seconds 0 
$account.SetPassword(“Bl@ck*Y@k!”)
Write-Host " ...Complete" -Fore Green;start-Sleep -Seconds 0 
#Rename the Guest account
Write-Host "Renaming Guest account to [ Bocefus ]" -Fore Yellow -NoNewline;start-Sleep -Seconds 0 
$account = ([adsi]"WinNT://$computer/$oldGuest")
$account.psbase.rename($newGuest)
Write-Host " ...Complete" -Fore Green;start-Sleep -Seconds 0 
}
Function RenameAdminandGuest2012 {
# Define Variables
$computer = $env:Computername
$oldAdmin = "Administrator"
$newAdmin = "blatanha"
$oldGuest = "Guest"
$newGuest = "bocefus"

$encPW = get-content "C:\Scripts\Provisioning\dependencies\RemoteFunctions\New-RemoteSession\blatanha.cred"
$pi = get-content "C:\Scripts\Provisioning\dependencies\RemoteFunctions\New-RemoteSession\PI.key"
$ssPW = ConvertTo-SecureString $encPW -key $pi
$userCred = New-Object System.Management.Automation.PSCredential $newAdmin,$ssPW
# Rename the Administrator account
Write-Host "`nRenaming Admin account to [ Blatanha ]" -Fore Yellow -NoNewline;start-Sleep -Seconds 0 
$account = ([adsi]"WinNT://$computer/$oldAdmin")
$account.psbase.rename($newAdmin)
Write-Host " ...Complete" -Fore Green;start-Sleep -Seconds 0 
# Set Administrator password to not expire
Write-Host "Setting Admin password to never expire" -Fore Yellow -NoNewline;start-Sleep -Seconds 0 
$newFlags = $account.UserFlags.value -bor $ADS_UF_DONT_EXPIRE_PASSWD
$account.UserFlags.value = $newFlags
$account.commitChanges()
Write-Host " ...Complete" -Fore Green;start-Sleep -Seconds 0 
# Reset Administrator password
Write-Host "Changing Admin password" -Fore Yellow -NoNewline;start-Sleep -Seconds 0 
$account.SetPassword($userCred.GetNetworkCredential().Password)
$account.SetInfo()
Write-Host " ...Complete" -Fore Green;start-Sleep -Seconds 0 
#Rename the Guest account
Write-Host "Renaming Guest account to [ Bocefus ]" -Fore Yellow -NoNewline;start-Sleep -Seconds 0 
$account = ([adsi]"WinNT://$computer/$oldGuest")
$account.psbase.rename($newGuest)
Write-Host " ...Complete" -Fore Green;start-Sleep -Seconds 0 
}

