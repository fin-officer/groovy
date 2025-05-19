# Script to set up Docker Engine in WSL2

# Colors for output
$GREEN = "`e[0;32m"
$BLUE = "`e[0;34m"
$YELLOW = "`e[1;33m"
$RED = "`e[0;31m"
$NC = "`e[0m" # No Color

Write-Host "${BLUE}[INFO]${NC} Setting up Docker in WSL2..."

# Check if WSL is available
$wslAvailable = $null -ne (Get-Command "wsl" -ErrorAction SilentlyContinue)

if (-not $wslAvailable) {
    Write-Host "${RED}[ERROR]${NC} WSL is not available. Please install WSL first."
    Write-Host "${YELLOW}[INFO]${NC} Run 'wsl --install' in an elevated PowerShell prompt."
    exit 1
}

# Check if Ubuntu is installed
Write-Host "${BLUE}[INFO]${NC} Checking for Ubuntu WSL distribution..."
$wslList = wsl --list
$hasUbuntu = $wslList -match "Ubuntu"

if (-not $hasUbuntu) {
    Write-Host "${RED}[ERROR]${NC} Ubuntu WSL distribution not found."
    Write-Host "${YELLOW}[INFO]${NC} Please install Ubuntu from the Microsoft Store or run 'wsl --install -d Ubuntu' in an elevated PowerShell prompt."
    exit 1
}

Write-Host "${BLUE}[INFO]${NC} Found Ubuntu WSL distribution. Checking if Docker is installed..."

# Check if Docker is installed in Ubuntu
$dockerInstalled = wsl -d Ubuntu -- command -v docker > $null 2>&1
$dockerStatus = $LASTEXITCODE

if ($dockerStatus -ne 0) {
    Write-Host "${YELLOW}[WARNING]${NC} Docker not found in Ubuntu WSL. Installing Docker..."
    
    # Install Docker in Ubuntu
    Write-Host "${BLUE}[INFO]${NC} Running Docker installation commands in Ubuntu WSL..."
    
    # Create a temporary script to install Docker
    $tempScriptPath = "$env:TEMP\install-docker-wsl.sh"
    @"
#!/bin/bash
set -e

# Update package lists
sudo apt-get update

# Install prerequisites
sudo apt-get install -y apt-transport-https ca-certificates curl software-properties-common

# Add Docker's official GPG key
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo apt-key add -

# Add Docker repository
sudo add-apt-repository "deb [arch=amd64] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable"

# Update package lists again
sudo apt-get update

# Install Docker
sudo apt-get install -y docker-ce docker-ce-cli containerd.io

# Add current user to docker group
sudo usermod -aG docker $USER

# Start Docker service
sudo service docker start

echo "Docker installation completed!"
"@ | Out-File -FilePath $tempScriptPath -Encoding ASCII
    
    # Copy the script to WSL and execute it
    Get-Content $tempScriptPath | wsl -d Ubuntu -- bash -c "cat > /tmp/install-docker.sh && chmod +x /tmp/install-docker.sh && sudo /tmp/install-docker.sh"
    
    # Check if Docker was installed successfully
    $dockerInstalled = wsl -d Ubuntu -- command -v docker > $null 2>&1
    $dockerStatus = $LASTEXITCODE
    
    if ($dockerStatus -ne 0) {
        Write-Host "${RED}[ERROR]${NC} Failed to install Docker in Ubuntu WSL."
        exit 1
    }
    
    Write-Host "${GREEN}[SUCCESS]${NC} Docker installed successfully in Ubuntu WSL!"
} else {
    Write-Host "${GREEN}[SUCCESS]${NC} Docker is already installed in Ubuntu WSL."
}

# Start Docker service in WSL
Write-Host "${BLUE}[INFO]${NC} Starting Docker service in Ubuntu WSL..."
wsl -d Ubuntu -- sudo service docker start

# Check if Docker is running
Write-Host "${BLUE}[INFO]${NC} Checking if Docker is running..."
$dockerRunning = wsl -d Ubuntu -- docker info > $null 2>&1
$dockerStatus = $LASTEXITCODE

if ($dockerStatus -ne 0) {
    Write-Host "${RED}[ERROR]${NC} Docker service is not running in Ubuntu WSL."
    Write-Host "${YELLOW}[INFO]${NC} Please try starting it manually with: wsl -d Ubuntu -- sudo service docker start"
    exit 1
}

Write-Host "${GREEN}[SUCCESS]${NC} Docker is running in Ubuntu WSL!"

# Create a helper script to run Docker commands through WSL
Write-Host "${BLUE}[INFO]${NC} Creating helper script to run Docker commands..."

@"
# Script to run Docker commands through WSL

