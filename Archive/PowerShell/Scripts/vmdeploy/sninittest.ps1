########################################################################################
#
#    MARITZ - VIRUTAL MACHINE DEPLOYMENT SCRIPT												
#    NAME: vmdeploy.ps1																	
# 
#    AUTHOR:  MGTS
#    DATE:  1/6/2014
# 
#    COMMENT:  This script will connect to vcenter and will deploy, customize, and turn on a vm 
#
#    VERSION HISTORY
#    1.000 - initial creation
#    1.001 - altered D drive size result to accommodate for page file size/placement 
#    1.002 - added initial centralized logging and .psm1
#    1.003 - added SN data pull, added params for SN kick off, added SN lookup functions.
#
#	 STEPS
#    1. Setup Session to Vcenter
#    2. ServiceNow Input
#    3. Header
#    4. Changing Primary Function to Server Type: $snServerType
#    5. Determining Cluster Selection: $myCluster
#	 6. Determine Folder Location Based on Server Type: $dstFld
#	 7. Determining Resource Pool based on Cluster assignment: $ResPoolName
#	 8. Determining VM Template based on OS selection: $myTemplate 
#	 9. Determining Network based on Cluster: $myNetworkName
#	 10. Gather Variables
#	 11. Determine Which DataStore to Assign based on Cluster assignment: $vmdepds
#	 12. VM Creation Process
#	 13. Put the VM on the TempalteHolder network
#	 14. move VM to appropriate resource Pool
#	 15. CPU and RAM adjustments
#	 16. Adding Partitions
#	 17. Start VM
#	 18. Put the VM on the appropriate network
#	 19. Start VM
#
########################################################################################

#parameters passed in from SN
Param
(
[Parameter(Mandatory=$true)]
[string]$CIsysID,
[Parameter(Mandatory=$false)]
[string]$myVmname,
[Parameter(Mandatory=$false)]
[string]$local
)

#-------------- FUNCTIONS -----------------#
#
#   Get-FolderPath - Allows the selection of vcetner folder more easily
#   DisplayResults - Simple function that prints more detailed variable results
#
#-------------------------------------------#
#importing logging module for centralized logging 
#logs under the autobuild category
#initially the logging will take place immediately after existing write-host remarks, eventually this will need to be cleaned up
if($local -eq "Yes"){
Import-Module .\LogEvent.psm1
}
Else{
Import-Module d:\scripts\vmdeploy\logevent.psm1
}
#Get the current script file fully qualified path, name, and last update datetime so we can use it to pass to the logging mod
$CurrentScriptFilePath = $script:MyInvocation.MyCommand.Path
$CurrentScriptLastModifiedDateTime = (Get-Item $script:MyInvocation.MyCommand.Path).LastWriteTime

#Local File Settings (if we are going to log locally)
$LocalLogFileName = ".\$env:ComputerName-logfile.txt"

#Windows EventViewer Settings (if we are going to log to the windows Event Viewer)
$LogName = "Application"
$LogSource = 'EventSystem'
########################################################################################################

$AppName = "AutoBuild"
$AppID = "54F789D3-29DE-4F86-9BAA-C396BF7967FB"
$ApiKey = "AD4D5552-A125-4C5D-8AD5-91C9457BFE5C"

function writelog {
	param($message)
	LogEvent -LocalLogFileName $LocalLogFileName -LocalLogFile $false -WebService $true -WindowsEventViewer $false -logname $LogName -logsource $logsource -MessageType "Notification" -Message $message -ScriptFilePath $CurrentScriptFilePath -ScriptFileLastModified $CurrentScriptLastModifiedDateTime -UrlType "Internal" -AppName $AppName -AppKey $AppKey -ApiKey $ApiKey
}

Function Get-ServiceNowTableHandle
{
   param($tableName)
   $duser = "s_snblddata"
	if($local -eq "Yes"){
   	$enstr = Get-Content ".\test.cred"
   	$pi = Get-Content ".\pi.key"
	}
	Else
	{
	$enstr = Get-Content "d:\scripts\vmdeploy\test.cred"
    $pi = Get-Content "d:\scripts\vmdeploy\pi.key"
	}
   #$enstr = Get-Content "test.cred"
   #$pi = Get-Content "pi.key"
   $SPass=Convertto-SecureString $enstr -key $pi
   $creds = New-Object System.Management.Automation.PSCredential $duser,$spass
   #if(!$credentials){$credentials = Get-Credential}
   #$URI = "$serviceNowURL$tableName.do?WSDL"
   $URI = "https://maritzdev.service-now.com/cmdb_ci_server.do?WSDL"
   $SNWSProxy = New-WebServiceProxy -uri $URI -Credential $creds
   return $SNWSProxy
}


