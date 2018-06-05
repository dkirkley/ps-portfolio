<#

.SYNOPSIS
This PowerShell script populates environment variables with mobile broadband information.

.DESCRIPTION
If the device has a mobile broadband modem, mobile broadband information (SIM, phone, ID, signal, model, firmware)
is collected and stored in environment variables. These variables are then collected via SCCM (or other means). 
The '-logging' parameter may be used to enable logging. The '-inventory' parameter may be used to force a Delta or Full SCCM hardware inventory.

.EXAMPLE
.\REMIND.ps1 -logging:true -inventory:delta

.NOTES
To view the variables on a machine, go to Start, search for "environment", 
click "edit the system environment variables". Click "environment variables", and view the 'GCD-' variables under "System variables'.

.LINK

.REMARKS

#>

[CmdletBinding()]param([string]$Logging, [string]$Inventory, [string]$Logfile)

$Time = (Get-Date).ToString()
 
Function LogWrite {
    Param ([string]$Logstring)
    $Time = (Get-Date).ToString()

    if ($Logging -eq $true) {
        Try{
            Test-Path $Logfile > $null
        }
        Catch{
            do {
                $Logfile = Read-Host -Prompt "Please enter a valid log file path"
            } until (Test-Path $Logfile)
        }
        Add-content $Logfile -value "$Time $Logstring"
    }
}

LogWrite "-------------------------------------------------------------------------------"
LogWrite "- INFO: Gather-CellData launched"

##########################################
# Stores data gathered into environment
##########################################

function Add-Data($VarName, $VarValue) {
    
    switch ($VarName) {

        {($_ -like "GCD-LogTime") } {

            LogWrite "- INFO: Storing data in EnVar: $VarName - $VarValue"
            [Environment]::SetEnvironmentVariable("$VarName", "$VarValue", "Machine")

        }

        {($_ -like "GCD-WWANPhone")} {
            if ($VarValue -like "") {
                LogWrite "- INFO: Storing data in EnVar: $VarName - Not activated"
                [Environment]::SetEnvironmentVariable("$VarName", "Not activated", "Machine")
            }
            else {
                LogWrite "- INFO: Storing data in EnVar: $VarName - $VarValue"
                [Environment]::SetEnvironmentVariable("$VarName", "$VarValue", "Machine")
            }
        }

        {($_ -like "GCD-WWANSIM")} {
            if ($VarValue -like "") {
                LogWrite "- INFO: Storing data in EnVar: $VarName - No SIM"
                [Environment]::SetEnvironmentVariable("$VarName", "No SIM", "Machine")
            }
            else {
                LogWrite "- INFO: Storing data in EnVar: $VarName - $VarValue"
                [Environment]::SetEnvironmentVariable("$VarName", "$VarValue", "Machine")
            }
        }

        {($_ -like "GCD-WWANModel") -or ($_ -like "GCD-WWANFirmware") -or ($_ -like "GCD-WWANID") -or ($_ -like "GCD-WWANDriver")} {
            if ($VarValue -like "*ERROR*") {
                LogWrite "- ERROR: Unable to detect $VarName - query returned: $VarValue"
                [Environment]::SetEnvironmentVariable("$VarName", "Unavailable", "Machine")
            }
            elseif ($VarValue -eq "") {
                LogWrite "- ERROR: Unable to detect $VarName - query returned: a null value"
            }
            else {
                LogWrite "- INFO: Storing data in EnVar: $VarName - $VarValue"
                [Environment]::SetEnvironmentVariable("$VarName", "$VarValue", "Machine")
            }
        }
    }
}

##########################################
# Force SCCM hardware inventory to run
##########################################

