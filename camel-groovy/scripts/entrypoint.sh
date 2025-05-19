#!/bin/bash
set -e

echo "Executing database initialization script..."
/app/scripts/init-db.sh

echo "Starting application..."
exec java $JAVA_OPTS -jar /app/app.jar