Function Get-ServiceNowRecordByKey
{

     param($RecordKey,$tableName)

     $Proxy = Get-ServiceNowTableHandle -tableName $tableName
     $type = $Proxy.getType().Namespace
     $datatype = $type + '.getRecords'
     $property = New-Object $datatype
     $property.sys_id = $RecordKey
     $Proxy.getRecords($property)
}


<#
param(
[Parameter(Mandatory=$true)]
	[String]$FileName #testing only
	[String]$myVmname
	[String]$snIPAddress
	[String]$snOSVersion
	[String]$snRAM 
	[String]$snCPU
	[String]$snCdrive
	[String]$snDdrive
	[String]$snEdrive
	[String]$snFdrive
	[String]$snGdrive
	[String]$snHdrive
	[String]$snEnvironment	 
)
#>
Function Get-FolderPath{
<#
.SYNOPSIS
  Returns the folderpath for a folder
.DESCRIPTION
  The function will return the complete folderpath for
  a given folder, optionally with the "hidden" folders
  included. The function also indicats if it is a "blue"
  or "yellow" folder.
.NOTES
  Authors:  Luc Dekens
.PARAMETER Folder
  On or more folders
.PARAMETER ShowHidden
  Switch to specify if "hidden" folders should be included
  in the returned path. The default is $false.
.EXAMPLE
  PS> Get-FolderPath -Folder (Get-Folder -Name "MyFolder")
.EXAMPLE
  PS> Get-Folder | Get-FolderPath -ShowHidden:$true
#>
 
  param(
  [parameter(valuefrompipeline = $true,
  position = 0,
  HelpMessage = "Enter a folder")]
  [VMware.VimAutomation.ViCore.Impl.V1.Inventory.FolderImpl[]]$Folder,
  [switch]$ShowHidden = $false
  )
 
  begin{
    $excludedNames = "Datacenters","vm","host"
  }
 
  process{
    $Folder | %{
      $fld = $_.Extensiondata
      $fldType = "yellow"
      if($fld.ChildType -contains "VirtualMachine"){
        $fldType = "blue"
      }
      $path = $fld.Name
      while($fld.Parent){
        $fld = Get-View $fld.Parent
        if((!$ShowHidden -and $excludedNames -notcontains $fld.Name) -or $ShowHidden){
          $path = $fld.Name + "\" + $path
        }
      }
      $row = "" | Select Name,Path,Type
      $row.Name = $_.Name
      $row.Path = $path
      $row.Type = $fldType
      $row
    }
  }
}
Function DisplayResults {
Write-Host "`nResults:" -Fore White -nonewline;Write-Host "$myVmname" -Fore Yellow
writelog "Results (myVmname var): $myVmname"
Write-Host "ESXI Host:" -Fore White -nonewline;Write-Host "$ESXi" -Fore Yellow
writelog "ESXI Host: $ESXi"
Write-Host "Datastore:" -Fore White -nonewline;Write-Host "$vmdepds.Name" -Fore Yellow
writelog "Datastore: $vmdepds.Name"
Write-Host "Template:" -Fore White -nonewline;Write-Host "$myTemplate" -Fore Yellow
writelog "Template: $myTemplate"
Write-Host "OS Customization Specification:" -Fore White -nonewline;Write-Host "$mySpecification" -Fore Yellow
writelog "OS Customization Specification: $mySpecification"
Write-Host "Resource Pool:" -Fore White -nonewline;Write-Host "$myResourcePool" -Fore Yellow
writelog "Resource Pool: $myResourcePool"
Write-Host "Folder:" -Fore White -nonewline;Write-Host "$dstFld" -Fore Yellow
writelog "Folder: $dstFld"
Write-Host "Cluster:" -Fore White -nonewline;Write-Host "$myCluster" -Fore Yellow
writelog "Cluster: $myCluster"
Write-Host "ResPoolName:" -Fore White -nonewline;Write-Host "$ResPoolName" -Fore Yellow
writelog "ResPoolName: $RespoolName"
Write-Host "Minimum Required Space:" -Fore White -nonewline;Write-Host "$dsminspace" -Fore Yellow;start-Sleep -Seconds 10 
writelog "Minimum Required Space: $dsminspace"
}

