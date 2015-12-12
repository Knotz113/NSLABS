########################################################################################################
#LogEvent Routines
#
#Code and Concepts by Chris Gillham, Andy Wolfe, George Harms, Kyle Gatewood
#Web service and site by Kiran Kapoor and Mary Mueller
#Maritz 
#10/10/2014
#Updated 11/05/2014 by George Harms But for the event log item.  If we want to use this in conjunction with custom event logs, perhaps a modification (in blue below) like this will suffice?  Checks to see if it can read the passed in Logname and if not, default to the Application log.  Then we can specify if you want to use a custom event log, you need to create it ahead of time.   This way the module doesn’t have to worry about elevation of rights, etc to create the log (not that we can’t build that in later.)
#Nothing more than a rudimentary change for $urltype.
########################################################################################################

Function LogEvent
{
	Param(
	[Parameter(Mandatory=$false)]
  	[bool]$WebService = $true,
	[Parameter(Mandatory=$false)]
  	[string]$AppKey = "54F789D3-29DE-4F86-9BAA-C396BF7967FB",
  	[Parameter(Mandatory=$false)]
  	[string]$AppName = "AutoBuild",
	[Parameter(Mandatory=$false)]
  	[string]$ApiKey = "AD4D5552-A125-4C5D-8AD5-91C9457BFE5C",
  	[Parameter(Mandatory=$false)]
    [bool]$LocalLogFile = $false,
    [Parameter(Mandatory=$false)]
  	[string]$LocalLogFileName,
	[Parameter(Mandatory=$false)]
  	[bool]$WindowsEventViewer = $false,
  	[Parameter(Mandatory=$true)]
  	[string]$MessageType= "Notification",
    [Parameter(Mandatory=$true)]
  	[string]$Message,    
    [Parameter(Mandatory=$false)]
  	[string]$LogName = "Application",
    [Parameter(Mandatory=$false)]
  	[string]$LogSource = 'EventSystem',
    [Parameter(Mandatory=$false)]    
  	[string]$ComputerName = $env:ComputerName,
    [Parameter(Mandatory=$false)]    
  	[string]$DomainName = $env:USERDOMAIN,
    [Parameter(Mandatory=$false)]    
  	[string]$ScriptUserID = $env:USERNAME,
    [Parameter(Mandatory=$false)]    
  	[string]$ScriptFilePath = $script:MyInvocation.MyCommand.Path,
	[Parameter(Mandatory=$true)]
	[String]$UrlType,
    [Parameter(Mandatory=$false)]    
  	[string]$ScriptFileLastModified = (Get-Item $script:MyInvocation.MyCommand.Path).LastWriteTime
	)

    if ($WebService -eq $true)
    {
        LogEventtoWebService -LogSource $LogSource -MessageType $MessageType -Message $Message -ScriptFilePath $ScriptFilePath -ScriptFileLastModified $ScriptFileLastModified -UrlType $UrlType
    }
    if ($LocalLogFile -eq $true)
    {
        LogEventtoLocalDisk -LogFile $LocalLogFileName -LogSource $LogSource -MessageType $MessageType -Message $Message -ScriptFilePath $ScriptFilePath -ScriptFileLastModified $ScriptFileLastModified
    }
    if ($WindowsEventViewer -eq $true)
    {
        LogEventtoLocalEventViewer -LogName $LogName -LogSource $LogSource -MessageType $MessageType -Message $Message -ScriptFilePath $ScriptFilePath -ScriptFileLastModified $ScriptFileLastModified
    }

  }

#http://nasdev.maritzdev.com/Logger/logger.asmx

#Requires -version 2.0

#Development Application ID/Key: A256A636-F27F-4D69-8654-C08C8353AF95
#Development API Key: CD14E26D-3A2F-4E36-BDF3-64E87BF2C7EE

#Production Application ID/Key: EE6B2EB1-E05F-4393-BB1F-65CE78F9D9FA
#Production API Key: 45DC5997-EAEF-454B-80D7-273795AF0610

#Here’s the Production web service --
#https://nasprod.maritz.com/Logger/Logger.asmx
#external prod url
#http://nas.maritz.com/LoggerRelay/loggerRelay.asmx?op=Log

#Here’s the production Admin screen -
#https://nasprod.maritz.com/LoggerAdmin/Login.aspx

