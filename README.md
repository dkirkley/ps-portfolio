# ps-portfolio
Collection of PowerShell scripts primarily focused on endpoint management and automation.

## Gather-CellData
This PowerShell script populates environment variables with mobile broadband information. If the device has a mobile broadband modem, mobile broadband information (SIM, phone, ID, signal, model, firmware) is collected and stored in environment variables. These variables are then collected via SCCM (or other means). 
The '-logging' parameter may be used to enable logging. The '-inventory' parameter may be used to force a Delta or Full SCCM hardware inventory.
