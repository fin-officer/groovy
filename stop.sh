#!/bin/bash
# Script to stop the Email-LLM Integration project

GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

echo -e "${BLUE}[INFO]${NC} Stopping Email-LLM Integration system..."

# Check if Docker is running
if ! docker info > /dev/null 2>&1; then
    echo -e "${RED}[ERROR]${NC} Docker is not running. Cannot properly stop containers."
    exit 1
fi

# Stop and remove all containers from docker-compose
echo -e "${BLUE}[INFO]${NC} Stopping containers managed by docker-compose..."
docker-compose down --remove-orphans

# Check for any remaining containers related to the project
REMAINING_CONTAINERS=$(docker ps -a | grep -E 'mailserver|ollama|camel-groovy|adminer' | awk '{print $1}')
if [ ! -z "$REMAINING_CONTAINERS" ]; then
    echo -e "${YELLOW}[WARNING]${NC} Found remaining containers. Stopping and removing them..."
    docker stop $REMAINING_CONTAINERS > /dev/null 2>&1
    docker rm $REMAINING_CONTAINERS > /dev/null 2>&1
fi

# Check if any containers are still running
if docker ps | grep -qE 'mailserver|ollama|camel-groovy|adminer'; then
    echo -e "${RED}[ERROR]${NC} Some containers could not be stopped. Please check:"
    docker ps | grep -E 'mailserver|ollama|camel-groovy|adminer'
    exit 1
else
    echo -e "${GREEN}[SUCCESS]${NC} All Email-LLM Integration containers stopped successfully!"
fi

# Optional: Remove volumes (uncomment if you want to also clean volume data)
# echo -e "${BLUE}[INFO]${NC} Removing project volumes..."
# docker volume rm $(docker volume ls -q | grep -E 'ollama_models|sqlite_data')

# Optional: Clean up dangling images (uncomment if you want to clean up images too)
# echo -e "${BLUE}[INFO]${NC} Cleaning up dangling images..."
# docker image prune -f