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
# 1.000 - initial versioning, not initial version of script
# 1.001 - added centralized logging
# 1.002 - added SN data pull
# 1.003 - added Write status to SN
########################################################################################
Param
(
[Parameter(Mandatory=$true)]
[string]$CIsysID
)

Function writelog {
	param($message)
    $message = "[$myVmname] - $message" 
	#LogEvent -LocalLogFileName $LocalLogFileName -LocalLogFile $false -WebService $true -WindowsEventViewer $false -logname $LogName -logsource $logsource -MessageType "Notification" -Message $message -ScriptFilePath $CurrentScriptFilePath -ScriptFileLastModified $CurrentScriptLastModifiedDateTime -UrlType "Internal" -AppName $AppName -AppKey $AppKey -ApiKey $ApiKey
}
Function Get-ServiceNowTableHandle {
	param($tableName)
	$duser = "s_snblddata"
	if($local -eq "Yes")
	{
		$enstr = Get-Content ".\test.cred"
		$pi = Get-Content ".\pi.key"
	}
	Else
	{
		$enstr = Get-Content "d:\scripts\vmdeploy\test.cred"
		$pi = Get-Content "d:\scripts\vmdeploy\pi.key"
	}
	$SPass=Convertto-SecureString $enstr -key $pi
	$creds = New-Object System.Management.Automation.PSCredential $duser,$spass
	$URI = "https://maritz.service-now.com/cmdb_ci_win_server.do?WSDL"
	$SNWSProxy = New-WebServiceProxy -uri $URI -Credential $creds
	return $SNWSProxy
}
Function Get-ServiceNowRecordByKey {
    param($RecordKey,$tableName)
    $Proxy = Get-ServiceNowTableHandle -tableName $tableName
    $type = $Proxy.getType().Namespace
    $datatype = $type + '.getRecords'
    $property = New-Object $datatype
    $property.sys_id = $RecordKey
    $Proxy.getRecords($property)
}
Function Update-SN_DomainNameRecord {
    param($SysID,$SNproperty,$newvalue, $maintenanceLogMessage)
    $currentDomain = Get-ServiceNowRecordByKey  $CISysID $strTablename
    $duser = "s_ServiceNowRB_US"
	$enstr = Get-Content "d:\scripts\vmdeploy\s_ServiceNowRB_US.cred"
	$pi = Get-Content "d:\scripts\vmdeploy\pi.key"
	$SPass=Convertto-SecureString $enstr -key $pi
    $creds = New-Object System.Management.Automation.PSCredential $duser,$spass
	$URI = "https://maritz.service-now.com/cmdb_ci_win_server.do?WSDL"
    $DNWSProxy = New-WebServiceProxy -uri $URI -Credential $creds
    $type = $DNWSProxy.getType().Namespace
    $datatype = $type + '.update'
    $properties = New-Object $datatype
    $properties.sys_id =  $SysID
    $properties.u_build_status = $currentDomain.u_build_status
    if($SNproperty -eq "u_build_status")
    {
        $properties.u_build_status = $newvalue
        $text = "Updating SN domain record [$($currentDomain.name)] with WHOIS Expiration Date [ $($newvalue) ]. Old value: [$($currentDomain.u_expiration_date)]"
        $properties.u_maint_notes =  $properties.u_maint_notes += "`n$(Get-Date) - Automation -  $text]"
        Write-Verbose "$($currentDomain.name) - $text"
        $text=$null
    }
	try 
	{
		$serviceNowReturnCode = $DNWSProxy.update($properties)
		write-output "[Success]Update of [$($currentDomain.name)] service now record with sys_id of $($serviceNowReturnCode.sys_id) complete.[/Success]" ##-foreground green
	}
	catch
	{
		write-output "[Error]CI was not found[/Error]" #-fore red
		Exit
	}
}
Function Wait-ForVMtoComeOnlineThenMonitorCustomization {
    param($VMName,$timeOutSeconds=900)
    $startTime = Get-Date 
    $isVMActive = $false
    $customizationComplete = $false
    Write-host "TimeOut Seconds set to $timeOutSeconds"
    while(!$isVMActive)
    {
        #check every 30 seconds for handle to VM
        try
        {
            $VM = Get-VM -Name $VMName.ToUpper() -erroraction stop
            if( $VM.PowerState -eq "PoweredOn" )
	        {
                Write-host "VM is found and shows as Powered on"
		        $isVMActive = $true
	        }
        }
        catch
        {
            Write-host "VM is not found in host yet. waiting 30 seconds for VM with name $VMName to show up in vCenter"
            Start-Sleep -Seconds 30
        }
    }
    Write-host "VM with name of [$VMName] is now online"
    Write-host "Checking logs for customization status"
    $customizationStartedEvent = Get-VIEvent $vm | ?{ $_.FullFormattedMessage -like "Started Customization*"}
    While(!$customizationStartedEvent -and  $( (Get-Date).Subtract($startTime).Seconds -lt $timeOutSeconds ) )
    {
       Write-host "Waiting 15 seconds for customization to start on $VMName $timeOutSeconds Seconds left until timeout"
       Start-Sleep -Seconds 15
	   $timeOutSeconds = $timeOutSeconds - 15
       $customizationStartedEvent = Get-VIEvent $vm | ?{ $_.FullFormattedMessage -like "Started Customization*"}
    }
    if( $customizationStartedEvent)
    {
        
        $message = "Customization Start found in Logs, Customization began at $( $customizationStartedEvent.CreatedTime)"
        Write-host $message
        writelog $message
    }
    $customizationCompletedEvent = Get-VIEvent $vm | ?{ $_.FullFormattedMessage -like "Customization of*"}
    if($customizationCompletedEvent){$customizationComplete = $true}
    While(!$customizationCompletedEvent -and  $( (Get-Date).Subtract($startTime).Seconds -lt $timeOutSeconds ) )
    {
       Write-host "Waiting 15 seconds for customization to complete on $VMName $timeOutSeconds Seconds left until timeout"
       Start-Sleep -Seconds 15
	   $timeOutSeconds = $timeOutSeconds - 15
       $customizationCompletedEvent = Get-VIEvent $vm | ?{ $_.FullFormattedMessage -like "Customization of*"}
       if($customizationCompletedEvent){$customizationComplete = $true}
    }
    if($customizationComplete -eq $true)
    {
        $message =  "vCenter Customization Completion found in Logs, Customization completed at $( $customizationStartedEvent.CreatedTime)"
        Write-host $message
        writelog $message
    }
    else
    {
        $message =  "vCenter Customization appears to have failed or never started. Please research."
        Write-host $message
        writelog $message
    }
    #script returns false if it went past timeout and never found customization to be complete, true if customization was found to be completed
    return $customizationComplete
}
Function Get-FolderPath {
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
      if($fld.ChildType -contains "VirtualMachine")
	  {
        $fldType = "blue"
      }
      $path = $fld.Name
      while($fld.Parent){
        $fld = Get-View $fld.Parent
        if((!$ShowHidden -and $excludedNames -notcontains $fld.Name) -or $ShowHidden)
		{
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
Function SendEmailAction {
param($message)
Send-MailMessage -From "automation@maritz.com" -To "$emailaddress" -Subject "Failure from OS Automation" -Body "$message"
}
Function HostLogEmailExit {
param($message)
write-output "[Error]$message[/Error]" ##-foreground red

Stop-Transcript
$transpathrev = "c:\transcripts\VmDeployLog" + "$myVmname" + ".txt"
If (test-path $transpathrev){remove-item $transpathrev -force}
rename-item $transpath $transpathrev
$a = Get-Content $transpathrev
$a > $transpathrev
Send-MailMessage -From "automation@maritz.com" -To "$emailaddress" -Subject "Server Build Error - $message" -Body "Script Exited with error message of: $message" #-Attachments "$transpathrev"

Exit
}
Function HostLogContinue {
param($message)
write-output "[Success]$message[/Success]" ###-foreground green
writelog "$message"
}
Function WaitTillProvisioningCompleteSNField {
sl D:\Scripts\vmdeploy
$time = 120
DO
{
	write-output "$time minutes until timeout"
	.\check_sn_field.ps1 $myVmname
	start-sleep 60
	$time--
} 
Until (($snfield -eq "Provisioning Complete") -or ($time -eq "0"))
if ($time -eq "0"){
	$message = "OS Provisioning Failed - All 6 steps did not complete - 120 minute timeout reached"
	HostLogEmailExit $message
}
Else {}
}

$transpath = "c:\transcripts\VmDeployLog.txt"
If (test-path $transpath){remove-item $transpath -force}
Else {}
start-transcript -path $transpath

Add-PSSnapin VMware.VimAutomation.Core
Add-PSSnapin VMware.vimautomation.vds
$strScriptVersion = "1.002"

#importing logging module for centralized logging - logs under the autobuild category - initially the logging will take place immediately after existing write-output remarks, eventually this will need to be cleaned up
Import-Module d:\scripts\vmdeploy\logevent.psm1

#default smtp server to be used
$PSEmailServer = "mifenmail99.maritz.com"

#Get the current script file fully qualified path, name, and last update datetime so we can use it to pass to the logging mod
$CurrentScriptFilePath = $script:MyInvocation.MyCommand.Path
$CurrentScriptLastModifiedDateTime = (Get-Item $script:MyInvocation.MyCommand.Path).LastWriteTime

#Local File Settings (if we are going to log locally)
$LocalLogFileName = ".\$env:ComputerName-logfile.txt"

#Windows EventViewer Settings (if we are going to log to the windows Event Viewer)
$LogName = "Application"
$LogSource = 'EventSystem'
$AppName = "AutoBuild"
$AppID = "54F789D3-29DE-4F86-9BAA-C396BF7967FB"
$ApiKey = "AD4D5552-A125-4C5D-8AD5-91C9457BFE5C"

#----------------------- Header -----------------------# 
write-output "`n*----------- Maritz Vmware Automation Script -----------*`n" ##-foreground green
writelog "Running Maritz VMWare Automation Script"

Update-SN_DomainNameRecord -SysID $CISysID -SNproperty u_build_status -newvalue "VmDeploy Started" -maintenanceLogMessage "Updated via automation, centralized logging will have script output"

#----------------------- ServiceNow Input -----------------------# 
#going to log the variables anyway even tho we likely just did that - adding in pull data from SN.  Req 2 functions get-servicenowrecordbykey and Get-ServiceNowTableHandle
writelog "Looking up SN information for sysID: $CIsysID"
$sysidnfo = Get-ServiceNowRecordByKey -RecordKey $CIsysID -tableName "cmdb_ci_server_list"
$createdby = $sysidnfo.sys_created_by
$emailaddress = Get-ADUser $createdby -Properties mail | Select-Object -ExpandProperty mail
$myVmname = $sysidnfo.name
writelog "myVmname set to: $myVmname"
$snIPAddress = $sysidnfo.ip_address
writelog "snIPAddress set to: $snIPAddress"
$snServerType = $sysidnfo.u_build_Role    
writelog "snServerType set to: $snServerType"
$snOSVersion = $sysidnfo.u_build_os         
writelog "snOSVersion set to: $snOSVersion"
[int]$snRAM = $sysidnfo.u_build_ram
writelog "snRam set to: $snRAM"
$snCPU = $sysidnfo.u_build_cpu
writelog "snCPU set to: $snCPU"
[int]$snCdrive = $sysidnfo.u_build_c_drive							
writelog "snCdrive set to: $snCdrive"
[int]$snDdrive = $sysidnfo.u_build_d_drive
writelog "snDdrive set to: $snDdrive"
[int]$snEdrive = $sysidnfo.u_build_e_drive
writelog "snEdrive set to: $snEdrive"
[int]$snFdrive = $sysidnfo.u_build_f_drive
writelog "snFdrive set to: $snFdrive"
[int]$snGdrive = $sysidnfo.u_build_g_drive
writelog "snGdrive set to: $snGdrive"
[int]$snHdrive = $sysidnfo.u_build_h_drive
writelog "snGdrive set to: $snGdrive"
$snEnvironment = $sysidnfo.u_Environment          
writelog "snEnvironment set to: $($sysidnfo.u_Environment)"

#----------------------- Setup Session to Vcenter -----------------------# 
$duser = "us\s_ServiceNowRB_US"
$enstr = Get-Content "d:\scripts\vmdeploy\s_ServiceNowRB_US.cred"
$pi = Get-Content "d:\scripts\vmdeploy\pi.key"
$SPass=Convertto-SecureString $enstr -key $pi
$bstr = [System.Runtime.InteropServices.marshal]::SecureStringToBSTR($spass)
$pass = [System.Runtime.Interopservices.marshal]::PtrToStringAuto($bstr)
$hostname = $vCenter = "FENAPPVCP03.Us.maritz.net"
Try
{
	Connect-VIServer $hostname -user $duser -password $pass -WarningAction 0 -ErrorAction Stop | out-null
	$message = "Connected to vCenter Server $vCenter"
	HostLogContinue $message
}
Catch
{
	$message = "Failure to connect to $vCenter"
	HostLogEmailExit $message
}


#----------------------- Changing Primary Function to Server Type: $snServerType -----------------------# 
writelog "Determining Server Type"
write-output "[Info]Server Type is: $snServerType[/Info]" ##-foreground gray
If (($snServerType -eq "WEB-EXTRANET") -or ($snServerType -eq "WEB_INTRANET") -or ($snServerType -eq "WEB_INTERNET"))
{
	$snServerType = "Web"
	writelog "snServerType set to: $snServerType"
}
ElseIf (($snServerType -eq "DB-MSSQL") -or ($snServerType -eq "DB-MYSQL") -or ($snServerType -eq "DB-ORACLE") -or ($snServerType -eq "SQL") -or ($snServerType -like "*SQL*"))
{
	$snServerType = "SQL"
	writelog "snServerType set to: $snServerType"
}
ElseIf ($snServerType -eq "FTP/sFTP")
{
	$snServerType = "FTP"
	writelog "snServerType set to: $snServerType"
}
ElseIf ($snServerType -eq "Print")
{
	$snServerType = "Print"
	writelog "snServerType set to: $snServerType"
}
ElseIf ($snServerType -eq "Domain Controller")
{
	$snServerType = "DC"
	writelog "snServerType set to: $snServerType"
}
ElseIf ($snServerType -eq "Citrix")
{
	$snServerType = "Citrix"
	writelog "snServerType set to: $snServerType"
}
Else 
{
	$snServerType = "Wap"
	writelog "snServerType set to: $snServerType"
}
write-output "[Info]Server type changed to: $snServerType[/Info]" ##-foreground gray
writelog "Server Type is: $snServerType"

#----------------------- Determining Cluster Selection: $myCluster -----------------------# 
writelog "Determining Cluster Selection"
write-output "[Info]IP is $snIPAddress[/Info]" ##-foreground gray
$IP = ($snIPAddress -match "156.45.23[2-6].\d{1,3}") -or ($snIPAddress -match "192.168.2[0-1].\d{1,3}")
If ($IP -eq "True")
{
	$myCluster = "200_External_DL380"
}
ElseIf ($snServerType -eq "SQL")
{
	If ($snEnvironment -eq "Production")
	{
		$myCluster = "300_SQL_Production_DL380"
	}
	Else 
	{
		$myCluster = "100_Internal_Windows_DL585"
	}
}
ElseIf ($snServerType -eq "Citrix")
{
	$myCluster = "400_Citrix_UCS_Intel"
}
Else 
{
	$myCluster = "100_Internal_Windows_DL585"
}
write-output "[Info]Cluster Selection is: $myCluster[/Info]" ##-foreground gray
writelog "myCluster set to $myCluster"

#----------------------- Determine Folder Location Based on Server Type: $dstFld -----------------------# 
write-output "[Info]Server type is $snServerType[/Info]" #-fore gray
writelog "Folder Location based on Server Type"
If ($snServerType -eq "Wap")
{
    $dstFld = "Wap"
}
ElseIf ($snServerType -eq "SQL")
{
	If ($snEnvironment -eq "Staging")
	{
		$destination = "Fenton\SQL Servers\Staging-SQL"
	    $dstFld = Get-Folder -Name Staging-SQL | where {(Get-FolderPath -Folder $_).Path -eq $destination}
	}
	ElseIf ($snEnvironment -eq "Production")
	{
		$destination = "Fenton\SQL Servers\Production-SQL"
	    $dstFld = Get-Folder -Name Production-SQL | where {(Get-FolderPath -Folder $_).Path -eq $destination}
	}
	Else 
	{
		$destination = "Fenton\SQL Servers\Development-SQL"
	    $dstFld = Get-Folder -Name Development-SQL | where {(Get-FolderPath -Folder $_).Path -eq $destination}
	}
}
ElseIf ($snServerType -eq "Web")
{
	$dstFld = "Web"
}
ElseIf ($snServerType -eq "Citrix")
{
	$dstFld = "Build"
}
ElseIf ($snServerType -eq "FTP")
{
	$dstFld = "FTP-2012"
}
ElseIf ($snServerType -eq "Print")
{
	$dstFld = "Print Servers"
}
ElseIf ($snServerType -eq "DC")
{
	$dstFld = "Domain Controllers"
}
Else
{
	$dstFld = "Infrastructure Servers"
}
write-output "[Info]Destination Folder is: $dstFld[/Info]" #-fore gray
writelog "Destination Folder set to: $dstFld"

#----------------------- Determining Resource Pool based on Cluster assignment: $ResPoolName -----------------------# 
write-output "[Info]Environment is set to: $snEnvironment[/Info]" #-fore gray
writelog "Determining Resource Pool based on Cluster assignment"
If ($snEnvironment -eq "Development")
{
  If ($myCluster -eq "100_Internal_Windows_DL585")
  {
	$ResPoolName = "Development"
  }
  ElseIf ($myCluster -eq "200_External_DL380")
  {
	$ResPoolName = "Staging"
  }
}
ElseIf ($snEnvironment -eq "Build")
{
	$ResPoolName = "Build"
}
ElseIf ($snEnvironment -eq "Production")
{
	$ResPoolName = "Production"
}
Else 
{
	$ResPoolName = "Build"
}
write-output "[Info]Resource Pool Selection is: $ResPoolName[/Info]" #-fore gray
writelog "Resource Pool Selection is: $ResPoolName"

#----------------------- Determining VM Template based on OS selection: $myTemplate -----------------------# 
write-output "[Info]OS is set to: $snOSVersion[/Info]" #-fore gray
writelog "Determining VM Template based on OS selection"
If ($snOSVersion -eq "Win2008R2")
{
	$myTemplate = Get-Template -Name "FENTMP2008R2"
}
Else
{
	$myTemplate = Get-Template -Name "FENTMP2012R2"
}
write-output "[Info]VM Template Selection is: $myTemplate[/Info]" #-fore gray
writelog "VM Template Selection is: $myTemplate"

#----------------------- Determining Network based on Cluster: $myNetworkName -----------------------#
write-output "[Info]Cluster is set to: $myCluster[/Info]" #-fore gray 
If ($myCluster -eq "300_SQL_Production_DL380")
{
	$myNetworkName = "dvpgRISLAN_10.90.5.0"
}
ElseIf ($myCluster -eq "400_Citrix_UCS_Intel")
{
	$myNetworkName = "dvpgCtxLAN_10.55.1.0"
}
Else 
{
	$myNetworkName = "dvInternalRISLan_10.90.5.0"
}
write-output "[Info]Network is set to: $myNetworkName[/Info]" #-fore gray 
writelog "myNetworkName set to: $myNetworkName"

#----------------------- Gather Variables -----------------------#
$oscustomization = "20150123_AutoBuildBootStrap" 
try
{
$mySpecification = Get-OSCustomizationSpec -Name $oscustomization -ErrorAction Stop
}
catch 
{
	write-output "[OSCustimization]OS Customization not found: $oscustomization[/OSCustimization]" #-fore red
	Exit
}

writelog "Determining minimum space needed"
$vmsize=([int]$snCdrive+[int]$snDdrive+[int]$snEdrive+[int]$snFdrive+[int]$snGdrive+[int]$snHdrive)
$dsminspace=($vmsize+80) 
write-output "[Info]Minimum space needed is: $dsminspace GB[/Info]" ##-foreground gray
writelog "Minimum space needed is: $dsminspace GB"
if ($dsminspace -gt 1200)
{
	$message = "Vm is requiring $dsminspace of GB.  This is too large for the automated process.  The most you can build with this process is 1200 GB"
	HostLogEmailExit $message
}
Else {}

#----------------------- Determine Which DataStore to Assign based on Cluster assignment: $vmdepds -----------------------# 
write-output "[Info]Cluster is set to: $myCluster[/Info]" ##-foreground gray
writelog "Determining Datastore"
If ($myCluster -eq "200_External_DL380") 
{
	$vmdepds = Get-Datacenter Fenton | Get-Folder -type Datastore -Name 200_External | Get-Datastore | Where-Object { ($_.Name -match "PAR0[1-4]_[edp]*disk*") -and ($_.Name -notmatch "local")} |
	Select-Object Name,
		@{n="CapacityGB";e={[math]::round(($_.CapacityMB/1024))}},
		@{n="FreeSpaceGB";e={[math]::round(($_.FreeSpaceMB/1024))}},
		@{n="FreeSpacePercent";e={[math]::round(($_.FreeSpaceMB/$_.CapacityMB*100))}} |
	where {($_.FreeSpaceGB - $vm.UsedSpaceGB - $dsminspace) -gt 0} | Sort-Object -Property FreeSpaceGB | Select name -First 1
	$vmdepds = $vmdepds.Name
}
ElseIf ($myCluster -eq "300_SQL_Production_DL380") 
{
	$vmdepds = Get-Datacenter Fenton | Get-Folder -type Datastore -Name 300_SQL | Get-Datastore | Where-Object { ($_.Name -match "PAR0[1-4]_[edp]*disk*") -and ($_.Name -notmatch "local")} |
	Select-Object Name,
		@{n="CapacityGB";e={[math]::round(($_.CapacityMB/1024))}},
		@{n="FreeSpaceGB";e={[math]::round(($_.FreeSpaceMB/1024))}},
		@{n="FreeSpacePercent";e={[math]::round(($_.FreeSpaceMB/$_.CapacityMB*100))}} |
	where {($_.FreeSpaceGB - $vm.UsedSpaceGB - $dsminspace) -gt 0} | Sort-Object -Property FreeSpaceGB | Select name -First 1
	$vmdepds = $vmdepds.Name
}
Elseif ($myCluster -eq "400_Citrix_UCS_Intel") 
{
	$vmdepds = Get-Datacenter Fenton | Get-Folder -type Datastore -Name 400_Citrix | Get-Datastore | Where-Object { ($_.Name -match "NA01[1-9]*") -and ($_.Name -notmatch "local")} |
	Select-Object Name,
		@{n="CapacityGB";e={[math]::round(($_.CapacityMB/1024))}},
		@{n="FreeSpaceGB";e={[math]::round(($_.FreeSpaceMB/1024))}},
		@{n="FreeSpacePercent";e={[math]::round(($_.FreeSpaceMB/$_.CapacityMB*100))}} |
	where {($_.FreeSpaceGB - $vm.UsedSpaceGB - $dsminspace) -gt 0} | Sort-Object -Property FreeSpaceGB | Select name -First 1
	$vmdepds = $vmdepds.Name
}
Else 
{
#	$vmdepds = Get-Datacenter Fenton | Get-Folder -type Datastore -Name "100_Internal" | Get-Datastore | Where-Object { ($_.Name -match "PAR0[1-4]_[edp]*disk*") -and ($_.Name -notmatch "local")} |
#	Select-Object Name,
#		@{n="CapacityGB";e={[math]::round(($_.CapacityMB/1024))}},
#		@{n="FreeSpaceGB";e={[math]::round(($_.FreeSpaceMB/1024))}},
#		@{n="FreeSpacePercent";e={[math]::round(($_.FreeSpaceMB/$_.CapacityMB*100))}} |
#	where {($_.FreeSpaceGB - $vm.UsedSpaceGB - $dsminspace) -gt 0} | Sort-Object -Property FreeSpaceGB | Select name -First 1
	
	$vmdepds = Get-DatastoreCluster | Where {$_.Name -like "*100_Internal*"}
	
	$vmdepds = $vmdepds.Name
}
If (!$vmdepds)
{
	write-output "[Error]No Suitable DataStore location found![/Error]" -for red
	writelog "No Suitable Datastore Found"
	Exit
}
Else 
{
	write-output "[Info]Datastore Assigned is: $vmdepds [/Info]" #-foreground gray 
	writelog "Datastore Assigned is: $vmdepds"
}


#----------------------- VM Creation Process -----------------------# 
try
{
	$myResourcePool = Get-ResourcePool -Location $myCluster -Name $ResPoolName -ErrorAction Stop
}
catch 
{
	write-output "[Error]Unable to get resource pool at $myCluster with name $ResPoolName[/Error]" #-fore red
	Exit
}

writelog "Determining ESXI host"
try
{
	$ESXi=Get-Cluster $myCluster -ErrorAction Stop | Get-VMHost -state connected | Get-Random 
	$message = "Esxi host is: $ESXi"
	HostLogContinue $message
}
catch
{
	$message = "No suitable ESXI host was located"
	HostLogEmailExit $message
}

writelog "Creating VM named $myVmname"
Update-SN_DomainNameRecord -SysID $CISysID -SNproperty u_build_status -newvalue "Status:VM Deployment Initiated" -maintenanceLogMessage "Updated via automation, centralized logging will have script output"
try 
{
	get-vm $myVmname -ErrorAction Stop | out-null
	$message = "VM is already in vmware"
	HostLogEmailExit $message
}
catch
{
	try 
	{
		if ($vmdepds = "100_Internal_DSK02")
		{
			New-VM -Name $myVmname.ToUpper() -ResourcePool $ESXi -Datastore $vmdepds -Location $dstFld -Template $myTemplate -OSCustomizationSpec $mySpecification -ErrorAction Stop | out-null 
		}
		Else 
		{
			New-VM -Name $myVmname.ToUpper() -VMHost $ESXi -Datastore $vmdepds -Location $dstFld -DiskStorageFormat Thick -Template $myTemplate -OSCustomizationSpec $mySpecification -ErrorAction Stop | out-null
		}
		$message = "VM creation is complete"
		HostLogContinue $message
	}
	catch
	{
		$message = "Unable to create VM"
		HostLogEmailExit $message
	}
	Update-SN_DomainNameRecord -SysID $CISysID -SNproperty u_build_status -newvalue "Status:VM Deployed, configuration occurring" -maintenanceLogMessage "Updated via automation, centralized logging will have script output"
	
	#----------------------- Put the VM on the RIS network -----------------------# 
	writelog "Putting the VM on the TemplateHolder network"
	$myNetworkAdapters = Get-VM $myVmname.ToUpper() | Get-NetworkAdapter 
	$myVDPortGroup = Get-VDPortgroup -Name $myNetworkName
	try
	{
		Set-NetworkAdapter -NetworkAdapter $myNetworkAdapters -Portgroup $myVDPortGroup	-Confirm:$false | out-null #-StartConnected:$true	-Type e1000
		$message = "VM nic set to $myVDPortGroup"
		HostLogContinue $message
	}
	catch
	{
		$message = "Unable to switch VM's nic"
		HostLogEmailExit $message
	}
	writelog "Network move completed"

	#----------------------- move VM to appropriate resource Pool-----------------------# 

	writelog "Moving VM to appropriate Resource Pool"
	try
	{
		Get-VM $myVmname.ToUpper() -ErrorAction Stop | Move-VM -Destination $myResourcePool | out-null
		$message = "Vm placed in $myResourcePool"
		HostLogContinue $message
	}
	catch
	{
		$message = "Unable to place in $myResourcePool Resource Pool"
		HostLogEmailExit $message
	}
	writelog "Completed Resource Pool move"
	
	
	#----------------------- CPU and RAM adjustments -----------------------# 

	writelog "Making CPU and Ram adjustments"
	try
	{
		Get-VM $myVmname.ToUpper() -ErrorAction Stop | Set-VM -MemoryGB $snRAM -NumCPU $snCPU -Confirm:$false | out-null
		$message = "Ram and CPU Adjusted"
		HostLogContinue $message
	}
	catch
	{
		$message = "Unable to adjust CPU and RAM"
		HostLogEmailExit $message
	}

	writelog "Completed CPU and Ram adjustments"
	
	#----------------------- Adding Partitions -----------------------# 
	If ($snServerType -eq "SQL" -or $snServerType -eq "Citrix")
	{
		If($snDdrive -eq "" -or $snDdrive -eq "0" -or $snDdrive -eq $null) 
		{
			$message = "Did not find a value for snDdrive"
			HostLogEmailExit $message
		}
		Else 
		{
			writelog "Adding $snDdrive GB D drive"
			try
			{
				New-HardDisk -VM $myVmname.ToUpper() -CapacityGB $snDdrive -DataStore $vmdepds | out-null
				$message = "D drive added"
				HostLogContinue $message
			}
			catch
			{
				$message = "Unable to create a D drive"
				HostLogEmailExit $message								
			}
			writelog "Completed adding D drive"
		}
		If($snEdrive -eq "" -or $snEdrive -eq "0" -or $snEdrive -eq $null) 
		{
			$message = "No value for E drive found"
			HostLogEmailExit $message
		}
		Else 
		{	
			writelog "Adding $snEdrive GB E Drive"
			try
			{
				New-HardDisk -VM $myVmname.ToUpper() -CapacityGB $snEdrive -DataStore $vmdepds | out-null
				$message = "E drive added"
				HostLogContinue $message
			}
			catch
			{
				$message = "Unable to create a E drive"
				HostLogEmailExit $message					
			}
			writelog "Completed adding E drive"
		}
		If($snFdrive -eq "" -or $snFdrive -eq "0" -or $snFdrive -eq $null) 
		{
			$message = "No value for F drive found"
			HostLogEmailExit $message
		}
		Else 
		{
			writelog "Adding $snFdrive GB F drive"
			try
			{
				New-HardDisk -VM $myVmname.ToUpper() -CapacityGB $snFdrive -DataStore $vmdepds | out-null
				$message = "F drive added"
				HostLogContinue $message
			}
			catch
			{
				$message = "Unable to create a F drive"
				HostLogEmailExit $message					
			}
			writelog "completed adding F Drive"
		}
		If($snGdrive -eq "" -or $snGdrive -eq "0" -or $snGdrive -eq $null) 
		{
			$message = "No value for G drive found"
			HostLogEmailExit $message
		}
		Else 
		{	
			writelog "Adding $snGdrive GB G drive"
			try
			{
				New-HardDisk -VM $myVmname.ToUpper() -CapacityGB $snGdrive -DataStore $vmdepds | out-null
				$message = "G drive added"
				HostLogContinue $message
			}
			catch
			{
				$message = "Unable to create a G drive"
				HostLogEmailExit $message					
			}
			writelog "Completed adding G drive"
		}
		If($snHdrive -eq "" -or $snHdrive -eq "0" -or $snHdrive -eq $null) 
		{
			$message = "No value for H drive found"
			HostLogEmailExit $message
		}
		Else 
		{
			writelog "Adding $snHDrive GB H drive"
			try
			{
				New-HardDisk -VM $myVmname.ToUpper() -CapacityGB $snHdrive -DataStore $vmdepds | out-null
				$message = "H drive added"
				HostLogContinue $message
			}
			catch
			{
				$message = "Unable to create a H drive"
				HostLogEmailExit $message			
			}
			writelog "Completed Adding H drive"
		}
	}
	Else 
	{
		If($snDdrive -eq "" -or $snDdrive -eq "0" -or $snDdrive -eq $null) 
		{
			writelog "Did not find a value for snDdrive"
			$message = "No value for D drive found"
			HostLogEmailExit $message
		}
		Else 
		{
			writelog "Adding $snDdrive GB D drive"
			try
			{
				New-HardDisk -VM $myVmname.ToUpper() -CapacityGB $snDdrive -DataStore $vmdepds | out-null
				$message = "D drive added"
				HostLogContinue $message
			}
			catch
			{
				$message = "Unable to create a D drive"
				HostLogEmailExit $message			
			}
			writelog "Completed D drive"
		}
	}
	
	#----------------------- Unreserve VM's memory -----------------------# 
	$spec = New-Object VMware.Vim.VirtualMachineConfigSpec
	$spec.memoryReservationLockedToMax = $false
	try
	{
		(Get-VM $myVmname).ExtensionData.ReconfigVM_Task($spec) | out-null
		$message = "Memory Reservation Removed"
		HostLogContinue $message
	}
	catch
	{
		$message = "Unable to change memory reservation"
		HostLogEmailExit $message
	}
	
	#----------------------- Set Memory Reserve to 0 -----------------------# 
	try
	{
		Get-VM $myVmname | Get-VMResourceConfiguration | Set-VMResourceConfiguration -MemReservationMB 0 | out-null
		$message = "Memory Reservation Amount set to 0"
		HostLogContinue $message
	}
	catch
	{
		$message = "Unable to set reservation to 0"
		HostLogEmailExit $message		
	}
	
	#----------------------- Start VM -----------------------# 
	writelog "Starting VM"
	try
	{
		Start-VM -vm $myVmname.ToUpper() -ErrorAction Stop | out-null
		$message = "$myVmname started"
		HostLogContinue $message
	}
	catch
	{
		$message = "Unable to start $myVmname"
		HostLogEmailExit $message
	}
	writelog "Completed Starting VM"

	#----------------------- Put the VM on the appropriate network -----------------------# 
	writelog "Checking for vCenter OS Customization Process completion on [$($myVmname.ToUpper())] "
	
	$customizationResult = Wait-ForVMtoComeOnlineThenMonitorCustomization -VMName $($myVmname.ToUpper())
	if(!$customizationResult) 
	{
		$message = "OS Customization process failed"
		HostLogEmailExit $message
	}
	
	writelog "vCenter OS Customization Process complete for  [$($myVmname.ToUpper())]"
	
	Update-SN_DomainNameRecord -SysID $CISysID -SNproperty u_build_status -newvalue "Status:VM Deployment Script Completed, VM Started." -maintenanceLogMessage "Updated via automation, centralized logging will have script output"
	
	#Wait until Build Status turns to "Provisioning Complete" - Timeout after 2 hours
	$message = "Starting OS Configuration"
	HostLogContinue $message
	WaitTillProvisioningCompleteSNField
	Stop-Transcript
	$transpathrev = "c:\transcripts\VmDeployLog" + "$myVmname" + ".txt"
	If (test-path $transpathrev){remove-item $transpathrev -force}
	rename-item $transpath $transpathrev
	$a = Get-Content $transpathrev
	$a > $transpathrev
	Send-MailMessage -From "automation@maritz.com" -To "$emailaddress" -Subject "Provisioning Complete For - $myVmname" -Body "Provisioning is complete.  Build Log can be found at [ c:\transcripts\VmDeployLog ] on Fenwdsp01"
}