########################################################################################
#
#    MARITZ - AUTOMATED POST SCRIPTS - POWERSHELL SCRIPT												
#    NAME: basic.ps1																	
# 
#    AUTHOR:  Nathan Storm
#    DATE:  11/14/2014
# 
#    COMMENT:  This script will perform the basic settings needed by all servers
#
#    VERSION HISTORY
#    1.000 - initial creation
#    1.001 - added the ability to detect all named drives and expand them to their max size as presented by vmware
#
#	 Description
#    
#
########################################################################################

Function New-RegistryKey([string]$key,[string]$Name,[string]$type,[string]$value){
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
Function RegAction{
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
Function Remove-DriveAccount{
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

$getos = Get-WmiObject Win32_OperatingSystem
$getosversion = $getos.version

#--- Error Checking set to prompt for action ---*
$time = "0"

#--- Error Checking set to prompt for action ---*
$ErrorActionPreference = "inquire"

write-host "`nDetecting Operating System" -Fore Yellow -NoNewline;start-Sleep -Seconds $time 
IF (($getosversion -like "6.2*") -or ($getosversion -like "6.3*")){
Write-Host " ...Server 2012 Detected" -Fore Green;start-Sleep -Seconds $time 
}
Elseif ($getosversion -like "6.1*"){
Write-Host " ...Server 2008 Detected" -Fore Green;start-Sleep -Seconds $time
}
Else {
Write-Host " ...Server OS is not 2012 or 2008" -Fore Red;start-Sleep -Seconds $time
}

Write-Host "Set Time Zone to Central Standard" -Fore Yellow -NoNewline;start-Sleep -Seconds $time
#-------------- Set Time Zone to Central Standard -----------------#
Set-TimeZone "Central Standard Time"
Write-Host " ...Complete" -Fore Green;start-Sleep -Seconds $time

IF (($getosversion -like "6.2*") -or ($getosversion -like "6.3*")){
Write-Host "Turning off FW" -Fore Yellow -NoNewline;start-Sleep -Seconds $time
#-------------- Turning off FW -----------------#
Get-NetFirewallProfile | Set-NetFirewallProfile -Enabled False
Write-Host " ...Complete" -Fore Green;start-Sleep -Seconds $time
}
Elseif ($getosversion -like "6.1*"){
}
Else {
}


Write-Host "Change CD Rom letter to R" -Fore Yellow -NoNewline;start-Sleep -Seconds $time
#-------------- Change CD Rom letter to R -----------------#
(gwmi Win32_cdromdrive).drive | %{$a=mountvol $_ /l;mountvol $_ /d;$a=$a.Trim();mountvol r: $a}
Write-Host " ...Complete" -Fore Green;start-Sleep -Seconds $time


Write-Host "Change Windows Update to Never Check for Updates" -Fore Yellow -NoNewline;start-Sleep -Seconds $time
#-------------- Change Windows Update to Never Check for Updates -----------------#
#$WUSettings = (New-Object -com "Microsoft.Update.AutoUpdate").Settings
#$WUSettings.NotificationLevel=1
#$WUSettings.save()
$UpdateValue = 1
$AutoUpdatePath = "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\WindowsUpdate\Auto Update"
Set-ItemProperty -Path $AutoUpdatePath -Name AUOptions -Value $UpdateValue
Write-Host " ...Complete" -Fore Green;start-Sleep -Seconds $time


Write-Host "Enable Remote Desktop" -Fore Yellow -NoNewline;start-Sleep -Seconds $time
#-------------- Enable Remote Desktop -----------------#
$regKey = "HKLM:\SYSTEM\CurrentControlSet\Control\Terminal Server"
Set-ItemProperty $regKey fDenyTsConnections 0
Write-Host " ...Complete" -Fore Green;start-Sleep -Seconds $time

Write-Host "Set event log attributes" -Fore Yellow -NoNewline;start-Sleep -Seconds $time
#-------------- Set event log attributes -----------------#
Limit-EventLog -LogName Application -MaximumSize 65536kb -OverflowAction OverwriteAsNeeded
Limit-EventLog -LogName Security -MaximumSize 81920kb -OverflowAction OverwriteAsNeeded
Limit-EventLog -LogName System -MaximumSize 65536kb -OverflowAction OverwriteAsNeeded
Write-Host " ...Complete" -Fore Green;start-Sleep -Seconds $time

Write-Host "Turn Off UAC" -Fore Yellow -NoNewline;start-Sleep -Seconds $time
#-------------- Turn Off UAC-----------------#
Set-ItemProperty -path "HKLM:SOFTWARE\Microsoft\Windows\CurrentVersion\policies\system" -name EnableLUA -value 0
Write-Host " ...Complete" -Fore Green;start-Sleep -Seconds $time

Write-Host "Turn Off Server Manager From Opening Automatically On Startup" -Fore Yellow -NoNewline;start-Sleep -Seconds $time
#-------------- Turn Off Server Manager From Opening Automatically On Startup-----------------#
Set-ItemProperty -path "HKLM:SOFTWARE\Microsoft\ServerManager" -name DoNotOpenServerManagerAtLogon -value 1
Set-ItemProperty -path "HKLM:SOFTWARE\Microsoft\ServerManager\Oobe" -name DoNotOpenInitialConfigurationTasksAtLogon -value 1
Write-Host " ...Complete" -Fore Green;start-Sleep -Seconds $time

Write-Host "Always Show Icons and Notifications" -Fore Yellow -NoNewline;start-Sleep -Seconds $time
#-------------- Always Show Icons and Notifications-----------------#
New-RegistryKey "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer" "EnableAutoTray" "Dword" "0"
Write-Host " ...Complete" -Fore Green;start-Sleep -Seconds $time

#-------------- Create Logs folder on the D drive -----------------#
Write-Host "Creating Logs folder on the D drive" -Fore Yellow -NoNewline;start-Sleep -Seconds $time
$drivepath = Test-Path d:\logs
If ($drivepath -eq "True") {
Write-Host " ...Folder already in place" -Fore Cyan;start-Sleep -Seconds $time
}
Else {
CreateDLogsFolder | out-null
Write-Host " ...Complete" -Fore Green;start-Sleep -Seconds $time
}



Write-Host "ADS_USER_FLAG_ENUM Enumeration" -Fore Yellow -NoNewline;start-Sleep -Seconds $time
#-------------- ADS_USER_FLAG_ENUM Enumeration -----------------#
# http://msdn.microsoft.com/en-us/library/aa772300(VS.85).aspx
$ADS_UF_SCRIPT                                   = 1         # 0x1
$ADS_UF_ACCOUNTDISABLE                           = 2         # 0x2
$ADS_UF_HOMEDIR_REQUIRED                         = 8         # 0x8
$ADS_UF_LOCKOUT                                  = 16        # 0x10
$ADS_UF_PASSWD_NOTREQD                           = 32        # 0x20
$ADS_UF_PASSWD_CANT_CHANGE                       = 64        # 0x40
$ADS_UF_ENCRYPTED_TEXT_PASSWORD_ALLOWED          = 128       # 0x80
$ADS_UF_TEMP_DUPLICATE_ACCOUNT                   = 256       # 0x100
$ADS_UF_NORMAL_ACCOUNT                           = 512       # 0x200
$ADS_UF_INTERDOMAIN_TRUST_ACCOUNT                = 2048      # 0x800
$ADS_UF_WORKSTATION_TRUST_ACCOUNT                = 4096      # 0x1000
$ADS_UF_SERVER_TRUST_ACCOUNT                     = 8192      # 0x2000
$ADS_UF_DONT_EXPIRE_PASSWD                       = 65536     # 0x10000
$ADS_UF_MNS_LOGON_ACCOUNT                        = 131072    # 0x20000
$ADS_UF_SMARTCARD_REQUIRED                       = 262144    # 0x40000
$ADS_UF_TRUSTED_FOR_DELEGATION                   = 524288    # 0x80000
$ADS_UF_NOT_DELEGATED                            = 1048576   # 0x100000
$ADS_UF_USE_DES_KEY_ONLY                         = 2097152   # 0x200000
$ADS_UF_DONT_REQUIRE_PREAUTH                     = 4194304   # 0x400000
$ADS_UF_PASSWORD_EXPIRED                         = 8388608   # 0x800000
$ADS_UF_TRUSTED_TO_AUTHENTICATE_FOR_DELEGATION   = 16777216  # 0x1000000

Write-Host " ...Complete" -Fore Green;start-Sleep -Seconds $time
#-------------- Reg Actions -----------------#
#
# a - Maritz Custom Reg Inserts
# b - SNMP configuration
# c - Disable IPV6
# d - Driver Signing Policy setting
# e - Protocol Settings
# f - Null Session Shares
# g - Cipher Changes.


Write-Host "SNMP configuration" -Fore Yellow -NoNewline;start-Sleep -Seconds $time
#b
RegAction "RegWrite" "HKLM:\SYSTEM\CurrentControlSet\services\SNMP\Parameters\PermittedManagers" "1" "156.45.55.61" "String"
RegAction "RegWrite" "HKLM:\SYSTEM\CurrentControlSet\services\SNMP\Parameters\PermittedManagers" "2" "127.0.0.1" "String"
RegAction "RegWrite" "HKLM:\SYSTEM\CurrentControlSet\services\SNMP\Parameters\PermittedManagers" "3" "156.45.55.117" "String"
RegAction "RegWrite" "HKLM:\SYSTEM\CurrentControlSet\services\SNMP\Parameters\TrapConfiguration\NetManagers" "1" "156.45.55.117" "String"
RegAction "RegWrite" "HKLM:\SYSTEM\CurrentControlSet\services\SNMP\Parameters\TrapConfiguration\NetManagers" "2" "156.45.55.61" "String"
RegAction "RegWrite" "HKLM:\SYSTEM\CurrentControlSet\services\SNMP\Parameters\ValidCommunities" "NetManagers" "8" "Dword"
RegAction "RegWrite" "HKLM:\SYSTEM\CurrentControlSet\services\SNMP\Parameters\ValidCommunities" "Public" "1" "Dword"
Write-Host " ...Complete" -Fore Green;start-Sleep -Seconds $time
#c
Write-Host "Disable IPV6" -Fore Yellow -NoNewline;start-Sleep -Seconds $time
RegAction "RegWrite" "HKLM:\SYSTEM\CurrentControlSet\Services\Tcpip6\Parameters" "DisabledComponents" "0xFFFFFFFF" "DWord"
Write-Host " ...Complete" -Fore Green;start-Sleep -Seconds $time
#d
Write-Host "Driver Signing Policy setting" -Fore Yellow -NoNewline;start-Sleep -Seconds $time
RegAction "RegWrite" "HKLM:\SOFTWARE\Microsoft\Driver Signing" "Policy" "01" "Binary"
Write-Host " ...Complete" -Fore Green;start-Sleep -Seconds $time
#e
Write-Host "Protocol Settings" -Fore Yellow -NoNewline;start-Sleep -Seconds $time
RegAction "RegWrite" "HKLM:\SYSTEM\CurrentControlSet\Control\SecurityProviders\SCHANNEL\Protocols\PCT 1.0\Client" "Enabled" "0" "DWord"
RegAction "RegWrite" "HKLM:\SYSTEM\CurrentControlSet\Control\SecurityProviders\SCHANNEL\Protocols\PCT 1.0\Server" "Enabled" "0" "DWord"
RegAction "RegWrite" "HKLM:\SYSTEM\CurrentControlSet\Control\SecurityProviders\SCHANNEL\Protocols\SSL 2.0\Client" "Enabled" "0" "DWord"
RegAction "RegWrite" "HKLM:\SYSTEM\CurrentControlSet\Control\SecurityProviders\SCHANNEL\Protocols\SSL 2.0\Server" "Enabled" "0" "DWord"
Write-Host " ...Complete" -Fore Green;start-Sleep -Seconds $time
#f
Write-Host "Null Session Shares" -Fore Yellow -NoNewline;start-Sleep -Seconds $time
RegAction "RegWrite" "HKLM:\SYSTEM\CurrentControlSet\Services\LanmanServer\Parameters" "NullSessionShares" "7" "Binary"
Write-Host " ...Complete" -Fore Green;start-Sleep -Seconds $time
#g

