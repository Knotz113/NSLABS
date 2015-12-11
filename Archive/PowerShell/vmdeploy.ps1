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

#-------------- FUNCTIONS -----------------#
#
#   Get-FolderPath - Allows the selection of vcetner folder more easily
#   DisplayResults - Simple function that prints more detailed variable results
#
#-------------------------------------------#

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
Write-Host "ESXI Host:" -Fore White -nonewline;Write-Host "$ESXi" -Fore Yellow
Write-Host "Datastore:" -Fore White -nonewline;Write-Host "$vmdepds.Name" -Fore Yellow
Write-Host "Template:" -Fore White -nonewline;Write-Host "$myTemplate" -Fore Yellow
Write-Host "OS Customization Specification:" -Fore White -nonewline;Write-Host "$mySpecification" -Fore Yellow
Write-Host "Resource Pool:" -Fore White -nonewline;Write-Host "$myResourcePool" -Fore Yellow
Write-Host "Folder:" -Fore White -nonewline;Write-Host "$dstFld" -Fore Yellow
Write-Host "Cluster:" -Fore White -nonewline;Write-Host "$myCluster" -Fore Yellow
Write-Host "ResPoolName:" -Fore White -nonewline;Write-Host "$ResPoolName" -Fore Yellow
Write-Host "Minimum Required Space:" -Fore White -nonewline;Write-Host "$dsminspace" -Fore Yellow;start-Sleep -Seconds 10 
}

#Add-PSSnapin VMware.VimAutomation.Core

#----------------------- Setup Session to Vcenter -----------------------# 
write-host "Connecting to vCenter Server $vCenter" -foreground green
<#
$hostname = "fenappvcp03"
$cred = Get-VICredentialStoreItem -File D:\Scripts\a_stormnc_creds.xml
Connect-VIServer $hostname -user $cred.user -password $cred.password -WarningAction 0
#>

#----------------------- ServiceNow Input -----------------------# 
$myVmname = "pltest102-new"
$snIPAddress = "156.45.55.60"
$snServerType = "Wap"          		    #"Wap,Web,SQL,FTP,Print,DC,Other"
$snOSVersion = "Windows 2008R2"         #"Windows 2008R2,Windows 2012,Windows 2012R2,HP-UX,Linux,Solaris"
$snRAM = 8
$snCPU = 4
$snCdrive = 40 							#This should always stay 40
$snDdrive = (20 + $snRAM)				#This equation is in place due to page file size and placement.  page file gets put in the d drive and is 1/2 the size of the ram.  This equation allow for 20GBs over what is needed to facilitate the page file size.
$snEdrive = 0
$snFdrive = 0
$snGdrive = 0
$snHdrive = 0
$snEnvironment = "Staging"          #"Development,Staging,Production,User Acceptance Testing,Reporting,Disaster Recovery,Personal,Lab"

#----------------------- Header -----------------------# 
write-host "`n*----------- Maritz Vmware Automation Script -----------*`n" -foreground green

#----------------------- Changing Primary Function to Server Type: $snServerType -----------------------# 
write-host "`nDetermining Server Type..." -foreground green
	If (($snServerType -eq "WEB-EXTRANET") -or ($snServerType -eq "WEB_INTRANET") -or ($snServerType -eq "WEB_INTERNET")){
	$snServerType = "Web"
	}
	ElseIf (($snServerType -eq "DB-MSSQL") -or ($snServerType -eq "DB-MYSQL") -or ($snServerType -eq "DB-ORACLE") -or ($snServerType -eq "SQL")){
	$snServerType = "SQL"
	}
	ElseIf ($snServerType -eq "FTP/sFTP"){
	$snServerType = "FTP"
	}
	ElseIf ($snServerType -eq "Print"){
	$snServerType = "Print"
	}
	ElseIf ($snServerType -eq "Domain Controller"){
	$snServerType = "DC"
	}
	Else {
	$snServerType = "Wap"
	}
write-host "Server Type is: $snServerType " -foreground Yellow

#----------------------- Determining Cluster Selection: $myCluster -----------------------# 
write-host "`nDetermining Cluster Selection..." -foreground green
$IP = ($snIPAddress -match "156.45.23[2-6].\d{1,3}") -or ($snIPAddress -match "192.168.2[0-1].\d{1,3}")

	If ($IP -eq "True"){
	$myCluster = "200_External_DL385"
	}
	ElseIf ($snServerType -eq "SQL"){
	$myCluster = "300_SQL_Internal_DL585"
	}
	Else {
	$myCluster = "100_Internal_DL585"
	}
