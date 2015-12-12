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
			Add-Content D:\Scripts\Output\PS_Version_Check2.csv "$computerName,NOSESSION"
			Exit
		}
	}
}

$scriptPath = split-path -parent $MyInvocation.MyCommand.Definition

If (!($computername))
{
	Write-host "`n---------------------------------------" -fore red
	Write-host "PsVersion Check2" -fore red
	Write-host "---------------------------------------`n" -fore red
	$computername = read-host "What is the server to be probed"
}
Else {}

Write-host "`n[ $computerName ]" -fore cyan
$ErrorActionPreference = 'SilentlyContinue'
if (!(test-connection $computerName))
{ 
	Add-Content D:\Scripts\Output\PS_Version_Check2.csv "$computerName,NOPING"
	write-host "NO PING " -fore red
	Exit
}
$ErrorActionPreference = 'Continue'

EstablishSession
$GETPSVER = Invoke-Command -Session $Session -ScriptBlock {
	function GetPsVer {
		Write-host "Powershell Version is " -fore yellow -nonewline
		$GETPSVER = $PSVersionTable.PSVersion.Major
		return $GETPSVER
	}
	GetPsVer
}
write-host "$GETPSVER" -fore white

$rebootneeded = Invoke-Command -Session $Session -ScriptBlock {
	function RebootCheck {
	if (test-path 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\WindowsUpdate\Auto Update\RebootRequired') 
	{
		$result = "yes"
		return $result
	}
	Else 
	{
		$result = "no"
		return $result
	}
	}
	RebootCheck
}

Add-Content D:\Scripts\Output\PS_Version_Check2.csv "$computerName,$GETPSVER,$rebootneeded"