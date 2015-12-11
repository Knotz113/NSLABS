<# 
.SYNOPSIS 
Add HTTPS listener is for WinRM

.DESCRIPTION 
Add HTTPS listener is for WinRM

.NOTES     
Author     : Brad Hoppe
Created    : 1/27/2014
Requires   : WinRM is intalled and configured
Revisions  : 

#> 

$hostname = [System.Net.DNS]::GetHostByName('').HostName
$Transport = winrm enumerate winrm/config/listener
$containsHTTPS = $Transport | ForEach-Object { $_ -Match "HTTPS" }

If ($containsHTTPS -contains $True) {
	Write-Host "INFO: WinRM HTTPS already configured."
}
Else {
	$Cert = dir cert:\localmachine\my | Where-Object {$_.Subject -like '*' + $hostname + '*' }
	$Cert
	$Thumb = $Cert.Thumbprint.ToString()    
	If ($Thumb) {
		#Configure WinRM HTTPS listener
		$hostname
		$Thumb
		winrm create winrm/config/Listener?Address=*+Transport=HTTPS `@`{Hostname=`"$hostname`"`;CertificateThumbprint=`"$Thumb`"`}
	}
}


# Add Certificate Store Name to fix SSL binding issue in IIS
$WinRMSsl = Get-ChildItem HKLM:\SYSTEM\CurrentControlSet\services\HTTP\Parameters\SslBindingInfo | Where-Object { $_.Name -like "*0.0.0.0:5986" }
If ($WinRMSsl) {
	Set-Location HKLM:\SYSTEM\CurrentControlSet\services\HTTP\Parameters\SslBindingInfo
	New-ItemProperty .\0.0.0.0:5986 -Name "SslCertStoreName" -Value "MY" -PropertyType "String"
}

#Enumerate WinRM listners
winrm enumerate winrm/config/listener 
