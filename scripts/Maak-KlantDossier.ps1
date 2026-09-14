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
    De OneDrive/SharePoint-syncmap heet niet bij iedereen hetzelfde (bv. met of zonder
    "OneDrive - " prefix). Daarom zoekt het script AUTOMATISCH naar de map "Klanten Dossiers"
    onder "Techdienst - Documenten" in het profiel van de ingelogde gebruiker.
    Werkt dit om een of andere reden niet, vul dan handmatig $BasePathOverride in.
#>

# ============================================================
# CONFIGURATIE
# ============================================================
# Laat leeg ("") om automatisch te zoeken. Vul enkel in als de automatische
# detectie niet werkt op een bepaalde pc (bv. afwijkende mapstructuur).
$BasePathOverride = ""

# Naam van de map die we zoeken, en het pad-fragment waaronder die moet staan
$TargetFolderName = "Klanten Dossiers"
$RequiredParentFragment = "Techdienst - Documenten"

# Standaard submappen die in elke klantmap moeten komen
$SubFolders = @("Clients", "Netwerk", "M365", "Security")

# ============================================================
# BASISPAD BEPALEN (automatisch of via override)
# ============================================================
if (-not [string]::IsNullOrWhiteSpace($BasePathOverride)) {
    $BasePath = $BasePathOverride
}
else {
    Write-Host "Bezig met zoeken naar '$TargetFolderName' onder '$RequiredParentFragment'..."

    $Gevonden = Get-ChildItem -Path $env:USERPROFILE -Directory -Recurse -Depth 4 -ErrorAction SilentlyContinue |
        Where-Object {
            $_.Name -ieq $TargetFolderName -and
            $_.FullName -imatch [Regex]::Escape($RequiredParentFragment)
        }

    if (-not $Gevonden) {
        Write-Host "Kon geen map '$TargetFolderName' vinden onder een map die '$RequiredParentFragment' bevat." -ForegroundColor Red
        Write-Host "Controleer of OneDrive/SharePoint correct gesynct is, of vul `$BasePathOverride handmatig in." -ForegroundColor Red
        Read-Host "Druk op Enter om af te sluiten"
        exit 1
    }

    if ($Gevonden.Count -gt 1) {
        Write-Host "Er zijn meerdere mogelijke locaties gevonden:" -ForegroundColor Yellow
        $Gevonden | ForEach-Object { Write-Host "  - $($_.FullName)" }
        Write-Host "De eerste wordt gebruikt. Vul `$BasePathOverride in indien dit niet de juiste is." -ForegroundColor Yellow
    }

    $BasePath = $Gevonden[0].FullName
}

Write-Host "Basispad: $BasePath" -ForegroundColor Cyan

# ============================================================
# CONTROLE: bestaat het basispad?
# ============================================================
if (-not (Test-Path -LiteralPath $BasePath)) {
    Write-Host "Het basispad '$BasePath' bestaat niet." -ForegroundColor Red
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
