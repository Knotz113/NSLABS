# WindowsUpdate_PS_config.ps1
#
# DESCRIPTION: This script will:
#   - Update the Windows code from the Microsoft update site
#
# REVISIONS:
# 20130603 - Original release - Greg Galbraith
#
# *********************************************************************************
# DO NOT USE IN A PRODUCTION ENVIRONMENT UNTIL YOU HAVE TESTED IN A LAB ENVIRONMENT
# *********************************************************************************
#
# 
# Import module for Windows updating
import-module C:\Scripts\Provisioning\WinUpdates\PSWindowsUpdate

# Install updates
#get-wulist
#get-wuinstall -AcceptAll -AutoReboot
Get-WUInstall -Category "security updates", "critical" -acceptall -IgnoreReboot