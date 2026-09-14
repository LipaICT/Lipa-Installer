<#
.SYNOPSIS
    Installs a list of packages using a fallback chain of installation methods.

.DESCRIPTION
    This script installs a list of packages from a given array. For each package, it attempts to install using winget,
    then falls back to chocolatey, and finally to a direct download if the previous methods fail.
    It logs successful and failed installations to separate files and shows installation progress.

.NOTES
    Adapted for Lenovo device installs:
      - HP-specific packages (HP Programmable Key, HP Support Assistant, HP Image Assistant) replaced
        with Lenovo equivalents (Lenovo Vantage, Lenovo Commercial Vantage, Lenovo System Update).
      - Winget is now invoked via its resolved absolute path instead of relying on the "winget" alias,
        since the winget App Execution Alias is a per-user reparse point and is not reliably resolvable
        when running as SYSTEM (e.g. via RMM/Intune/scheduled task deployments).
#>

# --- Resolve absolute path to winget.exe -----------------------------------
function Get-WingetPath {
    # Preferred: resolve via the installed Desktop App Installer package (works in SYSTEM context)
    try {
        $wingetPackage = Get-AppxPackage -Name "Microsoft.DesktopAppInstaller" -ErrorAction SilentlyContinue |
            Sort-Object -Property Version -Descending | Select-Object -First 1

        if ($wingetPackage) {
            $candidate = Join-Path -Path $wingetPackage.InstallLocation -ChildPath "winget.exe"
            if (Test-Path -Path $candidate) {
                return $candidate
            }
        }
    }
    catch {
        Write-Warning "Could not resolve winget via Get-AppxPackage: $_"
    }

    # Fallback 1: search the standard WindowsApps package folder (covers per-machine installs)
    try {
        $candidate = Get-ChildItem -Path "C:\Program Files\WindowsApps" -Filter "winget.exe" -Recurse -ErrorAction SilentlyContinue |
            Where-Object { $_.Directory.Name -like "Microsoft.DesktopAppInstaller_*" } |
            Sort-Object -Property FullName -Descending | Select-Object -First 1 -ExpandProperty FullName
        if ($candidate) {
            return $candidate
        }
    }
    catch {
        Write-Warning "Could not resolve winget via WindowsApps search: $_"
    }

    # Fallback 2: current user's App Execution Alias (works when run in user context)
    $userAlias = Join-Path -Path $env:LOCALAPPDATA -ChildPath "Microsoft\WindowsApps\winget.exe"
    if (Test-Path -Path $userAlias) {
        return $userAlias
    }

    # Fallback 3: whatever is on PATH
    $onPath = Get-Command winget -ErrorAction SilentlyContinue
    if ($onPath) {
        return $onPath.Source
    }

    return $null
}

$WingetExe = Get-WingetPath

if (-not $WingetExe) {
    Write-Warning "Could not resolve an absolute path to winget.exe. Winget installs will be skipped; chocolatey/download fallbacks will still run."
}
else {
    Write-Host "Using winget at: $WingetExe" -ForegroundColor DarkGray
}

# Packages to install
$Packages = @(
    @{ Name = "Splashtop"; OpenUrl = "https://my.splashtop.eu/sos/packages/download/XW2PS2PZ5KSKEU" },
    @{ Name = "Rustdesk"; WingetId = "RustDesk.RustDesk"; ChocolateyId = "rustdesk" },
    @{ Name = "Firefox"; WingetId = "Mozilla.Firefox"; ChocolateyId = "firefox" },
    @{ Name = "Google Chrome"; WingetId = "Google.Chrome"; ChocolateyId = "googlechrome" },
    @{ Name = "Adobe Acrobat Reader"; WingetId = "Adobe.Acrobat.Reader.64-bit"; ChocolateyId = "adobereader" },
    @{ Name = "Foxit PDF Reader"; WingetId = "Foxit.FoxitReader"; ChocolateyId = "foxitreader" },
    @{ Name = "Belgian EID middleware"; WingetId = "BelgianGovernment.eIDmiddleware"; ChocolateyId = "eid-belgium" },
    @{ Name = "Belgian EID viewer"; WingetId = "BelgianGovernment.eIDViewer"; ChocolateyId = "eid-belgium-viewer" },
    @{ Name = "OpenVPN Connect"; WingetId = "OpenVPNTechnologies.OpenVPNConnect"; ChocolateyId = "openvpn-connect" },
    @{ Name = "VLC Media player"; WingetId = ""; ChocolateyId = "vlc" },
    @{ Name = "Lenovo Vantage"; WingetId = "9WZDNCRFJ4MV"; Source = "msstore" },
    @{ Name = "Lenovo Commercial Vantage"; WingetId = "9NR5B8GVVM13"; Source = "msstore" },
    @{ Name = "Lenovo System Update"; WingetId = "Lenovo.SystemUpdate" },
    @{ Name = "MS Office 365 Apps"; WingetId = "Microsoft.Office"; ChocolateyId = "office365business" }
)

