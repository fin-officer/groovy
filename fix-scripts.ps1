# PowerShell script to fix entrypoint script issues in the container

# Colors for output
$GREEN = "`e[0;32m"
$BLUE = "`e[0;34m"
$YELLOW = "`e[1;33m"
$RED = "`e[0;31m"
$NC = "`e[0m" # No Color

Write-Host "${BLUE}[INFO]${NC} Stopping any running containers..."
docker compose down

Write-Host "${BLUE}[INFO]${NC} Creating a simple entrypoint script..."

# Create a new entrypoint.sh file with proper line endings
@"
#!/bin/bash
set -e

echo "Starting application..."
exec java $JAVA_OPTS -jar /app/app.jar
"@ | Out-File -FilePath "./camel-groovy/scripts/entrypoint.sh" -Encoding ASCII

# Create a simpler init-db.sh file
@"
#!/bin/bash
set -e

echo "Database initialization skipped for now."
"@ | Out-File -FilePath "./camel-groovy/scripts/init-db.sh" -Encoding ASCII

Write-Host "${BLUE}[INFO]${NC} Rebuilding the camel-groovy container..."
docker compose build camel-groovy

Write-Host "${BLUE}[INFO]${NC} Starting all containers..."
docker compose up -d

Write-Host "${GREEN}[SUCCESS]${NC} Done! Check container logs with: docker logs camel-groovy-email-llm"