Add-PSSnapin VMware.VimAutomation.Core

#----------------------- Setup Session to Vcenter -----------------------# 
$duser = "us\s_ServiceNowRB_US"
if($local -eq "Yes"){
$enstr = Get-Content ".\s_ServiceNowRB_US.cred"
$pi = Get-Content ".\pi.key"
}
Else{
$enstr = Get-Content "d:\scripts\vmdeploy\s_ServiceNowRB_US.cred"
$pi = Get-Content "d:\scripts\vmdeploy\pi.key"
}	
$SPass=Convertto-SecureString $enstr -key $pi
$bstr = [System.Runtime.InteropServices.marshal]::SecureStringToBSTR($spass)
$pass = [System.Runtime.Interopservices.marshal]::PtrToStringAuto($bstr)
$hostname = $vCenter = "FENAPPVCP03.Us.maritz.net"
Connect-VIServer $hostname -user $duser -password $pass -WarningAction 0
write-host "Connecting to vCenter Server $vCenter" -foreground green
writelog "Connecting to vCenter Server $vCenter"
<#
$hostname = "fenappvcp03"
$cred = Get-VICredentialStoreItem -File D:\Scripts\a_stormnc_creds.xml
Connect-VIServer $hostname -user $cred.user -password $cred.password -WarningAction 0
#>

#----------------------- ServiceNow Input -----------------------# 
#going to log the variables anyway even tho we likely just did that"
#adding in pull data from SN.  Req 2 functions get-servicenowrecordbykey and Get-ServiceNowTableHandle
writelog "Looking up SN information for sysID: $CIsysID"
$sysidnfo = Get-ServiceNowRecordByKey -RecordKey $CIsysID -tableName "cmdb_ci_server_list"

writelog "Listing variables from SN"
writelog "Name: $sysidnfo.name"
writelog "Status: $sysidnfo.status"
writelog "IP: $sysidnfo.ip_address"
#writelog "Support Group:" $sysidnfo.support_group
#writelog "company:" $sysidnfo.company
writelog "Domain: $sysidnfo.u_build_domain" # no direct mapping yet
writelog "OS Version: $sysidnfo.os_version"
writelog "CPU: $sysidnfo.u_build_cpu"
writelog "Ram: $sysidnfo.u_build_ram"

writelog "Drive C: $sysidnfo.u_build_c_drive" #$snCdrive = 40	#This should always stay 40
writelog "Drive D: $sysidnfo.u_build_d_drive" #$snDdrive = 18
writelog "Drive E: $sysidnfo.u_build_e_drive" #$snEdrive = 15
writelog "Drive F: $sysidnfo.u_build_f_drive" #$snFdrive = 15
writelog "Drive G: $sysidnfo.u_build_g_drive" #$snGdrive = 5
writelog "Drive H: $sysidnfo.u_build_h_drive" #$snHdrive = 3
writelog "Environment: $sysidnfo.u_Environment" #$snEnvironment = "Staging" 
writelog "Function: $sysidnfo.u_primary_function"

