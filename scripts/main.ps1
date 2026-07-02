# main.ps1

# Function to display ASCII art
function Show-AsciiArt {
    Write-Host @"
 ___       ___  ________  ________     
|\  \     |\  \|\   __  \|\   __  \    
\ \  \    \ \  \ \  \|\  \ \  \|\  \   
 \ \  \    \ \  \ \   ____\ \   __  \  
  \ \  \____\ \  \ \  \___|\ \  \ \  \ 
   \ \_______\ \__\ \__\    \ \__\ \__\
    \|_______|\|__|\|__|     \|__|\|__| 
                                       
                                       
                                       
"@ -ForegroundColor Green
}

# Function to display the menu
function Show-Menu {
    Write-Host "`nSelect a script to run:" -ForegroundColor Yellow
    Write-Host "1. Package Installation Script"
    Write-Host "2. Endpoint Configuration Script"
    Write-Host "3. Autotask Ticket Entry Generation Script"
    Write-Host "4. Move and rename splashtop"
    Write-Host "5. Update windows"
    Write-Host "6. Generate Spec Sheet"
    Write-Host "7. Add device to AD domain"    
    Write-Host "Enter your choice (1-7): " -NoNewline
}

# Main loop
while ($true) {
    Show-AsciiArt
    Show-Menu

    $choice = Read-Host

    switch ($choice) {
        "1" {
            Write-Host "Running Package Installation Script..." -ForegroundColor Cyan
            Invoke-Restmethod "https://raw.githubusercontent.com/LipaICT/Lipa-Installer/refs/heads/main/scripts/package-installation.ps1" | Invoke-Expression
            Read-Host "Press Enter to continue..."
        }
        "2" {
            Write-Host "Running Endpoint Configuration Script..." -ForegroundColor Cyan
            Invoke-Restmethod "https://raw.githubusercontent.com/LipaICT/Lipa-Installer/refs/heads/main/scripts/endpoint-configuration.ps1" | Invoke-Expression
            Read-Host "Press Enter to continue..."
        }
        "3" {
            Write-Host "Running Autotask Ticket Entry Generation Script..." -ForegroundColor Cyan
            Invoke-Restmethod "https://raw.githubusercontent.com/LipaICT/Lipa-Installer/refs/heads/main/scripts/generate-ticket.ps1" | Invoke-Expression
            Read-Host "Press Enter to continue..."
        }
         "4" {
            Write-Host "Running move and rename splashtop..." -ForegroundColor Cyan
            Invoke-Restmethod "https://raw.githubusercontent.com/LipaICT/Lipa-Installer/refs/heads/main/scripts/rename-and-move-splashtop.ps1" | Invoke-Expression
            Read-Host "Press Enter to continue..."
        }
         "5" {
            Write-Host "Running windows updates..." -ForegroundColor Cyan
            Invoke-Restmethod "https://raw.githubusercontent.com/LipaICT/Lipa-Installer/refs/heads/main/scripts/windows-update.ps1" | Invoke-Expression
            Read-Host "Press Enter to continue..."
        }
        "6" {
            Write-Host "Generating spec sheet..." -ForegroundColor Cyan
            Invoke-Restmethod "https://raw.githubusercontent.com/LipaICT/scripts/refs/heads/main/device_info.ps1" | Invoke-Expression
            Read-Host "Press Enter to continue..."
        }
        "7" {
            Write-Host "Adding device to AD domain..." -ForegroundColor Cyan
            Invoke-Restmethod "https://raw.githubusercontent.com/LipaICT/Lipa-Installer/refs/heads/main/scripts/domain-add.ps1" | Invoke-Expression
            Read-Host "Press Enter to continue..."
        }
        default {
            Write-Host "Invalid choice. Please enter a number between 1 and 4." -ForegroundColor Red
            Read-Host "Press Enter to continue..."
        }
    }
    Clear-Host
}
