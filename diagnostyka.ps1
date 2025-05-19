# Script diagnostyczny do sprawdzenia konfiguracji srodowiska

# Kolory dla wyjscia
$GREEN = "`e[0;32m"
$BLUE = "`e[0;34m"
$YELLOW = "`e[1;33m"
$RED = "`e[0;31m"
$NC = "`e[0m" # No Color

# Uzycie zmiennej YELLOW aby uniknac ostrzezenia o nieuzywanych zmiennych
# $YELLOW jest uzywany w komunikatach ostrzezen

# Funkcja do wyswietlania statusu
function Show-Status {
    param (
        [string]$component,
        [bool]$status,
        [string]$message = ""
    )
    
    if ($status) {
        Write-Host "${GREEN}[OK]${NC} $component"
    } else {
        Write-Host "${RED}[BLAD]${NC} $component $message"
    }
}

# Naglowek
Write-Host "${BLUE}=== Diagnostyka srodowiska Email-LLM Integration ===${NC}"
Write-Host "Data uruchomienia: $(Get-Date)"
Write-Host ""

# Sprawdzenie Docker CLI
Write-Host "${BLUE}[INFO]${NC} Sprawdzanie Docker CLI..."
$dockerCliAvailable = $null -ne (Get-Command "docker" -ErrorAction SilentlyContinue)
Show-Status -component "Docker CLI" -status $dockerCliAvailable -message "Docker CLI nie jest zainstalowane lub nie jest dostepne w PATH"

# Sprawdzenie Docker Daemon
Write-Host "${BLUE}[INFO]${NC} Sprawdzanie Docker Daemon..."
$dockerDaemonRunning = $false
try {
    docker info > $null 2>&1
    $dockerDaemonRunning = ($LASTEXITCODE -eq 0)
} catch {
    $dockerDaemonRunning = $false
}
Show-Status -component "Docker Daemon" -status $dockerDaemonRunning -message "Docker Daemon nie jest uruchomiony"

# Sprawdzenie Docker Compose
Write-Host "${BLUE}[INFO]${NC} Sprawdzanie Docker Compose..."
$dockerComposeAvailable = $false
try {
    docker compose version > $null 2>&1
    $dockerComposeAvailable = ($LASTEXITCODE -eq 0)
} catch {
    $dockerComposeAvailable = $false
}
Show-Status -component "Docker Compose" -status $dockerComposeAvailable -message "Docker Compose nie jest dostepny"

# Sprawdzenie wymaganych katalogow
Write-Host "${BLUE}[INFO]${NC} Sprawdzanie wymaganych katalogow..."
$requiredDirs = @("./data", "./logs", "./gradle-cache", "./ollama_models", "./camel-groovy")
foreach ($dir in $requiredDirs) {
    $dirExists = Test-Path $dir
    Show-Status -component "Katalog $dir" -status $dirExists -message "Katalog nie istnieje"
}

# Sprawdzenie pliku .env
Write-Host "${BLUE}[INFO]${NC} Sprawdzanie pliku .env..."
$envFileExists = Test-Path ".env"
Show-Status -component "Plik .env" -status $envFileExists -message "Plik .env nie istnieje"

# Jesli plik .env istnieje, sprawdz wymagane zmienne
if ($envFileExists) {
    Write-Host "${BLUE}[INFO]${NC} Sprawdzanie zmiennych w pliku .env..."
    $envContent = Get-Content -Path ".env" -Raw
    
    $requiredVars = @(
        "OLLAMA_EXTERNAL_PORT",
        "OLLAMA_MODELS_DIR",
        "MAILHOG_SMTP_PORT",
        "MAILHOG_UI_PORT",
        "SERVER_PORT",
        "SQLITE_DB_PATH",
        "ADMINER_PORT"
    )
    
    foreach ($var in $requiredVars) {
        $varExists = $envContent -match "$var=.*"
        Show-Status -component "Zmienna $var" -status $varExists -message "Zmienna nie jest zdefiniowana w pliku .env"
    }
}