# Log files
$SuccessLog = "C:\temp\successful_installations.log"
$FailureLog = "C:\temp\failed_installations.log"

# Ensure log directory exists
$LogDir = Split-Path -Path $SuccessLog -Parent
if (-not (Test-Path -Path $LogDir)) {
    New-Item -ItemType Directory -Path $LogDir -Force | Out-Null
}

# Clear previous logs
if (Test-Path $SuccessLog) { Clear-Content $SuccessLog }
if (Test-Path $FailureLog) { Clear-Content $FailureLog }

function Write-Progress-Message {
    param (
        [string]$Message,
        [string]$Color = "Cyan"
    )
    Write-Host "`n$Message" -ForegroundColor $Color
    Write-Host ("=" * 80) -ForegroundColor DarkGray
}

function Test-PackageInstalled {
    param (
        [string]$PackageName,
        [string]$WingetId,
        [string]$ChocolateyId
    )

    # Check winget
    if ($WingetId -and $WingetExe) {
        Write-Host "Checking if $PackageName is installed via winget..." -ForegroundColor Gray

        try {
            # Use Start-Job with timeout to prevent hanging
            $job = Start-Job -ScriptBlock {
                param($exe, $id)
                & $exe list --id $id 2>&1 | Out-String
            } -ArgumentList $WingetExe, $WingetId

            # Wait up to 10 seconds
            $completed = Wait-Job -Job $job -Timeout 10

            if ($completed) {
                $wingetCheckString = Receive-Job -Job $job
                Remove-Job -Job $job -Force

                # Check if package is in the list
                if ($wingetCheckString -match [regex]::Escape($WingetId)) {
                    Write-Host "✓ $PackageName is already installed (winget)" -ForegroundColor Green
                    return $true
                }
            }
            else {
                # Timeout occurred
                Write-Warning "Winget check timed out for $PackageName, assuming not installed"
                Remove-Job -Job $job -Force
            }
        }
        catch {
            Write-Warning "Error checking winget for $PackageName : $_"
        }
    }

    # Check chocolatey
    if ($ChocolateyId) {
        if (Get-Command choco -ErrorAction SilentlyContinue) {
            Write-Host "Checking if $PackageName is installed via chocolatey..." -ForegroundColor Gray
            try {
                $chocoList = choco list --local-only --exact $ChocolateyId 2>&1
                if ($LASTEXITCODE -eq 0 -and $chocoList -match $ChocolateyId) {
                    Write-Host "✓ $PackageName is already installed (chocolatey)" -ForegroundColor Green
                    return $true
                }
            }
            catch {
                Write-Warning "Error checking chocolatey for $PackageName : $_"
            }
        }
    }

    return $false
}

function Install-WithWinget {
    param (
        [string]$PackageName,
        [string]$PackageId,
        [string]$Source = "winget"
    )

    if (-not $WingetExe) {
        throw "Winget executable could not be resolved"
    }

    Write-Host "→ Installing $PackageName using winget ($WingetExe)..." -ForegroundColor Yellow

    & $WingetExe install -e --id $PackageId --accept-source-agreements --accept-package-agreements --source $Source

    $exitCode = $LASTEXITCODE

    if ($exitCode -eq 0 -or $exitCode -eq -1978335189) {
        Write-Host "✓ Successfully installed $PackageName using winget" -ForegroundColor Green
        return $true
    }
    else {
        throw "Winget install failed with exit code $exitCode"
    }
}

