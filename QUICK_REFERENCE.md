# Email-LLM Integration Quick Reference Guide

## Starting and Stopping the Application

```powershell
# Start the application
.\start.ps1

# Stop the application
.\stop.ps1

# Restart the application
.\restart.ps1
```

## Diagnostic Commands

```powershell
# Run full diagnostics
.\diagnostyka.ps1

# Check Docker status
.\start-docker-service.ps1

# Test application functionality
.\test-app.ps1
```

## Docker Commands

```powershell
# View running containers
docker ps

# View container logs
docker logs camel-groovy-email-llm
docker logs ollama
docker logs mailserver

# Restart a specific container
docker restart camel-groovy-email-llm

# Access container shell
docker exec -it camel-groovy-email-llm sh
```

## Web Interfaces

| Service | URL | Description |
|---------|-----|-------------|
| MailHog UI | http://localhost:8026 | Email testing interface |
| Adminer | http://localhost:8081 | Database management |

## API Endpoints

| Endpoint | Method | Description | Example |
|----------|--------|-------------|--------|
| `/api/health` | GET | Check system health | `curl http://localhost:8080/api/health` |
| `/api/emails` | GET | List processed emails | `curl http://localhost:8080/api/emails` |
| `/api/llm/direct-analyze` | POST | Analyze text with LLM | `curl -X POST -H "Content-Type: application/json" -d '{"text":"Analyze this"}' http://localhost:8080/api/llm/direct-analyze` |

## Common Issues and Solutions

### Docker Not Running

```powershell
# Start Docker service
.\start-docker-service.ps1
```

### Application Not Starting

```powershell
# Check logs
docker logs camel-groovy-email-llm

# Fix entrypoint scripts
.\fix-scripts.ps1

# Rebuild and restart
docker compose down
docker compose build camel-groovy
docker compose up -d
```

### Database Issues

```powershell
# Access SQLite database
docker exec -it camel-groovy-email-llm sqlite3 /data/emails.db

# Backup database
docker exec camel-groovy-email-llm sqlite3 /data/emails.db ".backup '/data/backup.db'"
```

## Environment Configuration

Key environment variables in `.env` file:

```
# Server configuration
SERVER_PORT=8080

# Ollama configuration
OLLAMA_HOST=ollama
OLLAMA_PORT=11434
OLLAMA_MODEL=mistral

# Database configuration
SQLITE_DB_PATH=/data/emails.db

# Email configuration
MAILHOG_SMTP_PORT=1026
MAILHOG_UI_PORT=8026
```

## Useful PowerShell Commands

```powershell
# Check if port is in use
Get-NetTCPConnection -LocalPort 8080 -ErrorAction SilentlyContinue

# Check if service is running
Get-Service -Name docker

# Find process using a port
Get-Process -Id (Get-NetTCPConnection -LocalPort 8080).OwningProcess
```
