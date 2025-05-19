# PowerShell script to initialize the Email-LLM project with Apache Camel and Groovy
# Author: Project structure generator
# Date: 2025-05-17

# Exit on error
$ErrorActionPreference = "Stop"

# Colors for output
$GREEN = "`e[0;32m"
$BLUE = "`e[0;34m"
$YELLOW = "`e[1;33m"
$RED = "`e[0;31m"
$NC = "`e[0m" # No Color

# Function to display info messages
function Info {
    param([string]$message)
    Write-Host "${BLUE}[INFO]${NC} $message"
}

# Function to display success messages
function Success {
    param([string]$message)
    Write-Host "${GREEN}[SUCCESS]${NC} $message"
}

# Function to display warning messages
function Warning {
    param([string]$message)
    Write-Host "${YELLOW}[WARNING]${NC} $message"
}

# Function to display error messages
function Error {
    param([string]$message)
    Write-Host "${RED}[ERROR]${NC} $message"
    exit 1
}

# Function to check requirements
function Check-Requirements {
    Info "Checking system requirements..."

    # Check Docker
    if (-not (Get-Command docker -ErrorAction SilentlyContinue)) {
        Error "Docker is not installed. Please install Docker before continuing."
    }

    # Check Docker Compose
    if (-not (Get-Command docker-compose -ErrorAction SilentlyContinue)) {
        Error "Docker Compose is not installed. Please install Docker Compose before continuing."
    }

    # Check curl
    if (-not (Get-Command curl -ErrorAction SilentlyContinue)) {
        Warning "curl is not installed. Some features may not work properly."
    }
}

# Function to create directory structure
function Create-DirectoryStructure {
    Info "Creating project directory structure..."
    
    $directories = @(
        "camel-groovy",
        "camel-groovy/src",
        "camel-groovy/src/main",
        "camel-groovy/src/main/java",
        "camel-groovy/src/main/resources",
        "camel-groovy/src/test",
        "camel-groovy/src/test/java",
        "data",
        "logs",
        "gradle-cache",
        "ollama_models"
    )

    foreach ($dir in $directories) {
        if (-not (Test-Path $dir)) {
            New-Item -ItemType Directory -Path $dir
            Info "Created directory: $dir"
        }
    }
}

# Function to create project files
function Create-ProjectFiles {
    Info "Creating project files..."
    
    $files = @(
        @{
            Path = "camel-groovy/build.gradle";
            Content = "// Gradle build file content"
        },
        @{
            Path = "camel-groovy/src/main/resources/application.properties";
            Content = "# Application properties"
        },
        @{
            Path = "camel-groovy/src/main/java/EmailLLMApplication.groovy";
            Content = "// Main application class"
        }
    )

    foreach ($file in $files) {
        if (-not (Test-Path $file.Path)) {
            New-Item -ItemType File -Path $file.Path
            Set-Content -Path $file.Path -Value $file.Content
            Info "Created file: $($file.Path)"
        }
    }
}

# Main installation function
function Install-Project {
    try {
        Check-Requirements
        Create-DirectoryStructure
        Create-ProjectFiles
        Success "Project setup completed successfully!"
    } catch {
        Error "An error occurred during installation: $_"
    }
}

# Run installation
Install-Project
