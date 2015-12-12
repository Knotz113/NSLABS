function setAuditingFolder {
		#write-host "Correcting Auditing Settings:" -fore yellow -nonewline
        $user = "Everyone"
        $SD = ([WMIClass] "Win32_SecurityDescriptor").CreateInstance()
        $ace = ([WMIClass] "Win32_ace").CreateInstance()
        $Trustee = ([WMIClass] "Win32_Trustee").CreateInstance()
        $SID = (New-Object System.Security.Principal.NTAccount $user).translate([System.Security.Principal.SecurityIdentifier])
        [byte[]] $SIDArray = ,0 * $SID.BinaryLength
        $SID.GetBinaryForm($SIDArray, 0)
        $Trustee.Name = $user
        $Trustee.SID = $SIDArray
		$ace.AccessMask = $FOLDER_ACCESS_MASK
		$ace.AceFlags = $FOLDER_ACE_FLAGS
		$ace.AceType = $SYSTEM_AUDIT_ACE_TYPE
        $ace.Trustee = $Trustee
        $SD.SACL = $ace
        $SD.ControlFlags = $SE_SACL_PRESENT
        # Write-Host ====Setting ControlFlags to : $SD.ControlFlags
        $wPrivilege = Get-WmiObject -Class Win32_LogicalFileSecuritySetting -filter "path='$fonamex'" -ComputerName $COMPUTER
        $wPrivilege.psbase.Scope.Options.EnablePrivileges = $true
        $wPrivilege.setsecuritydescriptor($SD) | Out-Null
		#Write-host " ...Complete" -fore green
		Write-Host "Changed to: " -fore white -nonewline
		Write-Host AceFlags: $ace.AceFlags AccessMask: $ace.AccessMask Trustee: $ace.Trustee.Name -ForegroundColor white
}
function setAuditingFile {
		#write-host "Correcting Auditing Settings:" -fore yellow -nonewline
        $user = "Everyone"
        $SD = ([WMIClass] "Win32_SecurityDescriptor").CreateInstance()
        $ace = ([WMIClass] "Win32_ace").CreateInstance()
        $Trustee = ([WMIClass] "Win32_Trustee").CreateInstance()
        $SID = (New-Object System.Security.Principal.NTAccount $user).translate([System.Security.Principal.SecurityIdentifier])
        [byte[]] $SIDArray = ,0 * $SID.BinaryLength
        $SID.GetBinaryForm($SIDArray, 0)
        $Trustee.Name = $user
        $Trustee.SID = $SIDArray
		$ace.AccessMask = $FILE_ACCESS_MASK
		$ace.AceFlags = $FILE_ACE_FLAGS
		$ace.AceType = $SYSTEM_AUDIT_ACE_TYPE
        $ace.Trustee = $Trustee
        $SD.SACL = $ace
        $SD.ControlFlags = $SE_SACL_PRESENT
        # Write-Host ====Setting ControlFlags to : $SD.ControlFlags
        $wPrivilege = Get-WmiObject -Class Win32_LogicalFileSecuritySetting -filter "path='$fnamex'" -ComputerName $COMPUTER
        $wPrivilege.psbase.Scope.Options.EnablePrivileges = $true
        $wPrivilege.setsecuritydescriptor($SD) | Out-Null
		#Write-host " ...Complete" -fore green
		Write-Host "Changed to: " -fore white -nonewline
		Write-Host AceFlags: $ace.AceFlags AccessMask: $ace.AccessMask Trustee: $ace.Trustee.Name -ForegroundColor white
}

$COMPUTER				= (Get-WmiObject Win32_OperatingSystem).CSName
$SE_SACL_PRESENT		= [System.Security.AccessControl.ControlFlags]"SystemAclPresent"
$SYSTEM_AUDIT_ACE_TYPE	= [System.Security.AccessControl.AceType]"SystemAudit"
$FILE_ACCESS_MASK 		= 852246
$FILE_ACE_FLAGS			= 64
$FOLDER_ACCESS_MASK		= 852310
$FOLDER_ACE_FLAGS 		= 67