function Start-SCCMInv($Type) {

    $SMSClient = Get-CimClass -Namespace root\ccm -ClassName SMS_Client
    $ScheduleID = "{00000000-0000-0000-0000-000000000001}"

    if ($SMSClient) {
        switch ($Type) {
            "delta" {
                $HwInv = Invoke-CimMethod -ClassName SMS_Client -MethodName TriggerSchedule -Arguments @{sScheduleID = "$ScheduleID"} -Namespace root/ccm
                LogWrite "- INFO: Delta SCCM HW inventory started - check C:\Windows\CCM\Logs\InventoryAgent.log for details"
            }

            "full" {
                
                #Clearing HW or SW inventory delta flag...
                $deltaflag = Get-CimInstance -Namespace root\ccm\InvAgt -ClassName InventoryActionStatus | Where-Object {$_.InventoryActionID -eq '{00000000-0000-0000-0000-000000000001}'}     
                if ($deltaflag) {
                    Remove-CimInstance -InputObject $deltaflag
                }

                $HwInv = Invoke-CimMethod -ClassName SMS_Client -MethodName TriggerSchedule -Arguments @{sScheduleID = "$ScheduleID"} -Namespace root/ccm
                LogWrite "- INFO: Full SCCM HW inventory started - check C:\Windows\CCM\Logs\InventoryAgent.log for details"
            }
            default {
                LogWrite "- ERROR: No inventory Type provided - the options are delta or full."
            }
        }
    }
    else {
        LogWrite "- ERROR: Could not get SCCM WMI class"
    }
}

##########################################
# Main
##########################################

$Mbn = netsh mbn show interface #gather WWAN connection info

# Check for presence of modem
if ($Mbn -eq "Mobile Broadband Service (wwansvc) is not running.") {
    LogWrite "- WARNING: No broadband modem detected."
    Add-Data "GCD-LogTime" "$Time"
}
else {
    LogWrite "- INFO: Modem detected"
    #$Mbnmanufact = $Mbn | Select-String "Manufacturer" | ForEach-Object {$_ -replace "    Manufacturer       : ", ""}
    $MbnDriverVer = (Get-CimInstance -ClassName Win32_PnPSignedDriver | Where-Object {$_.DeviceID -like "USB\VID_1199&PID_9041*" -or $_.DeviceID -like "USB\VID_1199&PID_907*" -or $_.DeviceID -like "USB\VID_413C&PID_81B6*"}).DriverVersion
    $MbnName = $Mbn | Select-String "    Name               :" | ForEach-Object {$_ -replace "    Name               : ", ""}
    $MbnModel = $Mbn | Select-String "Model" | ForEach-Object {$_ -replace "    Model              : ", ""}
    $MbnID = $Mbn | Select-String "Device Id" | ForEach-Object {$_ -replace "    Device Id          : ", ""}
    $MbnFirmware = $Mbn | Select-String "Firmware" | ForEach-Object {$_ -replace "    Firmware Version   : ", ""}
    $MbnSIMPhone = .\netsh Mbn show readyinfo interface=$MbnName
    $MbnSIM = $MbnSIMPhone | Select-String "SIM ICC Id" | ForEach-Object {$_ -replace "    SIM ICC Id       : ", ""}
    $MbnPhone = $MbnSIMPhone | Select-String "        Telephone #1             : " | ForEach-Object {$_ -replace "        Telephone #1             : ", ""}

    Add-Data "GCD-LogTime" "$Time"
    Add-Data "GCD-WWANModel" "$MbnModel"
    Add-Data "GCD-WWANDriver" "$MbnDriverVer"
    Add-Data "GCD-WWANFirmware" "$MbnFirmware"
    Add-Data "GCD-WWANID" "$MbnID"
    Add-Data "GCD-WWANPhone" "$MbnPhone"
    Add-Data "GCD-WWANSIM" "$MbnSIM"

}

switch ($inventory) {
    "delta" {
        LogWrite "- INFO: Delta SCCM Inventory parameter used - forcing Delta HW inventory"
        Start-SCCMInv "delta"
    }

    "full" {
        LogWrite "- INFO: Full SCCM Inventory parameter used - forcing full HW inventory"
        Start-SCCMInv "full"
    }

    default {
        LogWrite "- INFO: SCCM Inventory parameter not used - skipping forced HW inventory"
    }
}

LogWrite "- INFO: Script complete"
