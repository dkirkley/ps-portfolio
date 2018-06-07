<#

.DESCRIPTION
Script to name a machine during the OSD imaging process based on chassis type, build date, and serial number.
Also sets the isLaptop TS envar and OSDDiskCount/Index for determining which drive to image on devices with
multiple hard drives.

.EXAMPLE
powershell.exe -file Set-ComputerName.ps1

.NOTES
Chassis type list:
https://blogs.technet.microsoft.com/brandonlinton/2017/09/15/updated-win32_systemenclosure-chassis-types/

In Windows 10 Win32_ComputerSystem - ChassisSKUNumber might be easier to use. Needs to be tested.

#>

$ChassisType = (Get-CimInstance -ClassName Win32_SystemEnclosure | Select-Object ChassisTypes).ChassisTypes[0]
$SerialNumber = (Get-CimInstance -ClassName Win32_BIOS | Select-Object SerialNumber).SerialNumber
$Manufacturer = (Get-CimInstance -ClassName Win32_ComputerSystem | Select-Object).Manufacturer
$Model = (Get-CimInstance -ClassName Win32_ComputerSystem | Select-Object).Model
$Desktop = "2", "3", "4", "5", "6", "7", "13", "15", "16", "24", "35", "36"
$Laptop = "1", "8", "9", "10", "12", "14", "31", "32"
$Tablet = "30"
$InstallDate = Get-Date -UFormat "%y%m" # year/month device was built
$diskCount = (Get-PhysicalDisk).Count
$TSEnv = New-Object -COMObject Microsoft.SMS.TSEnvironment 

if ($SerialNumber.Length -gt 8) {
    $SerialNumber = $SerialNumber.SubString(($SerialNumber.Length) - 8) #Shorten serial for certain manufacturers
}

#Desktop
if ($Desktop -contains $ChassisType) {
    $TSEnv.Value("OSDComputerName") = "D-$InstallDate-$SerialNumber"
    $TSEnv.Value("isLaptop") = "false"
}
#Laptop
elseif ($Laptop -contains $ChassisType) {
    $TSEnv.Value("OSDComputerName") = "L-$InstallDate-$SerialNumber"
    $TSEnv.Value("isLaptop") = "true"
}
#Virtual
elseif ($Model -like "*virtual*") {
    $TSEnv.Value("OSDComputerName") = "V-$InstallDate-$SerialNumber"
    $TSEnv.Value("isLaptop") = "false"
}
#Tablet
elseif ($Tablet -contains $ChassisType) {
    $TSEnv.Value("OSDComputerName") = "T-$InstallDate-$SerialNumber"
    $TSEnv.Value("isLaptop") = "true"
}
#Field/rugged devices
elseif ($Manufacturer -like "*Panasonic*") {
    $TSEnv.Value("OSDComputerName") = "M-$InstallDate-$SerialNumber" 
    $TSEnv.Value("isLaptop") = "true"
}

if ($diskCount) {
    $SSDindex = Get-PhysicalDisk | Where-Object {$_.MediaType -eq 'SSD'} | Select-Object -ExpandProperty DeviceID
    $TSEnv.Value("OSDDiskCount") = $diskCount
    $TSEnv.Value("OSDDiskIndex") = $SSDindex
}
else {
    $TSEnv.Value("OSDDiskCount") = "1"
    $TSEnv.Value("OSDDiskIndex") = "0"
}