Function LogEventtoWebService
{
	Param(
	[Parameter(Mandatory=$false)]
  	[string]$AppKey = "54F789D3-29DE-4F86-9BAA-C396BF7967FB",
  	[Parameter(Mandatory=$false)]
  	[string]$AppName = "AutoBuild",
	[Parameter(Mandatory=$false)]
  	[string]$ApiKey = "AD4D5552-A125-4C5D-8AD5-91C9457BFE5C",
  	[Parameter(Mandatory=$true)]
  	[string]$MessageType,
	[Parameter(Mandatory=$true)]
  	[string]$Message,
  	[Parameter(Mandatory=$false)]
  	[string]$LogSource = '',
    [Parameter(Mandatory=$false)]    
  	[string]$ComputerName = $env:ComputerName,
    [Parameter(Mandatory=$false)]    
  	[string]$DomainName = $env:USERDOMAIN,
    [Parameter(Mandatory=$false)]    
  	[string]$ScriptUserID = $env:USERNAME,
    [Parameter(Mandatory=$false)]    
  	[string]$ScriptFilePath = $script:MyInvocation.MyCommand.Path,
	[Parameter(Mandatory=$true)]
	[String]$UrlType,
    [Parameter(Mandatory=$false)]    
  	[string]$ScriptFileLastModified = (Get-Item $script:MyInvocation.MyCommand.Path).LastWriteTime
	)
	
    Try
    {
	    if($UrlType -like 'Dev*'){
			$URI = "http://nasdev.maritzdev.com/Logger/logger.asmx?wsdl"
		}
		if($UrlType -like 'Internal'){
			$URI = "https://nasprod.maritz.com/Logger/Logger.asmx?wsdl"
		}
		if($UrlType -like 'External'){
			$URI = "http://nas.maritz.com/LoggerRelay/loggerRelay.asmx?op=Log"
		}
		#Development $URI = "http://nasdev.maritzdev.com/Logger/logger.asmx?wsdl"
        #Production $URI = "https://nasprod.maritz.com/Logger/Logger.asmx?wsdl"
        #$URI = "https://nasprod.maritz.com/Logger/Logger.asmx?wsdl"
        $Proxy = New-WebServiceProxy -uri $URI -namespace WebServiceProxy
	    $Proxy.Log($AppKey, $AppName, $ApiKey, $MessageType, $Message, $LogSource, $ComputerName, $DomainName, $ScriptUserID, $ScriptFilePath, $ScriptFileLastModified)
    }
    catch 
    {
        Write-Host "Error (Webservice)" -ForegroundColor Red
    }
}

#LogEvent -LogSource "Test" -MessageType "Notification" -Message "This is a test from PowerShell."
#LogEvent -MessageType "Warning" -Message "This is a test from PowerShell."
#LogEvent -MessageType "Error" -Message "This is a test from PowerShell."
#LogEvent -MessageType "Debug" -Message "This is a test from PowerShell."

Function LogEventtoLocalDisk
{
Param (
    [Parameter(Mandatory=$true)]
  	[string]$LogFile,    
    [Parameter(Mandatory=$true)]
    [string]$MessageType,
	[Parameter(Mandatory=$true)]
  	[string]$Message,
    [Parameter(Mandatory=$false)]
  	[string]$LogSource = '',
    [Parameter(Mandatory=$false)]    
  	[string]$ComputerName = $env:ComputerName,
    [Parameter(Mandatory=$false)]    
  	[string]$DomainName = $env:USERDOMAIN,
    [Parameter(Mandatory=$false)]    
  	[string]$ScriptUserID = $env:USERNAME,
    [Parameter(Mandatory=$false)]    
  	[string]$ScriptFilePath = $script:MyInvocation.MyCommand.Path,
    [Parameter(Mandatory=$false)]    
  	[string]$ScriptFileLastModified = (Get-Item $script:MyInvocation.MyCommand.Path).LastWriteTime    
    )
    
    if (!(Test-Path -path $LogFile ))
    {
        $LogFile = New-Item -type file $LogFile
    }
       
    Try
    {
        #Write-Host $Message -ForegroundColor White
        Add-content $Logfile -value "$((Get-Date).ToString("yyyy-MM-dd HH:mm:ss.fff")), $Message, $MessageType, $LogSource, $ComputerName, $DomainName, $ScriptUserID, $ScriptFilePath, $ScriptFileLastModified"
    }
    catch [system.UnauthorizedAccessException]
    {
        Write-Host "Error (logfile): Write access denied to $LogFile" -ForegroundColor Red
    }
}

Function LogEventtoLocalEventViewer
{
Param (
    [Parameter(Mandatory=$true)]
  	[string]$LogName,      
    [Parameter(Mandatory=$true)]
    [string]$MessageType,
	[Parameter(Mandatory=$true)]
  	[string]$Message,
    [Parameter(Mandatory=$true)]
  	[string]$LogSource,
    [Parameter(Mandatory=$false)]    
  	[string]$ComputerName = $env:ComputerName,
    [Parameter(Mandatory=$false)]    
  	[string]$DomainName = $env:USERDOMAIN,
    [Parameter(Mandatory=$false)]    
  	[string]$ScriptUserID = $env:USERNAME,
    [Parameter(Mandatory=$false)]    
  	[string]$ScriptFilePath = $script:MyInvocation.MyCommand.Path,
    [Parameter(Mandatory=$false)]    
  	[string]$ScriptFileLastModified = (Get-Item $script:MyInvocation.MyCommand.Path).LastWriteTime
    )     
    
    $EventMessage = "$Message, $LogSource, $ComputerName, $DomainName, $ScriptUserID, $ScriptFilePath, $ScriptFileLastModified"

    $EntryType = "Information"

    if($MessageType -eq "Notification")
    {
        $EntryType = "Information"
    }

    if($MessageType -eq "Warning")
    {
        $EntryType = "Warning"
    }

    if($MessageType -eq "Error")
    {
        $EntryType = "Error"
    }

    if($MessageType -eq "Debug")
    {
        $EntryType = "Information"
    }

    if($MessageType -eq "Generic")
    {
        $EntryType = "Information"
    }

    Try
    {
        write-eventlog -EntryType $EntryType -EventID 0001 -logname $LogName -source $LogSource -message $EventMessage

    }
    catch [system.UnauthorizedAccessException]
    {
        Write-Host "Error (EventViewer): Write access denied to $LogFile" -ForegroundColor Red
    }  

}