writelog "setting vars"
$CIsysID = $CIsysID
writelog "CIsysID set to: $CIsysID"
$myVmname = $sysidnfo.name
writelog "myVmname set to: $myVmname"
$snIPAddress = $sysidnfo.ip_address
writelog "snIPAddress set to: $snIPAddress"
$snServerType = $sysidnfo.u_build_Role    #"Wap,Web,SQL,FTP,Print,DC,Other"
writelog "snServerType set to: $snServerType"
$snOSVersion = $sysidnfo.os_version         #"Windows 2008R2,Windows 2012,Windows 2012R2,HP-UX,Linux,Solaris"
writelog "snOSVersion set to: $snOSVersion"
$snRAM = $sysidnfo.u_build_ram
writelog "snRam set to: $snRAM"
$snCPU = $sysidnfo.u_build_cpu
writelog "snCPU set to: $snCPU"
$snCdrive = $sysidnfo.u_build_c_drive							#This should always stay 40
writelog "snCdrive set to: $snCdrive"
$snDdrive = ($sysidnfo.u_build_d_drive + $snRAM)				#This equation is in place due to page file size and placement.  page file gets put in the d drive and is 1/2 the size of the ram.  This equation allow for 20GBs over what is needed to facilitate the page file size.
writelog "snDdrive set to: $snDdrive"
$snEdrive = $sysidnfo.u_build_e_drive
writelog "snEdrive set to: $snEdrive"
$snFdrive = $sysidnfo.u_build_f_drive
writelog "snFdrive set to: $snFdrive"
$snGdrive = $sysidnfo.u_build_g_drive
writelog "snGdrive set to: $snGdrive"
$snHdrive = $sysidnfo.u_build_h_drive
writelog "snGdrive set to: $snGdrive"
$snEnvironment = $sysidnfo.u_Environment          #"Development,Staging,Production,User Acceptance Testing,Reporting,Disaster Recovery,Personal,Lab"
writelog "snEnvironment set to: $sysidnfo.u_Environment"
#----------------------- Header -----------------------# 
write-host "`n*----------- Maritz Vmware Automation Script -----------*`n" -foreground green
writelog "Running Maritz VMWare Automation Script"

#----------------------- Changing Primary Function to Server Type: $snServerType -----------------------# 
write-host "`nDetermining Server Type..." -foreground green
writelog "Determining Server Type"
	If (($snServerType -eq "WEB-EXTRANET") -or ($snServerType -eq "WEB_INTRANET") -or ($snServerType -eq "WEB_INTERNET")){
	$snServerType = "Web"
	writelog "snServerType set to: $snServerType"
	}
	ElseIf (($snServerType -eq "DB-MSSQL") -or ($snServerType -eq "DB-MYSQL") -or ($snServerType -eq "DB-ORACLE") -or ($snServerType -eq "SQL")){
	$snServerType = "SQL"
	writelog "snServerType set to: $snServerType"
	}
	ElseIf ($snServerType -eq "FTP/sFTP"){
	$snServerType = "FTP"
	writelog "snServerType set to: $snServerType"
	}
	ElseIf ($snServerType -eq "Print"){
	$snServerType = "Print"
	writelog "snServerType set to: $snServerType"
	}
	ElseIf ($snServerType -eq "Domain Controller"){
	$snServerType = "DC"
	writelog "snServerType set to: $snServerType"
	}
	ElseIf ($snServerType -eq "Citrix"){
	$snServerType = "Citrix"
	writelog "snServerType set to: $snServerType"
	}
	Else {
	$snServerType = "Wap"
	writelog "snServerType set to: $snServerType"
	}
write-host "Server Type is: $snServerType " -foreground Yellow
writelog "Server Type is: $snServerType"
#----------------------- Determining Cluster Selection: $myCluster -----------------------# 
write-host "`nDetermining Cluster Selection..." -foreground green
writelog "Determining Cluster Selection"
$IP = ($snIPAddress -match "156.45.23[2-6].\d{1,3}") -or ($snIPAddress -match "192.168.2[0-1].\d{1,3}")

	If ($IP -eq "True"){
	$myCluster = "200_External_DL385"
	}
	ElseIf ($snServerType -eq "SQL"){
	$myCluster = "300_SQL_Internal_DL585"
	}
	ElseIf ($snServerType -eq "Citrix"){
	$myCluster = "400_Citrix_UCS_Intel"
	}
	Else {
	$myCluster = "100_Internal_DL585"
	}
write-host "Cluster Selection is: $myCluster " -foreground Yellow
writelog "myCluster set to $myCluster"

