# Simple script to run the application with Docker

# Colors for output
$GREEN = "`e[0;32m"
$BLUE = "`e[0;34m"
$YELLOW = "`e[1;33m"
$RED = "`e[0;31m"
$NC = "`e[0m" # No Color

Write-Host "${BLUE}[INFO]${NC} Starting Email-LLM Integration system..."

# Create necessary directories
Write-Host "${BLUE}[INFO]${NC} Creating necessary directories..."
New-Item -ItemType Directory -Force -Path "./data", "./logs", "./gradle-cache"

# Create ollama_models directory only if it doesn't exist
if (-not (Test-Path "./ollama_models")) {
    New-Item -ItemType Directory -Force -Path "./ollama_models"
}

# Try to stop any existing containers first
Write-Host "${BLUE}[INFO]${NC} Stopping any existing containers..."
try {
    docker compose down --remove-orphans
} catch {
    Write-Host "${YELLOW}[WARNING]${NC} Could not stop containers: $_"
}

# Start the containers
Write-Host "${BLUE}[INFO]${NC} Starting containers..."
try {
    docker compose up -d
    
    if ($LASTEXITCODE -ne 0) {
        Write-Host "${RED}[ERROR]${NC} Failed to start containers. Make sure Docker is running properly."
        exit 1
    }
} catch {
    Write-Host "${RED}[ERROR]${NC} Error starting containers: $_"
    Write-Host "${YELLOW}[INFO]${NC} Make sure Docker Desktop is running and try again."
    exit 1
}

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

Write-Host ""
Write-Host "${YELLOW}[INFO]${NC} To check application logs: docker logs -f camel-groovy-email-llm"
Write-Host "${YELLOW}[INFO]${NC} To check Ollama logs: docker logs -f ollama"
Write-Host "${YELLOW}[INFO]${NC} To stop the system: docker compose down"
