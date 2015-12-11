Param(
    [Parameter(Mandatory = $false)]
    [String]$sn_name
)

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
	$URI = "https://maritz.service-now.com/cmdb_ci_server.do?WSDL"
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
	if($srvNameKey.count -eq 1) 
	{
		$type = $WSProxy.getType().Namespace
		$datatype = $type + '.get'
		$property = New-Object $datatype
		$property.sys_id = $($srvNameKey.sys_id).split(",")[0]
		$global:out = $WSProxy.get($property)
	}
	elseif($srvNameKey.count -eq 0) 
	{
		Write-host "Error: Server not found in service Now`n"
		Exit
	}
	else 
	{
		Write-host "Error: More than one server record found in Service Now for [ $srvName ]`n"
		Exit
	}
}

Write-host "`n#--------------------------------------#" -fore red
Write-host "   Pull Server info from SN" -fore red
Write-host "#--------------------------------------#" -fore red
	
$sn_name = read-host "Please enter the server name"
Write-host "Querying SN" -fore yellow -nonewline
Get-SN_srvRecord "$sn_name"
Write-host " ...Complete" -fore green
Write-host "`n[ $sn_name ]" -fore Cyan
$rk = $out.sys_id
Write-host "SysID: " -fore yellow -nonewline
Write-host "$rk" -fore green
Write-host "[ end ]`n" -fore Cyan
$out

#$outputname = (Get-ServiceNowRecordByKey -RecordKey "$rk" -tableName "cmdb_ci_server_list").Name
#$outputname
#Get-ServiceNowRecordByKey -RecordKey "$rk" -tableName "cmdb_ci_server_list"