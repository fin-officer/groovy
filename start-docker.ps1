# Script to start Docker Desktop and then run the application

# Colors for output
$GREEN = "`e[0;32m"
$BLUE = "`e[0;34m"
$YELLOW = "`e[1;33m"
$RED = "`e[0;31m"
$NC = "`e[0m" # No Color

Write-Host "${BLUE}[INFO]${NC} Attempting to start Docker..."

# Start Docker in a non-interactive way
Write-Host "${BLUE}[INFO]${NC} Starting Docker WSL distribution..."
try {
    # Start the docker-desktop WSL distribution in background
    Start-Process -FilePath "wsl" -ArgumentList "-d", "docker-desktop" -WindowStyle Hidden
    Write-Host "${GREEN}[SUCCESS]${NC} Docker WSL distribution started."
} catch {
    Write-Host "${YELLOW}[WARNING]${NC} Could not start Docker WSL distribution: $_"
}

# Wait for Docker to initialize
Write-Host "${BLUE}[INFO]${NC} Waiting for Docker to initialize..."
Start-Sleep -Seconds 10

# Try to run docker-compose directly
Write-Host "${BLUE}[INFO]${NC} Starting the application with docker compose..."

# Create necessary directories
Write-Host "${BLUE}[INFO]${NC} Creating necessary directories..."
New-Item -ItemType Directory -Force -Path "./data", "./logs", "./gradle-cache"

# Create ollama_models directory only if it doesn't exist
if (-not (Test-Path "./ollama_models")) {
    New-Item -ItemType Directory -Force -Path "./ollama_models"
}

# Run docker compose directly
Write-Host "${BLUE}[INFO]${NC} Starting containers with docker compose..."
docker compose up -d

# Get port values from .env with defaults
$mailhogPort = "8026"
$adminerPort = "8081"
$serverPort = "8083"

# Try to read ports from .env file if it exists
if (Test-Path ".env") {
    $envContent = Get-Content -Path ".env" -Raw
    
    # Extract MAILHOG_UI_PORT if it exists
    if ($envContent -match "MAILHOG_UI_PORT\s*=\s*([0-9]+)") {
        $mailhogPort = $matches[1]
    }
    
    # Extract ADMINER_PORT if it exists
    if ($envContent -match "ADMINER_PORT\s*=\s*([0-9]+)") {
        $adminerPort = $matches[1]
    }
    
    # Extract SERVER_PORT if it exists
    if ($envContent -match "SERVER_PORT\s*=\s*([0-9]+)") {
        $serverPort = $matches[1]
    }
}

Write-Host "${GREEN}[SUCCESS]${NC} System started successfully!"
Write-Host "${BLUE}[INFO]${NC} Services are available at:"
Write-Host "${BLUE}[INFO]${NC} API: http://localhost:$serverPort/api"
Write-Host "${BLUE}[INFO]${NC} API Documentation: http://localhost:$serverPort/api/api-doc"
Write-Host "${BLUE}[INFO]${NC} Test Email Panel: http://localhost:$mailhogPort"
Write-Host "${BLUE}[INFO]${NC} SQLite Admin Panel: http://localhost:$adminerPort"

Write-Host "
To check application logs: docker logs -f camel-groovy-email-llm"
Write-Host "To check Ollama logs: docker logs -f ollama"
Write-Host "To stop the system: .\stop.ps1"
