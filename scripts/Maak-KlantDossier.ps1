<#
.SYNOPSIS
    Maakt een standaard mappenstructuur aan voor een nieuwe klant in het Klanten Dossiers archief.

.DESCRIPTION
    Vraagt de gebruiker om een klantnaam, controleert of er al een map met die naam
    bestaat binnen de "Klanten Dossiers" root (ongeacht submap), en maakt indien nodig
    de klantmap aan met de standaard substructuur:
        - Clients
        - Netwerk
        - M365
        - Security

.NOTES
    Pas de variabele $BasePath hieronder aan indien het pad naar "Klanten Dossiers" wijzigt.
#>

# ============================================================
# CONFIGURATIE - pas hier het basispad aan indien nodig
# ============================================================
$BasePath = "C:\Users\niels\OneDrive - Lipa NV\Techdienst - Documenten\Klanten Dossiers"

# Standaard submappen die in elke klantmap moeten komen
$SubFolders = @("Clients", "Netwerk", "M365", "Security")

# ============================================================
# CONTROLE: bestaat het basispad?
# ============================================================
if (-not (Test-Path -LiteralPath $BasePath)) {
    Write-Host "Het basispad '$BasePath' bestaat niet. Controleer de variabele `$BasePath in het script." -ForegroundColor Red
    Read-Host "Druk op Enter om af te sluiten"
    exit 1
}

# ============================================================
# VRAAG DE KLANTNAAM
# ============================================================
$KlantNaam = Read-Host "Geef de naam van de klant op"

if ([string]::IsNullOrWhiteSpace($KlantNaam)) {
    Write-Host "Geen klantnaam ingegeven. Script wordt afgebroken." -ForegroundColor Red
    Read-Host "Druk op Enter om af te sluiten"
    exit 1
}

# Verwijder tekens die niet toegelaten zijn in Windows mapnamen
$InvalidChars = [IO.Path]::GetInvalidFileNameChars() -join ''
$RegexInvalid = "[{0}]" -f [Regex]::Escape($InvalidChars)
$KlantNaamSchoon = ($KlantNaam -replace $RegexInvalid, '').Trim()

if ($KlantNaamSchoon -ne $KlantNaam) {
    Write-Host "Let op: ongeldige tekens zijn verwijderd uit de klantnaam." -ForegroundColor Yellow
    Write-Host "Gebruikte naam: '$KlantNaamSchoon'"
}

# ============================================================
# CONTROLEER OF DE KLANT AL BESTAAT (ergens in Klanten Dossiers)
# ============================================================
Write-Host "Bezig met controleren of '$KlantNaamSchoon' al bestaat in '$BasePath'..."

$BestaandeMap = Get-ChildItem -LiteralPath $BasePath -Directory -Recurse -ErrorAction SilentlyContinue |
    Where-Object { $_.Name -ieq $KlantNaamSchoon }

if ($BestaandeMap) {
    Write-Host "De klant '$KlantNaamSchoon' bestaat reeds op:" -ForegroundColor Yellow
    $BestaandeMap | ForEach-Object { Write-Host "  - $($_.FullName)" }
    Write-Host "Er wordt niets aangemaakt." -ForegroundColor Yellow
    Read-Host "Druk op Enter om af te sluiten"
    exit 0
}

# ============================================================
# KLANT BESTAAT NIET -> MAP AANMAKEN
# ============================================================
$NieuweKlantPad = Join-Path -Path $BasePath -ChildPath $KlantNaamSchoon

try {
    New-Item -Path $NieuweKlantPad -ItemType Directory -ErrorAction Stop | Out-Null
    Write-Host "Klantmap aangemaakt: $NieuweKlantPad" -ForegroundColor Green

    foreach ($Sub in $SubFolders) {
        $SubPad = Join-Path -Path $NieuweKlantPad -ChildPath $Sub
        New-Item -Path $SubPad -ItemType Directory -ErrorAction Stop | Out-Null
        Write-Host "  - Submap aangemaakt: $Sub" -ForegroundColor Green
    }

    Write-Host "`nKlantdossier voor '$KlantNaamSchoon' is volledig aangemaakt." -ForegroundColor Cyan
}
catch {
    Write-Host "Er ging iets mis bij het aanmaken van de mappen: $($_.Exception.Message)" -ForegroundColor Red
    Read-Host "Druk op Enter om af te sluiten"
    exit 1
}

Read-Host "Druk op Enter om af te sluiten"
