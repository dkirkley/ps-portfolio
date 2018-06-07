<#

.SYNOPSIS
This PowerShell script is to be used as a universal application uninstall script. It was originally written to be used
during the Windows 10 upgrade process to remove unwanted/incompatible applications.

.DESCRIPTION
For win32 applications, the name fed as a parameter needs to exactly match the application named listed in control panel. 
If the win32 application does not follow standard MSI install/uninstall guidelines it will fail (as the script uses the GUID/MSI 
uninstall switch from the registry).For appx applications, it should match the name property from the 
Get-AppxPackage/Get-ProvisionedAppxPackage cmdlets.

.EXAMPLE
.\ApplicationUninstall.ps1 -appname:Bonjour -Logging:true -Logfile:C:\Logs
.\ApplicationUninstall.ps1 -appname:Microsoft.SkypeApp -Logging:true -Logfile:C:\Logs

.NOTES
GUID can be found at:
HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall
HKLM:\SOFTWARE\Wow6432Node\Microsoft\Windows\CurrentVersion\Uninstall

.LINK

#>

[CmdletBinding()]param([string]$AppName, [string]$Logging, [string]$Logfile)

$reg = "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall"
$reg32 = "HKLM:\SOFTWARE\Wow6432Node\Microsoft\Windows\CurrentVersion\Uninstall"
 
Function LogWrite {
    Param ([string]$Logstring)
    $Time = (Get-Date).ToString()

    if ($Logging -eq $true) {
        Try {
            Test-Path $Logfile > $null
        }
        Catch {
            do {
                $Logfile = Read-Host -Prompt "Please enter a valid log file path"
            } until (Test-Path $Logfile)
        }
        Add-content $Logfile -value "$Time $Logstring"
    }
}
function ExitWithCode { 
    param($exitcode)
    $host.SetShouldExit($exitcode) 
    exit 
}

LogWrite "-------------------------------------------------------------------------------"
LogWrite "Application to uninstall is $appname"

if ($appname) {

    $key = Get-ChildItem -Path $reg, $reg32 | Get-ItemProperty | Where-Object {$_.DisplayName -eq $appname}

    #  Win32 uninstall
    if ($key) {
        $guids = $key.PSChildname

        LogWrite "Registry key(s) identified for $appname uninstall is $key"
        LogWrite "GUID(s) identified for $appname uninstall is $guids"

        foreach ($guid in $guids) {

            if ($guid -like "{*}") {

                LogWrite "Attempting uninstall using MSI command: msiexec.exe -ArgumentList /x $GUID /quiet /norestart -Wait -Passthru"
                $uninstall = (Start-Process -FilePath "msiexec.exe" -ArgumentList "/x $GUID /quiet /norestart" -Wait -Passthru)
                $exitcode = $uninstall.ExitCode

                LogWrite "$appname uninstall returned code $exitcode"

                if ($exitcode -eq 0 -or $exitcode -eq 3010) {
                    LogWrite "Successfully uninstalled $appname"
                    ExitWithCode
                }
                else {
                    Write-Warning "$appname had unexpected return code $exitcode - the uninstall may not have completed properly"
                    Write-Warning "Find error code $exitcode at https://msdn.microsoft.com/en-us/library/windows/desktop/aa376931(v=vs.85).aspx for more info"
                }
            }
            else {
                Write-Warning "$appname had unexpected GUID of $guid, unable to run uninstall command."
            }
        }
    }
    #Check for appx packages with app name
    elseif ($key -eq $null) {
        
        $Appx = Get-AppxPackage | Where-Object {$_.name -eq $AppName}
        $ProvAppx = Get-ProvisionedAppxPackage -Online | Where-Object {$_.displayname -eq $AppName} 

        if ($Appx) {
            LogWrite "Found $appname as an appx package"
            Remove-AppxPackage -Package $Appx
            $Appx = Get-AppxPackage | Where-Object {$_.name -eq $AppName}
            if ($Appx) {
                Write-Warning "$appname still detected - the uninstall may not have completed properly"
            }
            else {
                LogWrite "Successfully uninstalled $appname appx package"
            }
        }
        if ($ProvAppx) {
            LogWrite "Found $appname as a provisioned appx package"
            Remove-ProvisionedAppxPackage -PackageName $ProvAppx.PackageName -AllUsers -Online
            $ProvAppx = Get-ProvisionedAppxPackage -Online | Where-Object {$_.displayname -eq $AppName}
            if ($ProvAppx) {
                Write-Warning "$appname still detected - the uninstall may not have completed properly"
            }
            else {
                LogWrite "Successfully uninstalled $appname provisioned appx package"
            }
        }
        else {
            Write-Warning "$appname not found in registry or appx packages, verify application name and that it is installed"
        }

        LogWrite "-------------------------------------------------------------------------------"

    }
    else {
        #No app parameters entered, exitting
        LogWrite "No application name entered"
        Start-Sleep -s 20
        Stop-Process -Id $PID
    }
}