# PowerShell script to stop the Email-LLM Integration project

# Colors for output
$GREEN = "`e[0;32m"
$BLUE = "`e[0;34m"
$YELLOW = "`e[1;33m"
$RED = "`e[0;31m"
$NC = "`e[0m" # No Color

Write-Host "${BLUE}[INFO]${NC} Stopping Email-LLM Integration system..."

# Check if Docker is running
try {
    docker info -ErrorAction Stop
} catch {
    Write-Host "${RED}[ERROR]${NC} Docker is not running. Cannot properly stop containers."
    exit 1
}

# Stop and remove all containers from docker-compose
Write-Host "${BLUE}[INFO]${NC} Stopping containers managed by docker-compose..."
docker-compose down --remove-orphans

# Check for any remaining containers related to the project
$remainingContainers = docker ps -a | Select-String -Pattern "mailserver|ollama|camel-groovy|adminer" | ForEach-Object { $_.Matches.Value }
if ($remainingContainers) {
    Write-Host "${YELLOW}[WARNING]${NC} Found remaining containers. Stopping and removing them..."
    foreach ($container in $remainingContainers) {
        docker stop $container
        docker rm $container
    }
}

# Check if any containers are still running
$runningContainers = docker ps | Select-String -Pattern "mailserver|ollama|camel-groovy|adminer"
if ($runningContainers) {
    Write-Host "${RED}[ERROR]${NC} Some containers could not be stopped. Please check:"
    docker ps | Select-String -Pattern "mailserver|ollama|camel-groovy|adminer"
    exit 1
} else {
    Write-Host "${GREEN}[SUCCESS]${NC} All Email-LLM Integration containers stopped successfully!"
}

# Optional: Remove volumes (uncomment if you want to also clean volume data)
# Write-Host "${BLUE}[INFO]${NC} Removing project volumes..."
# $volumes = docker volume ls -q | Select-String -Pattern "ollama_models|sqlite_data"
# if ($volumes) {
#     docker volume rm $volumes
# }

# Optional: Clean up dangling images (uncomment if you want to clean up images too)
# Write-Host "${BLUE}[INFO]${NC} Cleaning up dangling images..."
# docker image prune -f
