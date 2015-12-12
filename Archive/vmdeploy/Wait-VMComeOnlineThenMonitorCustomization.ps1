
Function Wait-ForVMtoComeOnlineThenMonitorCustomization
{
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

Wait-ForVMtoComeOnlineThenMonitorCustomization -VMName $VMName

<# Snippet added to main process of vmdeploy.ps1

writelog "Checking for vCenter OS Customization Process completion on [$($myVmname.ToUpper())] "
$customizationResult = Wait-ForVMtoComeOnlineThenMonitorCustomization -VMName $($myVmname.ToUpper())
if(!$customizationResult)
{
    writelog "vCenter OS Customization process failed. Stopping vmdeploy.ps1 script"
    throw "vCenter OS Customization process failed. Stopping vmdeploy.ps1 script"
}
writelog "vCenter OS Customization Process complete for  [$($myVmname.ToUpper())]"

#>