write-host "Cluster Selection is: $myCluster " -foreground Yellow

#----------------------- Determine Folder Location Based on Server Type: $dstFld -----------------------# 
write-host "`nFolder Location Based on Server Type..." -foreground green
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

#----------------------- Determining Resource Pool based on Cluster assignment: $ResPoolName -----------------------# 
write-host "`nDetermining Resource Pool based on Cluster assignment..." -foreground green
If ($snEnvironment -eq "Development"){
  If ($myCluster -eq "100_Internal_DL585"){
  $ResPoolName = "Development"
  }
  ElseIf ($myCluster -eq "200_External_DL385"){
  $ResPoolName = "Staging"
  }
}
ElseIf ($snEnvironment -eq "Build"){
$ResPoolName = "Build"
}
ElseIf ($snEnvironment -eq "Production"){
$ResPoolName = "Production"
}
Else {
$ResPoolName = "Build"
}
write-host "Resource Pool Selection is: $ResPoolName " -foreground Yellow

#----------------------- Determining VM Template based on OS selection: $myTemplate -----------------------# 
write-host "`nDetermining VM Template based on OS selection..." -foreground green
If ($snOSVersion -eq "Windows 2008R2"){
$myTemplate = Get-Template -Name "FENTMP2008R2"
}
Else{
$myTemplate = Get-Template -Name "FENTMP2012R2"
}
write-host "VM Template Selection is: $myTemplate" -foreground Yellow

#----------------------- Determining Network based on Cluster: $myNetworkName -----------------------# 
If ($myCluster -eq "300_SQL_Internal_DL585"){
$myNetworkName = "dvpgRISLAN_10.90.5.0"
}
Else {
$myNetworkName = "dvInternalRISLan_10.90.5.0"
}

#----------------------- Gather Variables -----------------------# 
$mySpecification = Get-OSCustomizationSpec -Name "Windows 08/12 - RunBook"
write-host "`nDetermining minimum space needed:" -foreground green
$vmsize=($snCdrive+$snDdrive+$snEdrive+$snFdrive+$snGdrive+$snHdrive)
$dsminspace=($vmsize+50) 
write-host "Minimum space needed is: $dsminspace GB" -foreground Yellow

#----------------------- Determine Which DataStore to Assign based on Cluster assignment: $vmdepds -----------------------# 
write-host "`nDetermining Datastore..." -foreground green
If ($myCluster -eq "200_External_DL385") {
$vmdepds = Get-Datacenter Fenton | Get-Folder -type Datastore -Name 200_External | Get-Datastore | Where-Object { ($_.Name -match "PAR0[1-4]_[edp]*disk*") -and ($_.Name -notmatch "local")} |
Select-Object Name,
    @{n="CapacityGB";e={[math]::round(($_.CapacityMB/1024))}},
    @{n="FreeSpaceGB";e={[math]::round(($_.FreeSpaceMB/1024))}},
    @{n="FreeSpacePercent";e={[math]::round(($_.FreeSpaceMB/$_.CapacityMB*100))}} |
where {($_.FreeSpaceGB - $vm.UsedSpaceGB - $dsminspace) -gt 0} | Sort-Object -Property FreeSpaceGB | Select name -First 1
}
ElseIf ($myCluster -eq "300_SQL_Internal_DL585") {
$vmdepds = Get-Datacenter Fenton | Get-Folder -type Datastore -Name 300_SQL | Get-Datastore | Where-Object { ($_.Name -match "PAR0[1-4]_[edp]*disk*") -and ($_.Name -notmatch "local")} |
Select-Object Name,
    @{n="CapacityGB";e={[math]::round(($_.CapacityMB/1024))}},
    @{n="FreeSpaceGB";e={[math]::round(($_.FreeSpaceMB/1024))}},
    @{n="FreeSpacePercent";e={[math]::round(($_.FreeSpaceMB/$_.CapacityMB*100))}} |
where {($_.FreeSpaceGB - $vm.UsedSpaceGB - $dsminspace) -gt 0} | Sort-Object -Property FreeSpaceGB | Select name -First 1
}
Else {
$vmdepds = Get-Datacenter Fenton | Get-Folder -type Datastore -Name "100_Internal" | Get-Datastore | Where-Object { ($_.Name -match "PAR0[1-4]_[edp]*disk*") -and ($_.Name -notmatch "local")} |
Select-Object Name,
    @{n="CapacityGB";e={[math]::round(($_.CapacityMB/1024))}},
    @{n="FreeSpaceGB";e={[math]::round(($_.FreeSpaceMB/1024))}},
    @{n="FreeSpacePercent";e={[math]::round(($_.FreeSpaceMB/$_.CapacityMB*100))}} |
where {($_.FreeSpaceGB - $vm.UsedSpaceGB - $dsminspace) -gt 0} | Sort-Object -Property FreeSpaceGB | Select name -First 1
}
write-host "Datastore Assigned is: $vmdepds" -foreground Yellow

