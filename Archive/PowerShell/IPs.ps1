########################################################################################
#
#    MARITZ - AUTOMATED WINCOLLECT SCRIPT												
#    NAME: PsRemoting_Disable_Enable.ps1																	
# 
#    AUTHOR:  Nathan Storm
#    DATE:  12/4/2014
# 
#    COMMENT:  This script will - Look into a csv list of servers, connect to those servers, and install run WinCollect scripts
#
#    VERSION HISTORY
#    1.000 - initial creation
#
#	 Description
#    This script look into the csv file, use that list of server and for each server will use Psexec to remote to the machine and 
#	 turn on PSremote.  Then it will connect to that server and run WinCollect scripts.  Lastly, it will use Psexec again to disable-psremoting.
#	 It will then continue in this fashion for all servers listed in the CSV file.
#
########################################################################################

Function Write-Centered-Red {
    Param(  [string] $message,
            [string] $color = "red")
    $offsetvalue = [Math]::Round(([Console]::WindowWidth / 2) + ($message.Length / 2))
    Write-Host ("{0,$offsetvalue}" -f $message) -ForegroundColor $color
}

Function Get-DNS{
$dnschk = $NULL
$dnsexist =$NULL
$ErrorActionPreference= "silentlycontinue"
$dnschk = [System.Net.DNS]::GetHostAddresses("$comp")
$dnsip = $dnschk.IPAddressToString 
if ($dnsip -match "(\d{1,3}).(\d{1,3}).(\d{1,3}).(\d{1,3})") {
Write-host " ...$dnsip" -Fore White
} else {
write-host " ...No DNS entry found." -Fore Red;start-Sleep -Seconds 2
}
}

Function CheckIPisActive {
$testconnection = Test-Connection -computer $comp -quiet
if ($testconnection -eq "true"){
Get-DNS
} Else {
Write-host " ...Workstation is not responding to ping."-Fore Red
}
}

CLS

#--- Header ---*
write-host "`n`n"
Write-Centered-Red "*-----------------------------------------------------------------------------------*"
Write-Centered-Red "Maritz Win Collect Script"
Write-Centered-Red "*-----------------------------------------------------------------------------------*`n`n"

write-host ""

# csv file location and import to a variable
$FilePath = "D:\Scripts\workstations.csv"
$workstations = Import-CSV $FilePath 

# view contents of csv file and perform set actions against each one
ForEach ($workstation in $workstations){ 
$comp1 = $($workstation.workstations)
$comp = "M"+$comp1
Write-Host "Querying IP for [ $comp ]" -Fore Yellow -Nonewline #;start-Sleep -Seconds 2
Get-DNS
 
}
