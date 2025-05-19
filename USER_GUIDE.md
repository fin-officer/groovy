# Email-LLM Integration User Guide

## Table of Contents
1. [Introduction](#introduction)
2. [Getting Started](#getting-started)
3. [System Components](#system-components)
4. [Using the Application](#using-the-application)
5. [API Reference](#api-reference)
6. [Troubleshooting](#troubleshooting)
7. [FAQ](#faq)

## Introduction

Email-LLM Integration is a system that integrates an email server with local Large Language Models (LLM) using Apache Camel and Groovy. The main purpose of the system is to automatically process incoming email messages, analyze their content using LLM models, and generate appropriate responses.

## Getting Started

### Prerequisites

Before you begin, ensure you have the following installed on your system:

- Docker and Docker Compose
- PowerShell (for Windows) or Bash (for Linux/macOS)

### Installation

1. Clone the repository to your local machine
2. Navigate to the project directory
3. Create a `.env` file based on the provided `env.example`
4. Run the start script:

```powershell
# Windows
.\start.ps1

# Linux/macOS
./start.sh
```

### Verifying Installation

After starting the application, you can verify that everything is working correctly by running the diagnostic script:

```powershell
.\diagnostyka.ps1
```

This will check that all required components are running and properly configured.

## System Components

The Email-LLM Integration system consists of the following main components:

1. **Apache Camel** - Integration engine that manages data flows and business logic
2. **Groovy** - Programming language used to implement business logic
3. **Spring Boot** - Framework for rapid Java/Groovy application development
4. **Ollama** - Local LLM server for text analysis
5. **SQLite** - Lightweight database for storing messages and their analysis
6. **MailHog** - Test SMTP/IMAP server for development purposes
7. **Adminer** - Administrative tool for the database

All components are run as Docker containers and managed using Docker Compose.

## Using the Application

### Web Interfaces

The application provides several web interfaces for interaction:

1. **MailHog UI**: http://localhost:8026
   - View and test emails sent by the application
   - Send test emails for processing

2. **Adminer**: http://localhost:8081
   - Manage the SQLite database
   - View processed emails and their analysis

### Processing Emails

The system automatically processes emails received by the configured IMAP server. To test this functionality:

1. Send an email to the configured email address
2. The system will process the email and analyze it using the LLM
3. View the processed email and its analysis in the database through Adminer
4. If configured, the system can automatically generate and send a response

### Direct LLM Analysis

You can directly analyze text using the LLM through the API:

```bash
curl -X POST -H "Content-Type: application/json" \
  -d '{"text":"Please schedule a meeting for tomorrow at 2 PM.", "context":"Project planning"}' \
  http://localhost:8083/api/llm/direct-analyze
```

## API Reference

The system provides the following REST API endpoints:

| Endpoint | Method | Description | Example Request |
|----------|--------|-------------|----------------|
| `/api/health` | GET | Check application status | `curl http://localhost:8083/api/health` |
| `/api/emails` | GET | Get list of processed emails | `curl http://localhost:8083/api/emails` |
| `/api/llm/direct-analyze` | POST | Direct text analysis using LLM | `curl -X POST -H "Content-Type: application/json" -d '{"text":"Message content", "context":"Context"}' http://localhost:8083/api/llm/direct-analyze` |
| `/api/api-doc` | GET | API documentation in JSON format | `curl http://localhost:8083/api/api-doc` |
| `/api/ollama/analyze` | POST | Alternative endpoint for text analysis | `curl -X POST -H "Content-Type: application/json" -d '{"text":"Message content", "model":"mistral"}' http://localhost:8083/api/ollama/analyze` |

## Troubleshooting

### Common Issues

#### Docker Issues

**Problem**: Docker containers fail to start

**Solution**: 
1. Check if Docker is running: `docker ps`
2. Check container logs: `docker logs camel-groovy-email-llm`
3. Restart Docker and try again
4. Run the diagnostic script: `.\diagnostyka.ps1`

#### Application Issues

**Problem**: API endpoints return errors

**Solution**:
1. Check if all containers are running: `docker ps`
2. Check application logs: `docker logs camel-groovy-email-llm`
3. Verify the configuration in the `.env` file
4. Restart the application: `.\start.ps1`

#### Email Processing Issues

**Problem**: Emails are not being processed

**Solution**:
1. Check the email server configuration in the `.env` file
2. Verify that the email server is accessible
3. Check the application logs for connection errors
4. Try sending a test email through MailHog

### Logs

To view application logs, use the following commands:

```bash
# View Camel application logs
docker logs camel-groovy-email-llm

# View Ollama logs
docker logs ollama

# View MailHog logs
docker logs mailserver
```

## FAQ

### How do I update the LLM model?

To change the LLM model used by the application:

1. Edit the `.env` file and change the `OLLAMA_MODEL` variable
2. Restart the application: `.\start.ps1`

### How do I backup the database?

The SQLite database is stored in the `./data` directory. To backup the database:

1. Stop the application: `.\stop.ps1`
2. Copy the `./data/emails.db` file to a safe location
3. Restart the application: `.\start.ps1`

### How do I add custom email processing logic?

To add custom email processing logic:

1. Modify the `EmailProcessingRoute.groovy` file in the `camel-groovy/src/main/groovy/com/example/emailllm` directory
2. Rebuild and restart the application

### How do I monitor system performance?

The application provides health endpoints that can be used for monitoring:

1. Check the health endpoint: `curl http://localhost:8083/api/health`
2. Use the diagnostic script: `.\diagnostyka.ps1`
3. Monitor container resource usage: `docker stats`
