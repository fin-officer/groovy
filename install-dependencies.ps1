# Install-Dependencies.ps1
# This script installs all required dependencies including Docker Desktop on Windows
# Run this script in an elevated (Administrator) PowerShell session

#Requires -RunAsAdministrator

# Console colors
$GREEN = "`e[32m"
$BLUE = "`e[34m"
$YELLOW = "`e[33m"
$RED = "`e[31m"
$NC = "`e[0m" # No Color

function Write-Info {
    param([string]$message)
    Write-Host "${BLUE}[INFO]${NC} $message"
}

function Write-Success {
    param([string]$message)
    Write-Host "${GREEN}[SUCCESS]${NC} $message"
}

function Write-Warning {
    param([string]$message)
    Write-Host "${YELLOW}[WARNING]${NC} $message"
}

function Write-Error {
    param([string]$message)
    Write-Host "${RED}[ERROR]${NC} $message"
    exit 1
}

function Test-CommandExists {
    param($command)
    return (Get-Command $command -ErrorAction SilentlyContinue) -ne $null
}

function Install-Chocolatey {
    if (-not (Test-CommandExists choco)) {
        Write-Info "Installing Chocolatey package manager..."
        Set-ExecutionPolicy Bypass -Scope Process -Force
        [System.Net.ServicePointManager]::SecurityProtocol = [System.Net.ServicePointManager]::SecurityProtocol -bor 3072
        iex ((New-Object System.Net.WebClient).DownloadString('https://chocolatey.org/install.ps1'))
        
        # Refresh environment variables
        $env:Path = [System.Environment]::GetEnvironmentVariable("Path","Machine") + ";" + [System.Environment]::GetEnvironmentVariable("Path","User")
        
        if (-not (Test-CommandExists choco)) {
            Write-Error "Failed to install Chocolatey. Please install it manually from https://chocolatey.org/"
        }
        Write-Success "Chocolatey installed successfully"
    } else {
        Write-Info "Chocolatey is already installed"
    }
}

function Install-DockerDesktop {
    if (-not (Test-Path "$env:ProgramFiles\Docker\Docker\Docker Desktop.exe")) {
        Write-Info "Downloading Docker Desktop..."
        $dockerInstaller = "$env:TEMP\DockerDesktopInstaller.exe"
        Invoke-WebRequest -Uri "https://desktop.docker.com/win/stable/Docker%20Desktop%20Installer.exe" -OutFile $dockerInstaller
        
        Write-Info "Installing Docker Desktop..."
        Start-Process -FilePath $dockerInstaller -ArgumentList "install --quiet" -Wait
        
        # Add Docker to PATH
        [System.Environment]::SetEnvironmentVariable("Path", $env:Path + ";C:\Program Files\Docker\Docker\resources\bin", [System.EnvironmentVariableTarget]::Machine)
        $env:Path = [System.Environment]::GetEnvironmentVariable("Path","Machine") + ";" + [System.Environment]::GetEnvironmentVariable("Path","User")
        
        Write-Success "Docker Desktop installed. Please complete the setup by starting Docker Desktop manually."
        Write-Warning "You need to log out and back in for the Docker Desktop changes to take effect."
        Write-Warning "After logging back in, please start Docker Desktop and wait for it to be ready."
        
        # Ask to start Docker Desktop
        $startDocker = Read-Host "Would you like to start Docker Desktop now? (Y/N)"
        if ($startDocker -eq 'Y' -or $startDocker -eq 'y') {
            Start-Process "C:\Program Files\Docker\Docker\Docker Desktop.exe"
            Write-Info "Docker Desktop is starting. Please wait for it to be ready..."
            Start-Sleep -Seconds 30  # Give Docker some time to start
        }
    } else {
        Write-Info "Docker Desktop is already installed"
    }
}

function Install-Git {
    if (-not (Test-CommandExists git)) {
        Write-Info "Installing Git..."
        choco install git -y
        $env:Path = [System.Environment]::GetEnvironmentVariable("Path","Machine") + ";" + [System.Environment]::GetEnvironmentVariable("Path","User")
        Write-Success "Git installed successfully"
    } else {
        Write-Info "Git is already installed"
    }
}

