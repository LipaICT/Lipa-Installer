<#
.SYNOPSIS
    Generates a ticket with system information for a clean install.

.DESCRIPTION
    This script gathers system information, including device details, installed packages,
    and user credentials, and formats it into a ticket layout in Dutch.
#>

# Function to read info from the temp file
function Get-TicketInfoFromTempFile {
    $tempFile = "C:\temp\device_info.txt"
    if (Test-Path $tempFile) {
        $info = @{}
        Get-Content $tempFile | ForEach-Object {
            $key, $value = $_.Split('=', 2)
            $info[$key] = $value
        }
        return $info
    }
    return $null
}

# Get information
$ticketInfo = Get-TicketInfoFromTempFile
$deviceName = $ticketInfo["DEVICENAME"]
$clientAdminPassword = $ticketInfo["CLIENTADMIN_PASSWORD"]
$localUser = $ticketInfo["USER_USERNAME"]
$localUserPassword = $ticketInfo["USER_PASSWORD"]

$serialNumber = (Get-CimInstance Win32_BIOS).SerialNumber

# Format the output
$output = @"

Clean install Windows 11 en updates
User clientadmin aangemaakt en beveiligd
toestelnaam $deviceName
Installatie standaard programma's Edge Chromium, Google Chrome, Firefox, Adobe reader, Foxit Reader
HP Support Assistant en HPIA driver- en BIOS updates
e-ID software gedownload en kaartlezer getest
Camera en microfoon getest

-toestel in domein:
VPN connectie met server
toestel gekoppeld aan het domein
aangelogd als domeinuser x

-toestel zonder domein:
gebruiker $localuser aangemaakt met installatierechten

Trend Micro en Office installatie
Outlook instellen
Aanmelden in OneDrive

Apparaatnaam: $deviceName
Serienummer van het apparaat: $serialNumber

Lokale gebruiker clientadmin -> $clientAdminPassword
Lokale gebruiker $localUser -> $localUserPassword
"@

$output | Out-File -FilePath "$env:USERPROFILE\Desktop\autotask entry.txt"

