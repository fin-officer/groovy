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
