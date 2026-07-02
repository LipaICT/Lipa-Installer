<#
.SYNOPSIS
    Joins this Windows computer to an Active Directory domain.

.DESCRIPTION
    Interactive script that prompts the user for the domain name, optional
    OU placement, and whether to restart the computer after joining.
    Compatible with Windows PowerShell 5.1.

.EXAMPLE
    .\Join-Domain.ps1

.NOTES
    - Must be run as Administrator.
    - Prompts for domain credentials (a user with rights to add computers).
#>

[CmdletBinding(SupportsShouldProcess = $true)]
param(
    [Parameter(Mandatory = $false, HelpMessage = "Path to log file")]
    [string]$LogPath = "$env:SystemDrive\Logs\DomainJoin.log"
)

function Write-Log {
    param(
        [string]$Message,
        [ValidateSet("INFO", "WARN", "ERROR")]
        [string]$Level = "INFO"
    )
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $line = "[$timestamp] [$Level] $Message"

    $logDir = Split-Path -Path $LogPath -Parent
    if (-not (Test-Path -Path $logDir)) {
        New-Item -Path $logDir -ItemType Directory -Force | Out-Null
    }
    Add-Content -Path $LogPath -Value $line

    switch ($Level) {
        "ERROR" { Write-Host $line -ForegroundColor Red }
        "WARN"  { Write-Host $line -ForegroundColor Yellow }
        default { Write-Host $line -ForegroundColor Green }
    }
}

function Read-YesNo {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Question
    )
    while ($true) {
        Write-Host ""
        Write-Host $Question
        Write-Host "  1) Yes"
        Write-Host "  2) No"
        $choice = Read-Host "Enter 1 or 2"
        if ($choice -eq "1") { return $true }
        if ($choice -eq "2") { return $false }
        Write-Host "Invalid input. Please enter 1 or 2." -ForegroundColor Yellow
    }
}

function Read-RequiredString {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Prompt
    )
    while ($true) {
        $value = Read-Host $Prompt
        if (-not [string]::IsNullOrWhiteSpace($value)) {
            return $value.Trim()
        }
        Write-Host "This field cannot be empty." -ForegroundColor Yellow
    }
}

# --- Check for Administrator rights ---
$currentPrincipal = New-Object Security.Principal.WindowsPrincipal(
    [Security.Principal.WindowsIdentity]::GetCurrent()
)
if (-not $currentPrincipal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Write-Log -Level ERROR -Message "This script must be run as Administrator. Aborting."
    exit 1
}

# --- Ask for the domain name ---
$DomainName = Read-RequiredString -Prompt "Enter the domain name to join (e.g. contoso.local)"

# --- Check if already joined ---
$cs = Get-WmiObject -Class Win32_ComputerSystem
if ($cs.PartOfDomain -and $cs.Domain -ieq $DomainName) {
    Write-Log -Message "This computer is already a member of the domain '$DomainName'. Nothing to do."
    exit 0
}
if ($cs.PartOfDomain -and $cs.Domain -ine $DomainName) {
    Write-Log -Level WARN -Message "Computer is currently joined to domain '$($cs.Domain)', not '$DomainName'."
}

# --- Ask whether to restart after joining ---
$restart = Read-YesNo -Question "Do you want to restart the computer automatically after joining?"

# --- Prompt for domain credentials ---
try {
    $Credential = Get-Credential -Message "Enter credentials with rights to join computers to '$DomainName' (e.g. DOMAIN\username)"
    if (-not $Credential) {
        Write-Log -Level ERROR -Message "No credentials provided. Aborting."
        exit 1
    }
}
catch {
    Write-Log -Level ERROR -Message "Error retrieving credentials: $_"
    exit 1
}

# --- Build parameters for Add-Computer ---
$addComputerParams = @{
    DomainName  = $DomainName
    Credential  = $Credential
    Force       = $true
    ErrorAction = "Stop"
}

if ($restart) {
    $addComputerParams["Restart"] = $true
}

# --- Perform the domain join ---
$targetDesc = "join computer '$env:COMPUTERNAME' to domain '$DomainName'"
if ($PSCmdlet.ShouldProcess($targetDesc, "Add-Computer")) {
    try {
        Write-Log -Message "Starting domain join: $targetDesc ..."
        Add-Computer @addComputerParams

        Write-Log -Message "Domain join succeeded."
        if ($restart) {
            Write-Log -Message "The computer will restart automatically to complete the join."
        }
        else {
            Write-Log -Level WARN -Message "A restart is required to complete the domain join. Restart manually with Restart-Computer."
        }
    }
    catch {
        Write-Log -Level ERROR -Message "Domain join failed: $($_.Exception.Message)"
        exit 1
    }
}
