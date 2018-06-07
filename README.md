# ps-portfolio
Collection of PowerShell scripts primarily focused on endpoint management and automation.

## Gather-CellData
This script populates environment variables with mobile broadband information. If the device has a mobile broadband modem, mobile broadband information (SIM, phone, ID, signal, model, firmware) is collected and stored in environment variables. These variables are then collected via SCCM (or other means). 
The '-logging' parameter may be used to enable logging. The '-inventory' parameter may be used to force a Delta or Full SCCM hardware inventory.

## Remove-Application
This script is used as a universal application uninstall script. It was originally written to be used
during the Windows 10 upgrade process to remove unwanted/incompatible applications. It will remove both win32 and appx applications.

## Set-ComputerName
This script names a machine during the OSD imaging process based on chassis type, build date, and serial number.
It also sets the isLaptop TS envar and OSDDiskCount/Index for determining which drive to image on devices with
multiple hard drives.
