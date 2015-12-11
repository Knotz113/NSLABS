
Clear-host
write-host "`n`n*--------------------*" -Fore White
write-host "   Let's move a VM!" -Fore White
write-host "*--------------------*" -Fore White
$vm = read-host "`nWhat is the VM we are moving?"
$myCluster = get-vm $vm | get-cluster
write-host "Current cluster is:" -Fore Yellow -nonewline; start-Sleep -Seconds 2
write-host " $myCluster" -Fore Green 
$myDatastore = get-vm $vm | get-datastore
write-host "Current datastore is:" -Fore Yellow -nonewline; start-Sleep -Seconds 2
write-host " $myDatastore" -Fore Green 
$vmdescr = Get-VM $vm | Select Name, ProvisionedSpaceGB, UsedSpaceGB
$ProvSpaceTmp = [math]::round($vmdescr.ProvisionedSpaceGB , 0)
$ProvSpace = ($ProvSpaceTmp + 0)
write-host "Current provisioned space is:" -Fore Yellow -nonewline; start-Sleep -Seconds 2
write-host " "$ProvSpace"GB" -Fore Green 
$dsminspace = ($ProvSpace + 50 )

#----------------------- Determine Which DataStore to Assign based on Cluster assignment: $vmdepds -----------------------# 
#write-host "`nDetermining Datastore..." -foreground green

If ($myCluster -like "200_External_DL385") {
$vmdepds = Get-Datacenter Fenton | Get-Folder -type Datastore -Name "200_External" | Get-Datastore | Where-Object { ($_.Name -match "PAR0[1-4]_200_[edp]*disk*") -and ($_.Name -notmatch "local")} |
Select-Object Name,
    @{n="CapacityGB";e={[math]::round(($_.CapacityMB/1024))}},
    @{n="FreeSpaceGB";e={[math]::round(($_.FreeSpaceMB/1024))}},
    @{n="FreeSpacePercent";e={[math]::round(($_.FreeSpaceMB/$_.CapacityMB*100))}} |
where {($_.FreeSpaceGB - $vm.UsedSpaceGB - $dsminspace) -gt 0} | Sort-Object -Property FreeSpaceGB | Select name -First 1
	#write-host "result of If statement is:" $vmdepds
}
ElseIf (($myCluster -like "300_SQL_Production_DL380") -or ($myCluster -like "398_SQL_Internal_DL585_Legacy")) {
$vmdepds = Get-Datacenter Fenton | Get-Folder -type Datastore -Name 300_SQL | Get-Datastore | Where-Object { ($_.Name -match "PAR0[1-4]_[edp]*disk*") -and ($_.Name -notmatch "local")} |
Select-Object Name,
    @{n="CapacityGB";e={[math]::round(($_.CapacityMB/1024))}},
    @{n="FreeSpaceGB";e={[math]::round(($_.FreeSpaceMB/1024))}},
    @{n="FreeSpacePercent";e={[math]::round(($_.FreeSpaceMB/$_.CapacityMB*100))}} |
where {($_.FreeSpaceGB - $vm.UsedSpaceGB - $dsminspace) -gt 0} | Sort-Object -Property FreeSpaceGB | Select name -First 1
	#write-host "result of If statement is:" $vmdepds
}
elseif ($myCluster -like "400_Citrix_UCS_Intel") {
$vmdepds = Get-Datacenter Fenton | Get-Folder -type Datastore -Name 400_Citrix | Get-Datastore | Where-Object { ($_.Name -match "NA01[1-9]*") -and ($_.Name -notmatch "local")} |
Select-Object Name,
    @{n="CapacityGB";e={[math]::round(($_.CapacityMB/1024))}},
    @{n="FreeSpaceGB";e={[math]::round(($_.FreeSpaceMB/1024))}},
    @{n="FreeSpacePercent";e={[math]::round(($_.FreeSpaceMB/$_.CapacityMB*100))}} |
where {($_.FreeSpaceGB - $vm.UsedSpaceGB - $dsminspace) -gt 0} | Sort-Object -Property FreeSpaceGB | Select name -First 1
	#write-host "result of If statement is:" $vmdepds
}
Else {
$vmdepds = Get-Datacenter Fenton | Get-Folder -type Datastore -Name "100_Internal" | Get-Datastore | Where-Object { ($_.Name -match "PAR0[1-4]_[edp]*disk*") -and ($_.Name -notmatch "local")} |
Select-Object Name,
    @{n="CapacityGB";e={[math]::round(($_.CapacityMB/1024))}},
    @{n="FreeSpaceGB";e={[math]::round(($_.FreeSpaceMB/1024))}},
    @{n="FreeSpacePercent";e={[math]::round(($_.FreeSpaceMB/$_.CapacityMB*100))}} |
where {($_.FreeSpaceGB - $vm.UsedSpaceGB - $dsminspace) -gt 0} | Sort-Object -Property FreeSpaceGB | Select name -First 1
	#write-host "result of If statement is:" $vmdepds
}
write-host "Destination datastore assigned is:" -foreground Yellow -nonewline; start-Sleep -Seconds 2
write-host ""$vmdepds.name"" -Fore Green; start-Sleep -Seconds 2 
$ds = $vmdepds.name

$install = Read-Host "Do you want to move this VM to this Datastore? (Y/N)"
If (($install -eq "y") -or ($install -eq "Y")) { 
write-host "Preparing to move" -Fore Yellow ;start-Sleep -Seconds 2
Move-VM $vm -Datastore $ds -DiskStorageFormat thick
Write-Host "`n`t--------------<<    Move Complete    >>--------------" -Fore Green ;start-Sleep -Seconds 2  
	$another = Read-Host "`nDo you want to move another VM? (Y/N)"
	If (($another -eq "y") -or ($another -eq "Y")) {
	.\vm_move.ps1
	}
	ElseIf (($install -eq "n") -or ($install -eq "N")) {
	Exit
	}
	Else {
	Exit
	}
}
ElseIf (($install -eq "n") -or ($install -eq "N")) {
Exit
}
Else {
Exit
}