#----------------------- VM Creation Process -----------------------# 
$myResourcePool = Get-ResourcePool -Location $myCluster -Name $ResPoolName
write-host "`nDetermining ESXI host:" -foreground green
$ESXi=Get-Cluster $myCluster | Get-VMHost -state connected | Get-Random
write-host "ESXI host assigned is: $ESXi" -foreground Yellow
#DisplayResults
write-host "`nCreating VM named $myVmname" -foreground green
New-VM -Name $myVmname.ToUpper() -VMHost $ESXi -Datastore $vmdepds.Name -Location "R&D Servers" -DiskStorageFormat Thick -Template $myTemplate -OSCustomizationSpec $mySpecification
write-host "`nVM creation is complete" -foreground Yellow

#----------------------- Put the VM on the TempalteHolder network -----------------------# 
write-host "`nPutting the VM on the TemplateHolder network..." -foreground green
Get-VM $myVmname.ToUpper() | Get-NetworkAdapter | Set-NetworkAdapter -NetworkName TemplateHolder -Type e1000 -Confirm:$false -StartConnected:$true 
write-host "...Complete`n" -foreground Yellow

#----------------------- move VM to appropriate resource Pool-----------------------# 
write-host "Moving VM to appropriate Resource Pool...`n" -foreground green
Get-VM $myVmname.ToUpper() | Move-VM -Destination $myResourcePool
write-host "`n...Complete" -foreground Yellow

#----------------------- CPU and RAM adjustments -----------------------# 
write-host "Making CPU and RAM adjustments...`n" -foreground green
Get-VM $myVmname.ToUpper() | Set-VM -MemoryGB $snRAM -NumCPU $snCPU -Confirm:$false
write-host "`n...Complete" -foreground Yellow

#----------------------- Adding Partitions -----------------------# 
If ($snServerType -eq "SQL"){
write-host "`nAdding $snDdrive GB D drive..." -foreground green 
New-HardDisk -VM $myVmname.ToUpper() -CapacityGB $snDdrive -DataStore $vmdepds.Name
write-host "...Complete" -foreground Yellow
write-host "`nAdding $snEdrive GB E drive..." -foreground green 
New-HardDisk -VM $myVmname.ToUpper() -CapacityGB $snEdrive -DataStore $vmdepds.Name
write-host "...Complete" -foreground Yellow
write-host "`nAdding $snFdrive GB F drive..." -foreground green 
New-HardDisk -VM $myVmname.ToUpper() -CapacityGB $snFdrive -DataStore $vmdepds.Name
write-host "...Complete" -foreground Yellow
write-host "`nAdding $snGdrive GB G drive..." -foreground green 
New-HardDisk -VM $myVmname.ToUpper() -CapacityGB $snGdrive -DataStore $vmdepds.Name
write-host "...Complete" -foreground Yellow
write-host "`nAdding $snHdrive GB H drive..." -foreground green 
New-HardDisk -VM $myVmname.ToUpper() -CapacityGB $snHdrive -DataStore $vmdepds.Name
write-host "...Complete" -foreground Yellow
}
Else {
write-host "`nAdding $snDdrive GB D drive...`n" -foreground green
New-HardDisk -VM $myVmname.ToUpper() -CapacityGB $snDdrive -DataStore $vmdepds.Name
write-host "`n...Complete" -foreground Yellow
}

#----------------------- Start VM -----------------------# 
write-host "`nStarting VM...`n" -foreground green
Get-VM -Name $myVmname.ToUpper() | Start-VM
write-host "`n...Complete" -foreground Yellow

#----------------------- Put the VM on the appropriate network -----------------------# 
start-Sleep -Seconds 600 #( aka 10 minutes)
Get-VM -Name $myVmname.ToUpper() | Shutdown-VMGuest -Confirm:$false
start-Sleep -Seconds 30 
Get-VM $myVmname.ToUpper() | Get-NetworkAdapter | Set-NetworkAdapter -NetworkName $myNetworkName -Confirm:$false -StartConnected:$true 

#----------------------- Start VM -----------------------# 
write-host "`nStarting VM...`n" -foreground green
Get-VM -Name $myVmname.ToUpper() | Start-VM
write-host "`n...Complete" -foreground Yellow
