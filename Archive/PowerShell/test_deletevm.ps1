$vm = read-host "What is the vm name"
$a = get-template | get-view | Get-VIObjectByVIView | where {$_.Name -eq '$vm'}
if ($a) {
Write-host "Template found"
}
Else {
Write-host "No Template Found"
}

#Remove-Template -Template FENTMP2008R2 -DeletePermanently -Confirm:$false