# Colors for output
`$GREEN = \"`e[0;32m\"\n`$BLUE = \"`e[0;34m\"\n`$YELLOW = \"`e[1;33m\"\n`$RED = \"`e[0;31m\"\n`$NC = \"`e[0m\" # No Color\n\nWrite-Host \"`${BLUE}[INFO]`${NC} Running Docker through WSL...\"\n\n# Get all arguments passed to this script\n`$dockerArgs = `$args -join \" \"\n\n# Run the Docker command through WSL\nwsl -d Ubuntu -- docker `$dockerArgs\n\n# Return the exit code from the Docker command\nexit `$LASTEXITCODE\n"@ | Out-File -FilePath "docker-wsl.ps1" -Encoding ASCII

# Create a helper script to run docker-compose commands through WSL
Write-Host "${BLUE}[INFO]${NC} Creating helper script to run docker-compose commands..."

@"
# Script to run docker-compose commands through WSL

# Colors for output
`$GREEN = \"`e[0;32m\"\n`$BLUE = \"`e[0;34m\"\n`$YELLOW = \"`e[1;33m\"\n`$RED = \"`e[0;31m\"\n`$NC = \"`e[0m\" # No Color\n\nWrite-Host \"`${BLUE}[INFO]`${NC} Running docker-compose through WSL...\"\n\n# Get all arguments passed to this script\n`$composeArgs = `$args -join \" \"\n\n# Convert Windows path to WSL path\n`$currentDir = (Get-Location).Path\n`$wslPath = wsl -d Ubuntu -- wslpath \"`$currentDir\"\n\n# Run the docker-compose command through WSL\nwsl -d Ubuntu -- cd \"`$wslPath\" \"&&\" docker-compose `$composeArgs\n\n# Return the exit code from the docker-compose command\nexit `$LASTEXITCODE\n"@ | Out-File -FilePath "docker-compose-wsl.ps1" -Encoding ASCII

# Create a script to run the application
Write-Host "${BLUE}[INFO]${NC} Creating script to run the application..."

@"
# Script to run the application with Docker through WSL

# Colors for output
`$GREEN = \"`e[0;32m\"\n`$BLUE = \"`e[0;34m\"\n`$YELLOW = \"`e[1;33m\"\n`$RED = \"`e[0;31m\"\n`$NC = \"`e[0m\" # No Color\n\nWrite-Host \"`${BLUE}[INFO]`${NC} Starting Email-LLM Integration system through WSL...\"\n\n# Create necessary directories\nWrite-Host \"`${BLUE}[INFO]`${NC} Creating necessary directories...\"\nNew-Item -ItemType Directory -Force -Path \"./data\", \"./logs\", \"./gradle-cache\"\n\n# Create ollama_models directory only if it doesn't exist\nif (-not (Test-Path \"./ollama_models\")) {\n    New-Item -ItemType Directory -Force -Path \"./ollama_models\"\n}\n\n# Stop any existing containers\nWrite-Host \"`${BLUE}[INFO]`${NC} Stopping any existing containers...\"\n.\\docker-compose-wsl.ps1 down --remove-orphans\n\n# Start the containers\nWrite-Host \"`${BLUE}[INFO]`${NC} Starting containers...\"\n.\\docker-compose-wsl.ps1 up -d\n\nif (`$LASTEXITCODE -ne 0) {\n    Write-Host \"`${RED}[ERROR]`${NC} Failed to start containers.\"\n    exit 1\n}\n\n# Get port values from .env with defaults\n`$mailhogPort = \"8026\"\n`$adminerPort = \"8081\"\n`$serverPort = \"8083\"\n\n# Try to read ports from .env file if it exists\nif (Test-Path \".env\") {\n    `$envContent = Get-Content -Path \".env\" -Raw\n    \n    # Extract MAILHOG_UI_PORT if it exists\n    if (`$envContent -match \"MAILHOG_UI_PORT\\s*=\\s*([0-9]+)\") {\n        `$mailhogPort = `$matches[1]\n    }\n    \n    # Extract ADMINER_PORT if it exists\n    if (`$envContent -match \"ADMINER_PORT\\s*=\\s*([0-9]+)\") {\n        `$adminerPort = `$matches[1]\n    }\n    \n    # Extract SERVER_PORT if it exists\n    if (`$envContent -match \"SERVER_PORT\\s*=\\s*([0-9]+)\") {\n        `$serverPort = `$matches[1]\n    }\n}\n\nWrite-Host \"`${GREEN}[SUCCESS]`${NC} System started successfully!\"\nWrite-Host \"`${BLUE}[INFO]`${NC} Services are available at:\"\nWrite-Host \"`${BLUE}[INFO]`${NC} API: http://localhost:`$serverPort/api\"\nWrite-Host \"`${BLUE}[INFO]`${NC} API Documentation: http://localhost:`$serverPort/api/api-doc\"\nWrite-Host \"`${BLUE}[INFO]`${NC} Test Email Panel: http://localhost:`$mailhogPort\"\nWrite-Host \"`${BLUE}[INFO]`${NC} SQLite Admin Panel: http://localhost:`$adminerPort\"\n\nWrite-Host \"\"\nWrite-Host \"`${YELLOW}[INFO]`${NC} To check application logs: .\\docker-wsl.ps1 logs -f camel-groovy-email-llm\"\nWrite-Host \"`${YELLOW}[INFO]`${NC} To check Ollama logs: .\\docker-wsl.ps1 logs -f ollama\"\nWrite-Host \"`${YELLOW}[INFO]`${NC} To stop the system: .\\docker-compose-wsl.ps1 down\"\n"@ | Out-File -FilePath "run-app-wsl.ps1" -Encoding ASCII

Write-Host "${GREEN}[SUCCESS]${NC} Setup completed!"
Write-Host "${BLUE}[INFO]${NC} You can now run the application with: .\run-app-wsl.ps1"
Write-Host "${YELLOW}[INFO]${NC} This will run Docker through WSL Ubuntu."
