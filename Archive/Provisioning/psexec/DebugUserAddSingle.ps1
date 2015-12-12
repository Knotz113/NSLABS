Param(
    [Parameter(Mandatory = $false)]
    [String]$computerName
)

Function EstablishSession {
	if(Test-Path "$scriptPath\..\RemoteFunctions\New-RemoteSession\New-RemoteSession.ps1") 
	{
		$command = "$scriptPath\..\RemoteFunctions\New-RemoteSession\New-RemoteSession.ps1 -ComputerName $computername -UseRunBook -maxwait 10"
		$global:Session = Invoke-Expression $command
		if (!($session))
		{
			Exit
		}
	}
}

$scriptPath = split-path -parent $MyInvocation.MyCommand.Definition

If (!($computername))
{
	Write-host "`n---------------------------------------" -fore red
	Write-host "DebugUser Add" -fore red
	Write-host "---------------------------------------`n" -fore red
	$computername = read-host "What is the server to be probed"
}
Else {}

###################
Write-host "$computername" -fore Cyan
$ErrorActionPreference = 'SilentlyContinue'
Write-host "Ping Check" -fore yellow -nonewline
if (test-connection $computername)
{ 
	Write-host " ...Pass" -fore green
}
Else 
{
	Write-host " ...Fail" -fore red
	Exit
}
$ErrorActionPreference = 'Continue'

EstablishSession

$GETPSVER = Invoke-Command -Session $Session -ScriptBlock {
	function GetPsVer 
	{
		$GETPSVER = (Get-WmiObject Win32_OperatingSystem).Name
		return $GETPSVER
	}
GetPsVer
}
Write-host "OS Check" -fore yellow -nonewline
If ($GETPSVER -like "*2008*")
{
	Write-host " ...2008" -fore Green
}
Else 
{
	Write-host " ...2012" -fore Red
	Exit
}

Robocopy.exe D:\Scripts\Provisioning\psexec\SendFiles \\$computerName\c$\Scripts\Provisioning\DebugUserAdd *.* /E
Invoke-Command -Session $Session -ScriptBlock {c:\Scripts\Provisioning\DebugUserAdd\Install.ps1 Administrators}
Invoke-Command -Session $Session -ScriptBlock {c:\Scripts\Provisioning\DebugUserAdd\Install.ps1 US\s_uCMDBDiscovery}