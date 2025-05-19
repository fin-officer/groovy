#!/bin/bash

# Script to fix entrypoint script issues in the container

echo "Stopping any running containers..."
docker-compose down

echo "Creating a temporary fix container..."
docker run --rm -v "$(pwd)/camel-groovy/scripts:/scripts" bash:latest bash -c 'cd /scripts && dos2unix *.sh && chmod +x *.sh'

echo "Rebuilding the camel-groovy container..."
docker-compose build camel-groovy

echo "Starting all containers..."
docker-compose up -d

echo "Done! Check container logs with: docker logs camel-groovy-email-llm"
