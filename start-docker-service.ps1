# Script to start Docker service on Windows

# Colors for output
$GREEN = "`e[0;32m"
$BLUE = "`e[0;34m"
$YELLOW = "`e[1;33m"
$RED = "`e[0;31m"
$NC = "`e[0m" # No Color

Write-Host "${BLUE}[INFO]${NC} Checking Docker installation..."

# Check if Docker CLI is available
$dockerCliAvailable = $null -ne (Get-Command "docker" -ErrorAction SilentlyContinue)

if (-not $dockerCliAvailable) {
    Write-Host "${RED}[ERROR]${NC} Docker CLI not found. Please ensure Docker is installed."
    exit 1
}

Write-Host "${BLUE}[INFO]${NC} Docker CLI is available. Checking Docker Desktop..."

# Check for Docker Desktop
$dockerDesktopPaths = @(
    "${env:ProgramFiles}\Docker\Docker\Docker Desktop.exe",
    "${env:ProgramFiles(x86)}\Docker\Docker\Docker Desktop.exe",
    "${env:LOCALAPPDATA}\Docker\Docker Desktop.exe"
)

$dockerDesktopPath = $null
foreach ($path in $dockerDesktopPaths) {
    if (Test-Path $path) {
        $dockerDesktopPath = $path
        break
    }
}

if ($null -ne $dockerDesktopPath) {
    Write-Host "${BLUE}[INFO]${NC} Found Docker Desktop at: $dockerDesktopPath"
    Write-Host "${BLUE}[INFO]${NC} Starting Docker Desktop..."
    
    # Start Docker Desktop
    Start-Process -FilePath $dockerDesktopPath
    
    # Wait for Docker to be ready
    Write-Host "${BLUE}[INFO]${NC} Waiting for Docker to start (this may take a minute)..."
    $maxAttempts = 30
    $attempts = 0
    $dockerRunning = $false
    
    while ($attempts -lt $maxAttempts) {
        Start-Sleep -Seconds 5
        $attempts++
        
        try {
            $dockerStatus = docker info 2>&1
            if ($LASTEXITCODE -eq 0) {
                $dockerRunning = $true
                break
            }
        } catch {
            # Continue waiting
        }
        
        Write-Host "${YELLOW}[WAITING]${NC} Attempt $attempts of $maxAttempts..."
    }
    
    if ($dockerRunning) {
        Write-Host "${GREEN}[SUCCESS]${NC} Docker is now running!"
        Write-Host "${BLUE}[INFO]${NC} You can now run .\run-app.ps1 to start the application."
    } else {
        Write-Host "${RED}[ERROR]${NC} Docker did not start properly after multiple attempts."
        Write-Host "${YELLOW}[INFO]${NC} Please try starting Docker Desktop manually:"
        Write-Host "1. Open Docker Desktop from the Start menu"
        Write-Host "2. Wait for it to fully initialize"
        Write-Host "3. Then run .\run-app.ps1"
    }
} else {
    # Check if Docker is running through WSL
    Write-Host "${BLUE}[INFO]${NC} Docker Desktop not found. Checking WSL..."
    
    # Check if WSL is available
    $wslAvailable = $null -ne (Get-Command "wsl" -ErrorAction SilentlyContinue)
    
    if ($wslAvailable) {
        Write-Host "${BLUE}[INFO]${NC} WSL is available. Checking Docker in WSL..."
        
        # Check if docker-desktop WSL distribution exists
        $wslList = wsl --list
        $hasDockerWSL = $wslList -match "docker-desktop"
        
        if ($hasDockerWSL) {
            Write-Host "${BLUE}[INFO]${NC} Found Docker WSL distribution. Starting it..."
            
            # Start the docker-desktop WSL distribution
            Start-Process -FilePath "wsl" -ArgumentList "-d", "docker-desktop" -WindowStyle Hidden
            
            # Wait for Docker to be ready
            Write-Host "${BLUE}[INFO]${NC} Waiting for Docker to start (this may take a minute)..."
            $maxAttempts = 30
            $attempts = 0
            $dockerRunning = $false
            
            while ($attempts -lt $maxAttempts) {
                Start-Sleep -Seconds 5
                $attempts++
                
                try {
                    $dockerStatus = docker info 2>&1
                    if ($LASTEXITCODE -eq 0) {
                        $dockerRunning = $true
                        break
                    }
                } catch {
                    # Continue waiting
                }
                
                Write-Host "${YELLOW}[WAITING]${NC} Attempt $attempts of $maxAttempts..."
            }
            
            if ($dockerRunning) {
                Write-Host "${GREEN}[SUCCESS]${NC} Docker is now running through WSL!"
                Write-Host "${BLUE}[INFO]${NC} You can now run .\run-app.ps1 to start the application."
            } else {
                Write-Host "${RED}[ERROR]${NC} Docker did not start properly after multiple attempts."
                Write-Host "${YELLOW}[INFO]${NC} Please try the following:"
                Write-Host "1. Open a new PowerShell window"
                Write-Host "2. Run: wsl --shutdown"
                Write-Host "3. Run: wsl -d docker-desktop"
                Write-Host "4. Then run .\run-app.ps1"
            }
        } else {
            Write-Host "${RED}[ERROR]${NC} Docker WSL distribution not found."
            Write-Host "${YELLOW}[INFO]${NC} Please make sure Docker Desktop is installed properly."
        }
    } else {
        Write-Host "${RED}[ERROR]${NC} Neither Docker Desktop nor WSL was found."
        Write-Host "${YELLOW}[INFO]${NC} Please install Docker Desktop from: https://www.docker.com/products/docker-desktop/"
    }
}