#----------------------- Determine Folder Location Based on Server Type: $dstFld -----------------------# 
write-host "`nFolder Location Based on Server Type..." -foreground green
writelog "Folder Location based on Server Type"
	If ($snServerType -eq "Wap"){
    $dstFld = "Wap"
	}
	ElseIf ($snServerType -eq "SQL"){
		If ($snEnvironment -eq "Staging"){
		$destination = "Fenton\SQL Servers\Staging-SQL"
	    $dstFld = Get-Folder -Name Staging-SQL | where {(Get-FolderPath -Folder $_).Path -eq $destination}
		}
		ElseIf ($snEnvironment -eq "Production"){
		$destination = "Fenton\SQL Servers\Production-SQL"
	    $dstFld = Get-Folder -Name Production-SQL | where {(Get-FolderPath -Folder $_).Path -eq $destination}
		}
		Else {
		$destination = "Fenton\SQL Servers\Development-SQL"
	    $dstFld = Get-Folder -Name Development-SQL | where {(Get-FolderPath -Folder $_).Path -eq $destination}
		}
	}
	ElseIf ($snServerType -eq "Web"){
	$dstFld = "Web"
	}
	ElseIf ($snServerType -eq "Citrix"){
	$dstFld = "Build"
	}
	ElseIf ($snServerType -eq "FTP"){
	$dstFld = "FTP-2012"
	}
	ElseIf ($snServerType -eq "Print"){
	$dstFld = "Print Servers"
	}
	ElseIf ($snServerType -eq "DC"){
	$dstFld = "Domain Controllers"
	}
	Else{
	$dstFld = "Infrastructure Servers"
	}
write-host "Destination Folder is: $dstFld " -foreground Yellow
writelog "Destination Folder set to: $dstFld"

#----------------------- Determining Resource Pool based on Cluster assignment: $ResPoolName -----------------------# 
#commented out for testing only
#write-host "`nDetermining Resource Pool based on Cluster assignment..." -foreground green
#writelog "Determining Resource Pool based on Cluster assignment"
#If ($snEnvironment -eq "Development"){
#  If ($myCluster -eq "100_Internal_DL585"){
#  $ResPoolName = "Development"
#  }
#  ElseIf ($myCluster -eq "200_External_DL385"){
#  $ResPoolName = "Staging"
#  }
#}
#ElseIf ($snEnvironment -eq "Build"){
#$ResPoolName = "Build"
#}
#ElseIf ($snEnvironment -eq "Production"){
#$ResPoolName = "Production"
#}
#Else {
#$ResPoolName = "Build"
#}
$ResPoolName = "Resources"
write-host "Resource Pool Selection is: $ResPoolName " -foreground Yellow
writelog "Resource Pool Seelction is: $ResPoolName"

#----------------------- Determining VM Template based on OS selection: $myTemplate -----------------------# 
write-host "`nDetermining VM Template based on OS selection..." -foreground green
writelog "Determining VM Template based on OS selection"
If ($snOSVersion -eq "Windows 2008R2"){
$myTemplate = Get-Template -Name "FENTMP2008R2"
}
Else{
$myTemplate = Get-Template -Name "FENTMP2012R2"
}
write-host "VM Template Selection is: $myTemplate" -foreground Yellow
writelog "VM Template Selection is: $myTemplate"
#----------------------- Determining Network based on Cluster: $myNetworkName -----------------------# 
If ($myCluster -eq "300_SQL_Internal_DL585"){
$myNetworkName = "dvpgRISLAN_10.90.5.0"
}
Else {
$myNetworkName = "dvInternalRISLan_10.90.5.0"
}

writelog "myNetworkName set to: $myNetworkName"

#----------------------- Gather Variables -----------------------# 
$mySpecification = Get-OSCustomizationSpec -Name "Windows 08/12 - RunBook"
write-host "`nDetermining minimum space needed:" -foreground green
writelog "Determining minimum space needed"
$vmsize=([int]$snCdrive+[int]$snDdrive+[int]$snEdrive+[int]$snFdrive+[int]$snGdrive+[int]$snHdrive)
$dsminspace=($vmsize+50) 
write-host "Minimum space needed is: $dsminspace GB" -foreground Yellow
writelog "Minimum space needed is: $dsminspace GB"

