# PowerShell script to start the Email-LLM Integration project

# Colors for output
$GREEN = "`e[0;32m"
$BLUE = "`e[0;34m"
$YELLOW = "`e[1;33m"
$RED = "`e[0;31m"
$NC = "`e[0m" # No Color

Write-Host "${BLUE}[INFO]${NC} Starting Email-LLM Integration system..."

# Check if Docker is running
try {
    docker info 2>&1 | Out-Null
    if ($LASTEXITCODE -ne 0) { throw "Docker command failed" }
} catch {
    Write-Host "${RED}[ERROR]${NC} Docker is not running. Please start Docker and try again."
    exit 1
}

# Check port availability
if (Test-Path "./check-ports.ps1") {
    Write-Host "${BLUE}[INFO]${NC} Checking port availability..."
    & ./check-ports.ps1
} else {
    Write-Host "${YELLOW}[WARNING]${NC} Port checker script not found. Skipping port check."
}

# Create necessary directories
Write-Host "${BLUE}[INFO]${NC} Creating necessary directories..."
New-Item -ItemType Directory -Force -Path "./data", "./logs", "./gradle-cache"

# Create ollama_models directory only if it doesn't exist
if (-not (Test-Path "./ollama_models")) {
    New-Item -ItemType Directory -Force -Path "./ollama_models"
}

# Set permissions for directories
$directories = @("./data", "./logs", "./gradle-cache")
foreach ($dir in $directories) {
    if (Test-Path $dir) {
        $acl = Get-Acl $dir
        $rule = New-Object System.Security.AccessControl.FileSystemAccessRule("Everyone", "FullControl", "Allow")
        $acl.SetAccessRule($rule)
        Set-Acl $dir $acl
    }
}

# Check for existing containers
Write-Host "${BLUE}[INFO]${NC} Checking for existing containers..."
$existingContainers = docker ps -a | Select-String -Pattern "mailserver|ollama|camel-groovy|adminer" | ForEach-Object { $_.Matches.Value }
if ($existingContainers) {
    Write-Host "${YELLOW}[WARNING]${NC} Found existing containers that may conflict."
    Write-Host "${BLUE}[INFO]${NC} Stopping existing containers..."
    foreach ($container in $existingContainers) {
        docker stop $container
        docker rm $container
    }
}

# Start containers
Write-Host "${BLUE}[INFO]${NC} Starting containers..."
docker-compose up -d

# Get port values from .env with defaults
$mailhogPort = "8026"
$adminerPort = "8081"

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
}

Write-Host "${GREEN}[SUCCESS]${NC} System started successfully!"
Write-Host "${BLUE}[INFO]${NC} Services are available at:"
Write-Host "${BLUE}[INFO]${NC} Mailhog UI: http://localhost:$mailhogPort"
Write-Host "${BLUE}[INFO]${NC} Adminer: http://localhost:$adminerPort"
