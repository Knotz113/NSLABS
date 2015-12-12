<# 
.SYNOPSIS 
Check it HTTPS listener is configured and if so, delete the HTTP listener for WinRM

.DESCRIPTION 
Check it HTTPS listener is configured and if so, delete the HTTP listener for WinRM

.NOTES     
Author     : Brad Hoppe
Created    : 1/27/2014
Requires   : WinRM HTTPS listener is configured
Revisions  : 

#> 

# Check it HTTPS listenner is configured
$Transport = winrm enumerate winrm/config/listener
$containsHTTPS = $Transport | ForEach-Object { $_ -Match "HTTPS" }

if ($containsHTTPS -contains $True) {
	# Delete HTTP listener:
	winrm delete winrm/config/Listener?Address=*+Transport=HTTP
}
else {
	Write-Host "ERROR: WinRM HTTPS not configured. Configure HTTPS before disabling HTTP."
}

# Enumerate WinRM listners
winrm enumerate winrm/config/listener 