# Sprawdzenie dostepnosci portow
Write-Host "${BLUE}[INFO]${NC} Sprawdzanie dostepnosci portow..."

# Odczytaj porty z pliku .env lub uzyj domyslnych wartosci
$ports = @{
    "OLLAMA_EXTERNAL_PORT" = 11435
    "MAILHOG_SMTP_PORT" = 1026
    "MAILHOG_UI_PORT" = 8026
    "SERVER_PORT" = 8083
    "ADMINER_PORT" = 8081
}

if ($envFileExists) {
    foreach ($key in $ports.Keys) {
        if ($envContent -match "$key=([0-9]+)") {
            $ports[$key] = [int]$matches[1]
        }
    }
}

# Sprawdz, czy porty sa uzywane
foreach ($entry in $ports.GetEnumerator()) {
    $portInUse = $false
    try {
        $tcpConnection = New-Object System.Net.Sockets.TcpClient
        $portInUse = $tcpConnection.ConnectAsync("localhost", $entry.Value).Wait(100)
        $tcpConnection.Close()
    } catch {}
    
    Show-Status -component "Port $($entry.Key) ($($entry.Value))" -status (-not $portInUse) -message "Port jest juz uzywany przez inna aplikacje"
}

# Sprawdzenie pliku docker-compose.yml
Write-Host "${BLUE}[INFO]${NC} Sprawdzanie pliku docker-compose.yml..."
$composeFileExists = Test-Path "docker-compose.yml"
Show-Status -component "Plik docker-compose.yml" -status $composeFileExists -message "Plik docker-compose.yml nie istnieje"

# Sprawdzenie struktury projektu Camel Groovy
Write-Host "${BLUE}[INFO]${NC} Sprawdzanie struktury projektu Camel Groovy..."
$camelGroovyFiles = @(
    "./camel-groovy/Dockerfile",
    "./camel-groovy/build.gradle"
)

foreach ($file in $camelGroovyFiles) {
    $fileExists = Test-Path $file
    Show-Status -component "Plik $file" -status $fileExists -message "Plik nie istnieje"
}

# Sprawdzenie obrazow Docker
Write-Host "${BLUE}[INFO]${NC} Sprawdzanie obrazow Docker..."
$requiredImages = @("ollama/ollama", "mailhog/mailhog", "adminer")

foreach ($image in $requiredImages) {
    $imageExists = $false
    try {
        $imageInfo = docker images --format "{{.Repository}}" | Select-String -Pattern $image
        $imageExists = ($null -ne $imageInfo)
    } catch {}
    
    Show-Status -component "Obraz Docker $image" -status $imageExists -message "Obraz nie jest dostępny lokalnie"
}

# Sprawdzenie kontenerow
Write-Host "${BLUE}[INFO]${NC} Sprawdzanie kontenerow Docker..."
$requiredContainers = @("ollama", "mailserver", "camel-groovy", "adminer")

foreach ($container in $requiredContainers) {
    $containerExists = $false
    try {
        $containerInfo = docker ps -a --format "{{.Names}}" | Select-String -Pattern $container
        $containerExists = ($null -ne $containerInfo)
    } catch {}
    
    Show-Status -component "Kontener $container" -status $containerExists -message "Kontener nie istnieje"
}

# Podsumowanie
Write-Host ""
Write-Host "${BLUE}=== Podsumowanie diagnostyki ===${NC}"
Write-Host "Jesli wszystkie komponenty maja status [OK], srodowisko jest poprawnie skonfigurowane."
Write-Host "W przypadku bledow, sprawdz komunikaty i podejmij odpowiednie dzialania naprawcze."
Write-Host ""
Write-Host "${BLUE}[INFO]${NC} Aby uruchomic aplikacje, uzyj skryptu .\start.ps1"
Write-Host "${BLUE}[INFO]${NC} Aby zatrzymac aplikacje, uzyj skryptu .\stop.ps1"
