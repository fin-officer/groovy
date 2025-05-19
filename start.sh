#!/bin/bash
# Script to start the Email-LLM Integration project

GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

echo -e "${BLUE}[INFO]${NC} Starting Email-LLM Integration system..."

# Check if Docker is running
if ! docker info > /dev/null 2>&1; then
    echo -e "${RED}[ERROR]${NC} Docker is not running. Please start Docker and try again."
    exit 1
fi

# Sprawdź dostępność portów
if [ -f "./check-ports.sh" ]; then
    echo -e "${BLUE}[INFO]${NC} Checking port availability..."
    bash ./check-ports.sh
else
    echo -e "${YELLOW}[WARNING]${NC} Port checker script not found. Skipping port check."
fi

# Create necessary directories with proper permissions
echo -e "${BLUE}[INFO]${NC} Creating necessary directories..."
mkdir -p ./data ./logs ./gradle-cache

# Create ollama_models directory only if it doesn't exist
if [ ! -d "./ollama_models" ]; then
    mkdir -p ./ollama_models
fi

# Don't try to change permissions on ollama_models if they already exist
# This avoids Permission denied errors
if [ -w "./data" ]; then
    chmod -R 777 ./data
fi
if [ -w "./logs" ]; then
    chmod -R 777 ./logs
fi
if [ -w "./gradle-cache" ]; then
    chmod -R 777 ./gradle-cache
fi

# Check for existing containers and handle conflicts
echo -e "${BLUE}[INFO]${NC} Checking for existing containers..."
EXISTING_CONTAINERS=$(docker ps -a | grep -E 'mailserver|ollama|camel-groovy|adminer' | awk '{print $1}')
if [ ! -z "$EXISTING_CONTAINERS" ]; then
    echo -e "${YELLOW}[WARNING]${NC} Found existing containers that may conflict."
    echo -e "${BLUE}[INFO]${NC} Stopping and removing existing containers..."
    docker stop $EXISTING_CONTAINERS > /dev/null 2>&1
    docker rm $EXISTING_CONTAINERS > /dev/null 2>&1
fi

# Stop any remaining containers from this project
echo -e "${BLUE}[INFO]${NC} Ensuring all project containers are stopped..."
docker-compose down --remove-orphans > /dev/null 2>&1

# Build images with build cache
echo -e "${BLUE}[INFO]${NC} Building images with cache optimization..."
docker-compose build --build-arg GRADLE_OPTS="-Dorg.gradle.daemon=false -Dorg.gradle.caching=true" --pull

# Get server port from .env without comments
SERVER_PORT=$(grep "SERVER_PORT=" .env 2>/dev/null | cut -d '=' -f2 | sed 's/#.*$//' | xargs || echo "8083")
echo -e "${BLUE}[INFO]${NC} Checking if port $SERVER_PORT is in use by Docker containers..."

# Find and stop containers using the API port
CONTAINERS_USING_PORT=$(docker ps --format "{{.ID}}" -f "publish=$SERVER_PORT")
if [ ! -z "$CONTAINERS_USING_PORT" ]; then
    echo -e "${YELLOW}[WARNING]${NC} Found containers using port $SERVER_PORT. Stopping them..."
    docker stop $CONTAINERS_USING_PORT
fi

# Start containers
echo -e "${BLUE}[INFO]${NC} Starting containers..."
docker-compose up -d

# Wait for Ollama to start
echo -e "${BLUE}[INFO]${NC} Waiting for Ollama to start..."
MAX_RETRIES=30
RETRY_COUNT=0
while ! docker exec -i ollama curl -s http://localhost:11434/api/health &> /dev/null; do
    echo -n "."
    sleep 2
    RETRY_COUNT=$((RETRY_COUNT+1))
    if [ $RETRY_COUNT -ge $MAX_RETRIES ]; then
        echo ""
        echo -e "${YELLOW}[WARNING]${NC} Ollama health check timeout. Checking container status..."
        docker ps | grep ollama
        docker logs ollama | tail -20

        echo -e "${BLUE}[INFO]${NC} Trying to continue anyway..."
        break
    fi
done
echo ""

# Only try to pull the model if Ollama is running
if docker ps | grep -q ollama; then
    # Download Mistral model if it doesn't exist
    if ! docker exec -i ollama ollama list 2>/dev/null | grep -q mistral; then
        echo -e "${BLUE}[INFO]${NC} Downloading Mistral model (may take several minutes)..."
        docker exec -i ollama ollama pull mistral
    else
        echo -e "${BLUE}[INFO]${NC} Mistral model already downloaded."
    fi
else
    echo -e "${YELLOW}[WARNING]${NC} Ollama container not running, skipping model download."
fi

# Wait for application to start
echo -e "${BLUE}[INFO]${NC} Waiting for application to start..."
MAX_APP_RETRIES=45
APP_RETRY_COUNT=0

# Get actual server port from .env file, clean it from comments
SERVER_PORT=$(grep "SERVER_PORT=" .env 2>/dev/null | cut -d '=' -f2 | sed 's/#.*$//' | xargs || echo "8083")
echo -e "${BLUE}[INFO]${NC} Using API port: $SERVER_PORT"

while ! curl -s http://localhost:$SERVER_PORT/api/health &> /dev/null; do
    echo -n "."
    sleep 2
    APP_RETRY_COUNT=$((APP_RETRY_COUNT+1))
    if [ $APP_RETRY_COUNT -ge $MAX_APP_RETRIES ]; then
        echo ""
        echo -e "${YELLOW}[WARNING]${NC} Application health check timeout. Checking container logs..."
        docker ps | grep camel-groovy
        docker logs camel-groovy-email-llm 2>/dev/null | tail -20
        break
    fi
done
echo ""

# Check container status
echo -e "${BLUE}[INFO]${NC} Checking container status..."
docker ps | grep -E 'ollama|camel-groovy|mailserver|adminer'

# Read port values from .env for display, clean from comments
MAILHOG_UI_PORT=$(grep "MAILHOG_UI_PORT=" .env 2>/dev/null | cut -d '=' -f2 | sed 's/#.*$//' | xargs || echo "8026")
ADMINER_PORT=$(grep "ADMINER_PORT=" .env 2>/dev/null | cut -d '=' -f2 | sed 's/#.*$//' | xargs || echo "8081")

echo -e "${GREEN}[SUCCESS]${NC} System started successfully!"
echo ""
echo "Available services:"
echo -e "${BLUE}* API:${NC} http://localhost:$SERVER_PORT/api"
echo -e "${BLUE}* API Documentation:${NC} http://localhost:$SERVER_PORT/api/api-doc"
echo -e "${BLUE}* Test Email Panel:${NC} http://localhost:$MAILHOG_UI_PORT"
echo -e "${BLUE}* SQLite Admin Panel:${NC} http://localhost:$ADMINER_PORT"
echo ""
echo -e "${YELLOW}To check application logs:${NC} docker logs -f camel-groovy-email-llm"
echo -e "${YELLOW}To check Ollama logs:${NC} docker logs -f ollama"
echo -e "${YELLOW}To stop the system:${NC} ./stop.sh"