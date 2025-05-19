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

# Stop existing containers
echo -e "${BLUE}[INFO]${NC} Stopping existing containers..."
docker-compose down

# Build images
echo -e "${BLUE}[INFO]${NC} Building images..."
docker-compose build

# Start containers
echo -e "${BLUE}[INFO]${NC} Starting containers..."
docker-compose up -d

# Wait for Ollama to start
echo -e "${BLUE}[INFO]${NC} Waiting for Ollama to start..."
until docker exec -i ollama curl -s http://localhost:11434/api/health &> /dev/null; do
    echo -n "."
    sleep 2
done
echo ""

# Download Mistral model if it doesn't exist
if ! docker exec -i ollama ollama list | grep -q mistral; then
    echo -e "${BLUE}[INFO]${NC} Downloading Mistral model (may take several minutes)..."
    docker exec -i ollama ollama pull mistral
fi

# Wait for application to start
echo -e "${BLUE}[INFO]${NC} Waiting for application to start..."
for i in $(seq 1 30); do
    if curl -s http://localhost:8080/api/health &> /dev/null; then
        echo ""
        break
    fi
    echo -n "."
    sleep 2
    if [ $i -eq 30 ]; then
        echo ""
        echo -e "${YELLOW}[WARNING]${NC} Application health check timeout, but containers may still be starting..."
    fi
done

# Check container status
echo -e "${BLUE}[INFO]${NC} Checking container status..."
docker ps | grep -E 'ollama|camel-groovy|mailserver|adminer'

echo -e "${GREEN}[SUCCESS]${NC} System started successfully!"
echo ""
echo "Available services:"
echo -e "${BLUE}* API:${NC} http://localhost:8080/api"
echo -e "${BLUE}* API Documentation:${NC} http://localhost:8080/api/api-doc"
echo -e "${BLUE}* Test Email Panel:${NC} http://localhost:${MAILHOG_UI_PORT:-8025}"
echo -e "${BLUE}* SQLite Admin Panel:${NC} http://localhost:${ADMINER_PORT:-8081}"
echo ""
echo -e "${YELLOW}To check application logs:${NC} docker logs -f camel-groovy-email-llm"
echo -e "${YELLOW}To stop the system:${NC} docker-compose down"