$CurrentScriptFilePath = $script:MyInvocation.MyCommand.Path
$CurrentScriptLastModifiedDateTime = (Get-Item $script:MyInvocation.MyCommand.Path).LastWriteTime

Function Get-ServiceNowRecordByKey {
	param($RecordKey,$tableName)
    $Proxy = Get-ServiceNowTableHandle -tableName $tableName
    $type = $Proxy.getType().Namespace
    $datatype = $type + '.getRecords'
    $property = New-Object $datatype
    $property.sys_id = $RecordKey
    $Proxy.getRecords($property)
}
Function Get-ServiceNowTableHandle {
	param($tableName)
	$duser = "s_snblddata"
	if($local -eq "Yes") {
		$enstr = Get-Content ".\test.cred"
		$pi = Get-Content ".\pi.key"
	}
	Else {
		$enstr = Get-Content "d:\scripts\vmdeploy\test.cred"
		$pi = Get-Content "d:\scripts\vmdeploy\pi.key"
	}
	$SPass=Convertto-SecureString $enstr -key $pi
	$creds = New-Object System.Management.Automation.PSCredential $duser,$spass
	$URI = "https://maritzdev.service-now.com/cmdb_ci_server.do?WSDL"
	$SNWSProxy = New-WebServiceProxy -uri $URI -Credential $creds
	return $SNWSProxy
}
Function Get-SN_srvRecord {
	param($srvName)
	$duser = "s_ServiceNowRB_US"
	$enstr = Get-Content "d:\scripts\vmdeploy\s_ServiceNowRB_US.cred"
	$pi = Get-Content "d:\scripts\vmdeploy\pi.key"
	$SPass=Convertto-SecureString $enstr -key $pi
	$creds= New-Object System.Management.Automation.PSCredential $duser, $spass 
	$URI = "https://maritz.service-now.com/cmdb_ci_server_list.do?WSDL"
	$WSProxy = New-WebServiceProxy -uri $URI -Credential $creds
	$type = $WSProxy.getType().Namespace
	$datatype = $type + '.getKeys'
	$property = New-Object $datatype
	$property.name = $srvName
	$srvNameKey = $WSProxy.getKeys($property)
	if($srvNameKey.count -eq 1) {
		$type = $WSProxy.getType().Namespace
		$datatype = $type + '.get'
		$property = New-Object $datatype
		$property.sys_id = $($srvNameKey.sys_id).split(",")[0]
		$global:out = $WSProxy.get($property)
	}
	elseif($srvNameKey.count -eq 0) {
		Write-host "Error: Server not found in service Now`n"
		Exit
	}
	else {
		Write-host "Error: More than one server record found in Service Now for [ $srvName ]`n"
		Exit
	}
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
        #Write-Verbose "$($currentDomain.name) - $text"
        $text=$null
    }
	try 
	{
		$serviceNowReturnCode = $DNWSProxy.update($properties)
		write-host "Complete" -foreground green
	}
	catch
	{
		Write-host "Error" -fore red
		Exit
	}
}
Function Wait-ForVMtoComeOnlineThenMonitorCustomization {
    param($VMName,$timeOutSeconds=300)
    
    # Contact Kyle Gatewood [gatewok] for any issues with this function
    #$DebugPreference = "Continue"

    $startTime = Get-Date 
    $isVMActive = $false
    $customizationComplete = $false
    Write-Debug "TimeOut Seconds set to $timeOutSeconds"


    while(!$isVMActive)
    {
        #check every 30 seconds for handle to VM
        try
        {
            $VM = Get-VM -Name $VMName.ToUpper() -erroraction stop
            if( $VM.PowerState -eq "PoweredOn" )
	        {
                Write-Debug "VM is found and shows as Powered on"
		        $isVMActive = $true
	        }
        }
        catch
        {
            Write-Debug "VM is not found in host yet. waiting 30 seconds for VM with name $VMName to show up in vCenter"
            Start-Sleep -Seconds 30
        }
    }
    Write-Debug "VM with name of [$VMName] is now online"
    Write-Debug "Checking logs for customization status"

    $customizationStartedEvent = Get-VIEvent $vm | ?{ $_.FullFormattedMessage -like "Started Customization*"}
    
    

    While(!$customizationStartedEvent -and  $( (Get-Date).Subtract($startTime).Seconds -lt $timeOutSeconds ) )
    {
       Write-Debug "Waiting 15 seconds for customization to start on $VMName $(($timeOutSeconds - (Get-Date).Subtract($startTime).Seconds) /60 ) minutes left until timeout"
       Start-Sleep -Seconds 15
       $customizationStartedEvent = Get-VIEvent $vm | ?{ $_.FullFormattedMessage -like "Started Customization*"}
    }
    if( $customizationStartedEvent)
    {
        
        $message = "Customization Start found in Logs, Customization began at $( $customizationStartedEvent.CreatedTime)"
        Write-Debug $message
        writelog $message
    }

    $customizationCompletedEvent = Get-VIEvent $vm | ?{ $_.FullFormattedMessage -like "Customization of*"}
    if($customizationCompletedEvent){$customizationComplete = $true}

    While(!$customizationCompletedEvent -and  $( (Get-Date).Subtract($startTime).Seconds -lt $timeOutSeconds ) )
    {
       Write-Debug "Waiting 15 seconds for customization to complete on $VMName $(($timeOutSeconds - (Get-Date).Subtract($startTime).Seconds) /60 ) minutes left until timeout"
       Start-Sleep -Seconds 15
       $customizationCompletedEvent = Get-VIEvent $vm | ?{ $_.FullFormattedMessage -like "Customization of*"}
       if($customizationCompletedEvent){$customizationComplete = $true}
    }

    if($customizationComplete -eq $true)
    {
        $message =  "vCenter Customization Completion found in Logs, Customization completed at $( $customizationStartedEvent.CreatedTime)"
        Write-Debug $message
        writelog $message
    }
    else
    {
        $message =  "vCenter Customization appears to have failed or never started. Please research."
        Write-Debug $message
        writelog $message
    }

    #script returns false if it went past timeout and never found cutomization to be complete, true if customization was found to be completed
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


Write-host "`n#------------------------------------------------------------#" -fore red
Write-host "   Automated Server Deployment Mechanism (Manual Kickoff)" -fore red
Write-host "#------------------------------------------------------------#" -fore red
	
$sn_name = read-host "Please enter the server name"
Get-SN_srvRecord "$sn_name"
$out = $out.sys_id
$out

sl D:\Scripts\vmdeploy

.\vmdeploy.ps1 $out

<#
$sn_name = read-host "Please enter the server name"
#Get-SN_srvRecord "$sn_name"
#$out = $out.sys_id
#$out
DO
{
.\check_sn_field.ps1 $sn_name
} 
Until ($snfield -eq "Provisioning Complete")
#>