function Install-RequiredFeatures {
    Write-Info "Enabling Windows features..."
    
    # Enable WSL (Windows Subsystem for Linux)
    if (-not (Get-WindowsOptionalFeature -Online -FeatureName Microsoft-Windows-Subsystem-Linux).State -eq "Enabled") {
        Enable-WindowsOptionalFeature -Online -FeatureName Microsoft-Windows-Subsystem-Linux -NoRestart -ErrorAction SilentlyContinue | Out-Null
    }
    
    # Enable Virtual Machine Platform
    if (-not (Get-WindowsOptionalFeature -Online -FeatureName VirtualMachinePlatform).State -eq "Enabled") {
        Enable-WindowsOptionalFeature -Online -FeatureName VirtualMachinePlatform -NoRestart -ErrorAction SilentlyContinue | Out-Null
    }
    
    # Enable Hyper-V (if available)
    if ((Get-WindowsOptionalFeature -Online -FeatureName Microsoft-Hyper-V-All -ErrorAction SilentlyContinue) -and 
        -not (Get-WindowsOptionalFeature -Online -FeatureName Microsoft-Hyper-V-All).State -eq "Enabled") {
        Enable-WindowsOptionalFeature -Online -FeatureName Microsoft-Hyper-V-All -NoRestart -ErrorAction SilentlyContinue | Out-Null
    }
    
    Write-Success "Windows features enabled. A system restart may be required."
}

function Test-DockerRunning {
    try {
        docker info | Out-Null
        return $true
    } catch {
        return $false
    }
}

# Main installation process
Write-Host "`n${BLUE}=== Email-LLM Integration Dependencies Installer ===${NC}`n"

# Check if running as administrator
$isAdmin = ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
if (-not $isAdmin) {
    Write-Error "This script must be run as Administrator. Please right-click on PowerShell and select 'Run as Administrator'"
}

# Install Chocolatey
Install-Chocolatey

# Install Git
Install-Git

# Enable Windows features
Install-RequiredFeatures

# Install Docker Desktop
Install-DockerDesktop

# Verify Docker is running
Write-Info "Verifying Docker is running..."
if (-not (Test-DockerRunning)) {
    Write-Warning "Docker is not running. Please start Docker Desktop and wait for it to be ready."
    $wait = Read-Host "Press any key to continue after starting Docker Desktop..."
    
    # Check again after user confirmation
    if (-not (Test-DockerRunning)) {
        Write-Error "Docker is still not running. Please start Docker Desktop manually and run this script again."
    }
}

# Install Docker Compose if not installed via Docker Desktop
if (-not (Test-CommandExists docker-compose)) {
    Write-Info "Installing Docker Compose..."
    choco install docker-compose -y
    $env:Path = [System.Environment]::GetEnvironmentVariable("Path","Machine") + ";" + [System.Environment]::GetEnvironmentVariable("Path","User")
}

# Verify installations
Write-Info "`nVerifying installations..."
$tools = @("git", "docker", "docker-compose")
$allGood = $true

foreach ($tool in $tools) {
    if (Test-CommandExists $tool) {
        Write-Success "$tool is installed: $((Get-Command $tool).Source)"
    } else {
        Write-Error "$tool is not installed or not in PATH"
        $allGood = $false
    }
}

if ($allGood) {
    Write-Host "`n${GREEN}=== All dependencies installed successfully! ===${NC}"
    Write-Host "`nNext steps:"
    Write-Host "1. If Docker Desktop is not already running, start it from the Start menu"
    Write-Host "2. Clone the repository if you haven't already:"
    Write-Host "   git clone https://github.com/fin-officer/groovy.git"
    Write-Host "3. Navigate to the project directory and run the setup script:"
    Write-Host "   .\setup.ps1"
    Write-Host "4. Start the application:"
    Write-Host "   .\start.ps1"
} else {
    Write-Host "`n${YELLOW}=== Some dependencies may not be installed correctly ===${NC}"
    Write-Host "Please check the installation logs above and install any missing components manually."
}

# Offer to restart the computer if needed
$restart = Read-Host "`nA system restart may be required. Would you like to restart now? (Y/N)"
if ($restart -eq 'Y' -or $restart -eq 'y') {
    Restart-Computer -Confirm
}