Clear
Write-host "-----------------" -fore red
Write-host "Folder Check" -fore red
Write-host "-----------------" -fore red
$FilePath = "D:\audit\foldersToAudit.csv"
$FolderList = Import-Csv $FilePath 
ForEach ($FolderName in $FolderList) {
$foname = ($FolderName.Folder)
write-host "`n[ $foname ]" -fore cyan
If (test-path $foname){
$fonamex = [regex]::Escape("$foname")
Do{
$wPrivilege = Get-WmiObject -Class Win32_LogicalFileSecuritySetting -filter "path='$fonamex'" -ComputerName $COMPUTER
$wPrivilege.psbase.Scope.Options.EnablePrivileges = $true
$osd = $wPrivilege.GetSecurityDescriptor()
If (!$osd.Descriptor.SACL) {
	Write-host "No SACL set for [ $foname ]" -fore red
	setAuditingFolder
	}  Else {
	Write-host "SACL set for [ $foname ]" -fore yellow
	ForEach ($ace In $osd.Descriptor.SACL) {
		            If (($ace.AceFlags -eq $FOLDER_ACE_FLAGS) -and ($ace.AccessMask -eq $FOLDER_ACCESS_MASK) -and ($ace.Trustee.Name -eq "Everyone")) {
	                	Write-Host "Correct:" $folder AceFlags: $ace.AceFlags AccessMask: $ace.AccessMask Trustee: $ace.Trustee.Name -ForegroundColor Green
						$exitfo = "yes"
					} Else {
						Write-Host INCORRECT $folder AceFlags`($FOLDER_ACE_FLAGS`): $ace.AceFlags AccessMask`($FOLDER_ACCESS_MASK`): $ace.AccessMask Trustee`(Everyone`): $ace.Trustee.Name -ForegroundColor Red
						setAuditingFolder
					}
					}
	}
} Until ($exitfo)
remove-variable exitfo
}
Else {
Write-host "Folder Not Found!" -fore red
}


}


Write-host "`n-----------------" -fore red
Write-host "File Check" -fore red
Write-host "-----------------" -fore red
$FilePath = "D:\audit\filesToAudit.csv"
$FileList = Import-Csv $FilePath 
ForEach ($FileName in $FileList) {
$fname = ($FileName.File)
write-host "`n[ $fname ]" -fore cyan
If (test-path $fname){
$fnamex = [regex]::Escape("$fname")
$fnamex = $fnamex.Replace("\.", ".")
Do{
$fPrivilege = Get-WmiObject -Class Win32_LogicalFileSecuritySetting -filter "path='$fnamex'" -ComputerName $COMPUTER
$fPrivilege.psbase.Scope.Options.EnablePrivileges = $true
$osd = $fPrivilege.GetSecurityDescriptor()
If (!$osd.Descriptor.SACL) {
	Write-host "No SACL set for [ $fname ]" -fore red
	setAuditingFile
	}  Else {
	Write-host "SACL set for [ $foname ]" -fore yellow
	ForEach ($ace In $osd.Descriptor.SACL) {
		                If (($ace.AceFlags -eq $FILE_ACE_FLAGS) -and ($ace.AccessMask -eq $FILE_ACCESS_MASK) -and ($ace.Trustee.Name -eq "Everyone")) {
	                	Write-Host "Correct:" $folder AceFlags: $ace.AceFlags AccessMask: $ace.AccessMask Trustee: $ace.Trustee.Name -ForegroundColor Green
						$exitfi = "yes"
					} Else {
						Write-Host INCORRECT $folder AceFlags`($FILE_ACE_FLAGS`): $ace.AceFlags AccessMask`($FILE_ACCESS_MASK`): $ace.AccessMask Trustee`(Everyone`): $ace.Trustee.Name -ForegroundColor Red
						setAuditingFile
					}
					}
	}
} Until ($exitfi)
remove-variable exitfi	
}
Else {
Write-host "File Not Found!" -fore red
}
}

Write-host "`n"