#----------------------- Determine Which DataStore to Assign based on Cluster assignment: $vmdepds -----------------------# 
write-host "`nDetermining Datastore..." -foreground green
writelog "Determining Datastore"
If ($myCluster -eq "200_External_DL385") {
$vmdepds = Get-Datacenter Fenton | Get-Folder -type Datastore -Name 200_External | Get-Datastore | Where-Object { ($_.Name -match "PAR0[1-4]_[edp]*disk*") -and ($_.Name -notmatch "local")} |
Select-Object Name,
    @{n="CapacityGB";e={[math]::round(($_.CapacityMB/1024))}},
    @{n="FreeSpaceGB";e={[math]::round(($_.FreeSpaceMB/1024))}},
    @{n="FreeSpacePercent";e={[math]::round(($_.FreeSpaceMB/$_.CapacityMB*100))}} |
where {($_.FreeSpaceGB - $vm.UsedSpaceGB - $dsminspace) -gt 0} | Sort-Object -Property FreeSpaceGB | Select name -First 1
	write-host "result of If statement is:" $vmdepds
}
ElseIf ($myCluster -eq "300_SQL_Internal_DL585") {
$vmdepds = Get-Datacenter Fenton | Get-Folder -type Datastore -Name 300_SQL | Get-Datastore | Where-Object { ($_.Name -match "PAR0[1-4]_[edp]*disk*") -and ($_.Name -notmatch "local")} |
Select-Object Name,
    @{n="CapacityGB";e={[math]::round(($_.CapacityMB/1024))}},
    @{n="FreeSpaceGB";e={[math]::round(($_.FreeSpaceMB/1024))}},
    @{n="FreeSpacePercent";e={[math]::round(($_.FreeSpaceMB/$_.CapacityMB*100))}} |
where {($_.FreeSpaceGB - $vm.UsedSpaceGB - $dsminspace) -gt 0} | Sort-Object -Property FreeSpaceGB | Select name -First 1
	write-host "result of If statement is:" $vmdepds
}
elseif ($myCluster -eq "400_Citrix_UCS_Intel") {
$vmdepds = Get-Datacenter Fenton | Get-Folder -type Datastore -Name 400_Citrix | Get-Datastore | Where-Object { ($_.Name -match "NA01[1-9]*") -and ($_.Name -notmatch "local")} |
Select-Object Name,
    @{n="CapacityGB";e={[math]::round(($_.CapacityMB/1024))}},
    @{n="FreeSpaceGB";e={[math]::round(($_.FreeSpaceMB/1024))}},
    @{n="FreeSpacePercent";e={[math]::round(($_.FreeSpaceMB/$_.CapacityMB*100))}} |
where {($_.FreeSpaceGB - $vm.UsedSpaceGB - $dsminspace) -gt 0} | Sort-Object -Property FreeSpaceGB | Select name -First 1
	write-host "result of If statement is:" $vmdepds
}
Else {
$vmdepds = Get-Datacenter Fenton | Get-Folder -type Datastore -Name "100_Internal" | Get-Datastore | Where-Object { ($_.Name -match "PAR0[1-4]_[edp]*disk*") -and ($_.Name -notmatch "local")} |
Select-Object Name,
    @{n="CapacityGB";e={[math]::round(($_.CapacityMB/1024))}},
    @{n="FreeSpaceGB";e={[math]::round(($_.FreeSpaceMB/1024))}},
    @{n="FreeSpacePercent";e={[math]::round(($_.FreeSpaceMB/$_.CapacityMB*100))}} |
where {($_.FreeSpaceGB - $vm.UsedSpaceGB - $dsminspace) -gt 0} | Sort-Object -Property FreeSpaceGB | Select name -First 1
	write-host "result of If statement is:" $vmdepds
}
write-host "Datastore Assigned is:" $vmdepds.name -foreground Yellow
writelog "Datastore Assigned is: $vmdepds"




#----------------------- VM Creation Process -----------------------# 
$myResourcePool = Get-ResourcePool -Location $myCluster -Name $ResPoolName
write-host "`nDetermining ESXI host:" -foreground green
writelog "Determining ESXI host"
$ESXi=Get-Cluster $myCluster | Get-VMHost -state connected | Get-Random
write-host "ESXI host assigned is: $ESXi" -foreground Yellow
writelog "ESXI host assigned is: $ESXi"
#DisplayResults
write-host "`nCreating VM named $myVmname" -foreground green
writelog "Creating VM named $myVmname"
New-VM -Name $myVmname.ToUpper() -VMHost $ESXi -Datastore $vmdepds.Name -Location $dstFld -DiskStorageFormat Thick -Template $myTemplate[0] -OSCustomizationSpec $mySpecification[0]
write-host "`nVM creation is complete" -foreground Yellow
writelog "VM Creation is complete"

