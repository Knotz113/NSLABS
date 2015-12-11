Function SetSNCreds {
If (($hostname -eq "fenappmgp20") -or ($hostname -eq "fenappmgp03")){
$script:username = "us\S_ServiceNowRB_US"
$script:password = ""
}
ElseIf ($hostname -eq "fenappmgp05"){
$script:username = "MNETI\S_ServiceNowRB_MNETI"
$script:password = ""
}
ElseIf ($hostname -eq "fenappmgp09"){
$script:username = "MPNI\S_ServiceNowRB_MPNI"
$script:password = ""
}
ElseIf ($hostname -eq "fenappmgp04"){
$script:username = "MPNE\S_ServiceNowRB_MPNE"
$script:password = ""
}
ElseIf ($hostname -eq "fenappmgp08"){
$script:username = "MPN\S_ServiceNowRB_MPN"
$script:password = ""
}
ElseIf ($hostname -eq "fenappmgp06"){
$script:username = "MNETE\S_ServiceNowRB_MNETe"
$script:password = ""
}
Else {}
}
Function PsexecRemoteCommandSend {
$commandBytes = [System.Text.Encoding]::Unicode.GetBytes($expression)
$encodedCommand = [Convert]::ToBase64String($commandBytes)
.\PsExec.exe \\$servername -u $servername\$username -p $password cmd /c “echo . | powershell -EncodedCommand $encodedCommand” >> .\Output\stdout.txt 2>> .\Output\stderr.txt 
}
Function PsexecRemoteCommandSendDomainAccount {
$commandBytes = [System.Text.Encoding]::Unicode.GetBytes($expression)
$encodedCommand = [Convert]::ToBase64String($commandBytes)
.\PsExec.exe \\$servername -u $username -p $password cmd /c “echo . | powershell -EncodedCommand $encodedCommand” >> .\Output\stdout.txt 2>> .\Output\stderr.txt
}
Function Header {
Write-host "`n---------------------------------------" -fore red
Write-host "Accessibility Check" -fore red
Write-host "---------------------------------------`n" -fore red
}

$hostname = ($env:computername)
$scriptPath = split-path -parent $MyInvocation.MyCommand.Definition

Clear
Header
Write-host "[1] Full Scan" -fore yellow
Write-host "[2] Single Port Scan" -fore yellow
Write-host "[3] Cred Check`n" -fore yellow
$menuselect = read-host "Make selection"
clear
Header
$servername = read-host "What is the server to be probed"

switch ($menuselect)
{
	1 
	{
		Write-host "`n[ $servername ]" -fore cyan
		$ErrorActionPreference = 'SilentlyContinue'
		write-host "Pinging $servername" -fore yellow -nonewline
		if (test-connection $servername) 
		{ 
			write-host " ...Pass" -fore green 
		}
		Else 
		{
			write-host " ...Fail" -fore red 
		}
		$ErrorActionPreference = 'Continue'
	
		$port = 5985 
		Write-host "Checking HTTP listening port $port" -fore yellow -nonewline
		$ErrorActionPreference = 'SilentlyContinue'
		If (New-Object System.Net.Sockets.TCPClient -ArgumentList $servername,$port) 
		{ 
			Write-Host ' ...Port Open' -fore green 
		}
		If ($? -eq $false) 
		{ 
			Write-Host ' ...Port Not Accessible' -fore red 
		}
		$ErrorActionPreference = 'Continue'
	
		$port = 5986 
		Write-host "Checking HTTPS listening port $port" -fore yellow -nonewline
		$ErrorActionPreference = 'SilentlyContinue'
		If (New-Object System.Net.Sockets.TCPClient -ArgumentList $servername,$port) 
		{ 
			Write-Host ' ...Port Open' -fore green 
		}
		If ($? -eq $false) 
		{ 
			Write-Host ' ...Port Not Accessible' -fore red 
		}
		$ErrorActionPreference = 'Continue'
	
		$port = 135 
		Write-host "Checking Psexec port $port" -fore yellow -nonewline
		$ErrorActionPreference = 'SilentlyContinue'
		If (New-Object System.Net.Sockets.TCPClient -ArgumentList $servername,$port) 
		{ 
			Write-Host ' ...Port Open' -fore green 
		}
		If ($? -eq $false) 
		{ 
			Write-Host ' ...Port Not Accessible' -fore red 
		}
		$ErrorActionPreference = 'Continue'
	
		$port = 445 
		Write-host "Checking Psexec port $port" -fore yellow -nonewline
		$ErrorActionPreference = 'SilentlyContinue'
		If (New-Object System.Net.Sockets.TCPClient -ArgumentList $servername,$port) 
		{ 
			Write-Host ' ...Port Open' -fore green 
		}
		If ($? -eq $false) 
		{ 
			Write-Host ' ...Port Not Accessible' -fore red 
		}
		$ErrorActionPreference = 'Continue'
	
		$username = "blatanha"
		$password = "Bl@ck*Y@k!"
		write-host "Cred check for [ $username ] against [ $servername ]" -fore yellow -nonewline
		$expression = “winrm enumerate winrm/config/listener”
		PsexecRemoteCommandSend
		if ($LastExitCode -eq "0") 
		{ 
			write-host " ...Pass" -fore green 
		}
		Else 
		{ 
			write-host " ...Fail" -fore Red 
		}
	
		$username = "Inoc"
		$password = "Wttm030(3"
		write-host "Cred check for [ $username ] against [ $servername ]" -fore yellow -nonewline
		$expression = “winrm enumerate winrm/config/listener”
		PsexecRemoteCommandSend
		if ($LastExitCode -eq "0") 
		{ 
			write-host " ...Pass" -fore green 
		}
		Else 
		{ 
			write-host " ...Fail" -fore Red 
		}
	}
	2
	{
		$port = read-host "What port do you want to check"
		Write-host "Checking port [ $port ] on [ $servername ]" -fore yellow -nonewline
		$ErrorActionPreference = 'SilentlyContinue'
		If (New-Object System.Net.Sockets.TCPClient -ArgumentList $servername,$port) 
		{ 
			Write-Host ' ...Port Open' -fore green 
		}
		If ($? -eq $false) 
		{ 
			Write-Host ' ...Port Not Accessible' -fore red 
		}
		$ErrorActionPreference = 'Continue'
	}
	3
	{
		$username = "blatanha"
		$password = "Bl@ck*Y@k!"
		write-host "Cred check for [ $username ] against [ $servername ]" -fore yellow -nonewline
		$expression = “winrm enumerate winrm/config/listener”
		PsexecRemoteCommandSend
		if ($LastExitCode -eq "0") 
		{ 
			write-host " ...Pass" -fore green 
		}
		Else 
		{ 
			write-host " ...Fail" -fore Red 
		}
	
		$username = "Inoc"
		$password = "Wttm030(3"
		write-host "Cred check for [ $username ] against [ $servername ]" -fore yellow -nonewline
		$expression = “winrm enumerate winrm/config/listener”
		PsexecRemoteCommandSend
		if ($LastExitCode -eq "0") 
		{ 
			write-host " ...Pass" -fore green 
		}
		Else 
		{ 
			write-host " ...Fail" -fore Red 
		}
	}
}