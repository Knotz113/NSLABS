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
Function Get-SN_srvRecord {
# This function first gets all records so that it can find the sysid for the one we want, in order to
# retrieve the full record
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
    Write-host "Error: Server not found in service Now"
	#throw "Error: Server not found in service Now"
}
else
{
    throw "Error: More than one server record found in Service Now for [ $srvName ]"
}
}

#Required
#Get the current script file fully qualified path, name, and last update datetime
Write-host "`n#--------------------------------------#" -fore red
Write-host "Compare SN CPU's to Vmware CPU's" -fore red
Write-host "#--------------------------------------#" -fore red

$countyes = 0
$countno = 0
$FilePath = "D:\Scripts\SN_Call\CPUresults.csv"
$ServerList = Import-CSV $FilePath | select -First 20
ForEach ($computerName in $ServerList) {
	$name = $computerName.Name
	$cpu = $computerName.vCPUs
	
	write-host "`n$name" -fore cyan
	Write-host "Vmware: " -fore yellow -nonewline
	Write-host "$cpu"
	Write-host "Service Now: " -fore yellow -nonewline
	
	$sn_name = $computername.name
	Get-SN_srvRecord "$sn_name"
	
	if ($out){
		$rk = $out.sys_id
		$outputname = (Get-ServiceNowRecordByKey -RecordKey "$rk" -tableName "cmdb_ci_server_list").Name
		$outputcpu = (Get-ServiceNowRecordByKey -RecordKey "$rk" -tableName "cmdb_ci_server_list").cpu_count
		$outputcore = (Get-ServiceNowRecordByKey -RecordKey "$rk" -tableName "cmdb_ci_server_list").cpu_core_count
		$outputcpu
		$outputcore
		$totalcores = $outputcpu * $outputcore
		Write-host "$totalcores"
		If ($totalcores -eq $cpu) {
			Write-host "CPU's Match!" -fore green
			$countyes ++
		}
		Else {
			Write-host "CPU's Do Not Match!" -fore red
			$countno ++
		}
	}
}
Write-host "`nTOTALS"
Write-host "----------"
Write-host "Total Match Count: " -nonewline -fore green
Write-host "$countyes"
Write-host "Total Not-Match Count: " -nonewline -fore red
Write-host "$countno"
Write-host ""