function Install-WithChocolatey {
    param (
        [string]$PackageName,
        [string]$PackageId
    )

    Write-Host "→ Installing $PackageName using chocolatey..." -ForegroundColor Yellow

    choco install $PackageId -y

    if ($LASTEXITCODE -eq 0) {
        Write-Host "✓ Successfully installed $PackageName using chocolatey" -ForegroundColor Green
        return $true
    }
    else {
        Write-Warning "✗ Chocolatey install failed with exit code $LASTEXITCODE"
        return $false
    }
}


function Install-Chocolatey {
    if (Get-Command choco -ErrorAction SilentlyContinue) {
        Write-Host "Chocolatey is already installed." -ForegroundColor Gray
        return
    }

    Write-Progress-Message "Installing Chocolatey package manager..." "Magenta"
    try {
        Set-ExecutionPolicy Bypass -Scope Process -Force
        [System.Net.ServicePointManager]::SecurityProtocol = [System.Net.ServicePointManager]::SecurityProtocol -bor 3072
        Invoke-Expression ((New-Object System.Net.WebClient).DownloadString('https://community.chocolatey.org/install.ps1')) | Out-Null

        # Refresh environment variables
        $env:Path = [System.Environment]::GetEnvironmentVariable("Path", "Machine") + ";" + [System.Environment]::GetEnvironmentVariable("Path", "User")

        Write-Host "✓ Chocolatey installation completed" -ForegroundColor Green
    }
    catch {
        throw "Failed to install Chocolatey: $_"
    }
}

# Main installation logic
Write-Progress-Message "Starting Package Installation Process" "Cyan"
Write-Host "Total packages to process: $($Packages.Count)`n" -ForegroundColor White

Install-Chocolatey

$counter = 0
foreach ($package in $Packages) {
    $counter++
    $name = $package.Name

    Write-Progress-Message "[$counter/$($Packages.Count)] Processing: $name" "Cyan"

    # Check if already installed
    if (Test-PackageInstalled -PackageName $name -WingetId $package.WingetId -ChocolateyId $package.ChocolateyId) {
        "Already installed: $name" | Out-File -FilePath $SuccessLog -Append
        continue
    }

    $installed = $false
    $installMethod = ""

    # Try Winget first (only if WingetId exists and winget was resolved)
    if ($package.WingetId -and $WingetExe) {
        try {
            $source = if ($package.Source) { $package.Source } else { "winget" }
            if (Install-WithWinget -PackageName $name -PackageId $package.WingetId -Source $source) {
                $installMethod = "winget"
                $installed = $true
            }
        }
        catch {
            Write-Host "Winget installation failed, trying fallback methods..." -ForegroundColor Yellow
        }
    }

    # Fallback to Chocolatey (if Winget failed or not available)
    if (-not $installed -and $package.ChocolateyId) {
        if (Install-WithChocolatey -PackageName $name -PackageId $package.ChocolateyId) {
            $installMethod = "chocolatey"
            $installed = $true
        }
        else {
            Write-Host "Chocolatey installation failed, trying fallback methods..." -ForegroundColor Yellow
        }
    }



    # Open URL in browser (for packages that need manual download)
    if (-not $installed -and $package.OpenUrl) {
        Write-Host "→ Opening download page for $name in browser..." -ForegroundColor Cyan
        Start-Process $package.OpenUrl
        $installed = $true
    }

    # Log results
    if ($installed) {
        $logMessage = "Successfully installed $name using $installMethod"
        $logMessage | Out-File -FilePath $SuccessLog -Append
    }
    else {
        $logMessage = "Failed to install $name using all available methods"
        $logMessage | Out-File -FilePath $FailureLog -Append
        Write-Host "✗ $logMessage" -ForegroundColor Red
    }
}

# Summary
Write-Progress-Message "Installation Process Complete" "Green"
Write-Host "`nResults:"
if (Test-Path $SuccessLog) {
    $successCount = (Get-Content $SuccessLog).Count
    Write-Host "  ✓ Successful installations: $successCount" -ForegroundColor Green
    Write-Host "    Log: $SuccessLog" -ForegroundColor Gray
}
if (Test-Path $FailureLog) {
    $failureCount = (Get-Content $FailureLog).Count
    if ($failureCount -gt 0) {
        Write-Host "  ✗ Failed installations: $failureCount" -ForegroundColor Red
        Write-Host "    Log: $FailureLog" -ForegroundColor Gray
    }
}