#----------------------- Put the VM on the TempalteHolder network -----------------------# 
write-host "`nPutting the VM on the TemplateHolder network..." -foreground green
writelog "Putting the VM on the TemplateHolder network"
Get-VM $myVmname.ToUpper() | Get-NetworkAdapter | Set-NetworkAdapter -NetworkName TemplateHolder -Type e1000 -Confirm:$false -StartConnected:$true 
write-host "...Complete`n" -foreground Yellow
writelog "Network move completed"

#----------------------- move VM to appropriate resource Pool-----------------------# 
write-host "Moving VM to appropriate Resource Pool...`n" -foreground green
writelog "Moving VM to appropriate Resource Pool"
Get-VM $myVmname.ToUpper() | Move-VM -Destination $myResourcePool
write-host "`n...Complete" -foreground Yellow
writelog "Completed Resource Pool move"
#----------------------- CPU and RAM adjustments -----------------------# 
write-host "Making CPU and RAM adjustments...`n" -foreground green
writelog "Making CPU and Ram adjustments"
Get-VM $myVmname.ToUpper() | Set-VM -MemoryGB $snRAM -NumCPU $snCPU -Confirm:$false
write-host "`n...Complete" -foreground Yellow
writelog "Completed CPU and Ram adjustments"

#----------------------- Adding Partitions -----------------------# 
If ($snServerType -eq "SQL"){
write-host "`nAdding $snDdrive GB D drive..." -foreground green
writelog "Adding $snDdrive GB D drive"
New-HardDisk -VM $myVmname.ToUpper() -CapacityGB $snDdrive -DataStore $vmdepds.Name
write-host "...Complete" -foreground Yellow
writelog "Completed adding D drive"
write-host "`nAdding $snEdrive GB E drive..." -foreground green
writelog "Adding $snEdrive GB E Drive"
New-HardDisk -VM $myVmname.ToUpper() -CapacityGB $snEdrive -DataStore $vmdepds.Name
write-host "...Complete" -foreground Yellow
writelog "Completed adding E drive"
write-host "`nAdding $snFdrive GB F drive..." -foreground green 
writelog "Adding $snFdrive GB F drive"
New-HardDisk -VM $myVmname.ToUpper() -CapacityGB $snFdrive -DataStore $vmdepds.Name
write-host "...Complete" -foreground Yellow
writelog "completed adding F Drive"
write-host "`nAdding $snGdrive GB G drive..." -foreground green
writelog "Adding $snGdrive GB G drive"
New-HardDisk -VM $myVmname.ToUpper() -CapacityGB $snGdrive -DataStore $vmdepds.Name
write-host "...Complete" -foreground Yellow
writelog "Completed adding G drive"
write-host "`nAdding $snHdrive GB H drive..." -foreground green 
writelog "Adding $snHDrive GB H drive"
New-HardDisk -VM $myVmname.ToUpper() -CapacityGB $snHdrive -DataStore $vmdepds.Name
write-host "...Complete" -foreground Yellow
writelog "Completed Adding H drive"
}
Else {
write-host "`nAdding $snDdrive GB D drive...`n" -foreground green
writelog "Adding $snDdrive GB D drive"
New-HardDisk -VM $myVmname.ToUpper() -CapacityGB $snDdrive -DataStore $vmdepds.Name
write-host "`n...Complete" -foreground Yellow
writelog "Completed D drive"
}

#----------------------- Start VM -----------------------# 
write-host "`nStarting VM...`n" -foreground green
writelog "Starting VM"
Get-VM -Name $myVmname.ToUpper() | Start-VM
write-host "`n...Complete" -foreground Yellow
writelog "Completed Starting VM"
#----------------------- Put the VM on the appropriate network -----------------------# 
start-Sleep -Seconds 600 #( aka 10 minutes)
Get-VM -Name $myVmname.ToUpper() | Shutdown-VMGuest -Confirm:$false
start-Sleep -Seconds 30 
Get-VM $myVmname.ToUpper() | Get-NetworkAdapter | Set-NetworkAdapter -NetworkName $myNetworkName -Confirm:$false -StartConnected:$true 

#----------------------- Start VM -----------------------# 
write-host "`nStarting VM...`n" -foreground green
writelog "Starting VM"
Get-VM -Name $myVmname.ToUpper() | Start-VM
write-host "`n...Complete" -foreground Yellow
writelog "Completed Starting VM"