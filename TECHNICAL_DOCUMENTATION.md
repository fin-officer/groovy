# Email-LLM Integration Technical Documentation

## Table of Contents
1. [System Architecture](#system-architecture)
2. [Docker Environment](#docker-environment)
3. [Application Components](#application-components)
4. [Data Flow](#data-flow)
5. [Database Schema](#database-schema)
6. [API Specifications](#api-specifications)
7. [Configuration Reference](#configuration-reference)
8. [Development Guidelines](#development-guidelines)
9. [Testing](#testing)
10. [Deployment](#deployment)

## System Architecture

The Email-LLM Integration system is built using a microservices architecture with Docker containers. The core components are:

```
┌─────────────────┐     ┌──────────────┐     ┌───────────────┐
│                 │     │              │     │               │
│  Email Server   │────▶│  Camel App   │────▶│  Ollama LLM   │
│   (MailHog)     │     │  (Groovy)    │     │               │
│                 │     │              │     │               │
└─────────────────┘     └──────────────┘     └───────────────┘
                              │
                              ▼
                        ┌──────────────┐     ┌───────────────┐
                        │              │     │               │
                        │    SQLite    │────▶│    Adminer    │
                        │   Database   │     │               │
                        │              │     │               │
                        └──────────────┘     └───────────────┘
```

### Communication Flow

1. Emails are received by the MailHog server
2. The Camel application polls the email server for new messages
3. Messages are processed and sent to the Ollama LLM for analysis
4. Analysis results are stored in the SQLite database
5. Responses can be generated and sent back through the email server
6. The entire process can be monitored and managed through REST APIs

## Docker Environment

The application uses Docker Compose to manage all services. The following containers are defined:

| Container | Image | Purpose |
|-----------|-------|--------|
| camel-groovy-email-llm | Custom (built from Dockerfile) | Main application |
| ollama | ollama/ollama | Local LLM server |
| mailserver | mailhog/mailhog | SMTP/IMAP server for testing |
| adminer | adminer | Database management UI |

### Network Configuration

All containers are connected to a single Docker network (`app-network`), allowing them to communicate with each other using container names as hostnames.

### Volume Mounts

| Container | Mount | Purpose |
|-----------|-------|--------|
| camel-groovy-email-llm | ./data:/data | Persistent storage for SQLite database |
| ollama | ./ollama_models:/root/.ollama | Persistent storage for LLM models |

## Application Components

### Main Application Classes

#### EmailLlmIntegrationApplication

The main Spring Boot application class that initializes the application context and configures the environment.

```groovy
package com.example.emailllm

@SpringBootApplication
@ImportResource("classpath:camel-context.xml")
class EmailLlmIntegrationApplication {
    static void main(String[] args) {
        SpringApplication.run(EmailLlmIntegrationApplication, args)
    }
    
    @Bean
    DataSource dataSource(@Value('${SQLITE_DB_PATH}') String dbPath) {
        // SQLite DataSource configuration
    }
}
```

#### EmailProcessingRoute

The main Camel route for processing emails, implementing the core business logic.

```groovy
package com.example.emailllm

@Component
class EmailProcessingRoute extends RouteBuilder {
    @Override
    void configure() {
        // Configure error handling
        errorHandler(deadLetterChannel("direct:error"))
        
        // Main email processing route
        from("imaps://{{EMAIL_IMAP_HOST}}:{{EMAIL_IMAP_PORT}}")
            .routeId("emailProcessor")
            .log("Processing new email: ${header.subject}")
            .process(new EmailProcessor())
            .to("direct:analyzeLLM")
            .to("jdbc:dataSource")
            
        // Other route definitions
    }
}
```

#### MaintenanceRoutes

Contains routes for system maintenance tasks such as health checks and database optimization.

```groovy
package com.example.emailllm

@Component
class MaintenanceRoutes extends RouteBuilder {
    @Override
    void configure() {
        // Scheduled health check
        from("timer:healthCheck?period=3600000")
            .routeId("healthCheck")
            .log(LoggingLevel.INFO, "Running scheduled health check")
            .setBody().constant("PRAGMA quick_check;")
            .to("jdbc:dataSource")
            .log(LoggingLevel.INFO, "Database health check completed")
            
        // Other maintenance routes
    }
}
```

#### OllamaDirectRoute

Implements direct integration with the Ollama LLM service.

```groovy
package com.example.emailllm

@Component
class OllamaDirectRoute extends RouteBuilder {
    @Override
    void configure() {
        // REST API configuration
        restConfiguration()
            .component("servlet")
            .bindingMode(RestBindingMode.json)
            .dataFormatProperty("prettyPrint", "true")
            .contextPath("/api")
            
        // LLM analysis endpoint
        rest("/llm")
            .post("/direct-analyze")
            .consumes("application/json")
            .produces("application/json")
            .to("direct:analyzeLLM")
            
        // LLM analysis route
        from("direct:analyzeLLM")
            .routeId("llmAnalyzer")
            .log("Analyzing text with LLM")
            .process(new OllamaRequestProcessor())
            .to("http://{{OLLAMA_HOST}}:{{OLLAMA_PORT}}/api/generate")
            .process(new OllamaResponseProcessor())
    }
}
```

### Processors

#### EmailProcessor

Processes email messages, extracting relevant information and preparing them for analysis.

#### OllamaRequestProcessor

Prepares requests to the Ollama LLM service, formatting the prompt and setting appropriate headers.

#### OllamaResponseProcessor

Processes responses from the Ollama LLM service, extracting the generated text and formatting it for the client.

## Data Flow

### Email Processing Flow

1. **Email Reception**:
   - Email is received by the IMAP server
   - Camel polls the server at regular intervals

2. **Initial Processing**:
   - Email headers and content are extracted
   - Attachments are processed if present
   - Message is converted to a standardized format

3. **LLM Analysis**:
   - Email content is sent to the Ollama LLM
   - LLM generates an analysis of the content
   - Analysis is attached to the email record

4. **Storage**:
   - Email and analysis are stored in the SQLite database
   - Attachments are stored separately with references

5. **Response Generation** (optional):
   - Based on analysis, a response may be generated
   - Response is sent back through the SMTP server

### API Request Flow

1. **Request Reception**:
   - REST API receives a request
   - Request is validated and routed to the appropriate handler

2. **Processing**:
   - Request is processed according to the endpoint
   - For LLM analysis, text is sent to Ollama

3. **Response**:
   - Results are formatted as JSON
   - Response is sent back to the client

## Database Schema

### Table: processed_emails

| Column | Type | Description |
|--------|------|-------------|
| id | INTEGER | Primary key |
| message_id | TEXT | Unique email message ID |
| subject | TEXT | Email subject |
| sender | TEXT | Sender email address |
| recipients | TEXT | Recipient email addresses (JSON array) |
| received_date | TIMESTAMP | Date email was received |
| processed_date | TIMESTAMP | Date email was processed |
| body_text | TEXT | Plain text body |
| body_html | TEXT | HTML body (if available) |
| status | TEXT | Processing status |
| llm_analysis | TEXT | LLM analysis result (JSON) |
| metadata | TEXT | Additional metadata (JSON) |

### Table: email_attachments

| Column | Type | Description |
|--------|------|-------------|
| id | INTEGER | Primary key |
| email_id | INTEGER | Foreign key to processed_emails.id |
| filename | TEXT | Original filename |
| content_type | TEXT | MIME type |
| size | INTEGER | Size in bytes |
| content | BLOB | Attachment content |

## API Specifications

### Health Check

**Endpoint**: `GET /api/health`

**Response**:
```json
{
  "status": "OK",
  "components": {
    "database": "OK",
    "ollama": "OK",
    "email": "OK"
  },
  "timestamp": "2025-05-19T15:30:00Z"
}
```

### Email List

**Endpoint**: `GET /api/emails`

**Query Parameters**:
- `limit` (optional): Maximum number of emails to return (default: 10)
- `offset` (optional): Offset for pagination (default: 0)
- `sort` (optional): Field to sort by (default: "received_date")
- `order` (optional): Sort order ("asc" or "desc", default: "desc")

**Response**:
```json
{
  "total": 42,
  "limit": 10,
  "offset": 0,
  "emails": [
    {
      "id": 1,
      "message_id": "<example@mail.com>",
      "subject": "Test Email",
      "sender": "sender@example.com",
      "received_date": "2025-05-19T15:00:00Z",
      "status": "processed",
      "has_attachments": false
    },
    // More emails...
  ]
}
```

### Direct LLM Analysis

**Endpoint**: `POST /api/llm/direct-analyze`

**Request Body**:
```json
{
  "text": "Please analyze this text for sentiment and key points.",
  "context": "Customer support email",
  "model": "mistral",  // Optional, defaults to configured model
  "options": {  // Optional
    "temperature": 0.7,
    "max_tokens": 500
  }
}
```

**Response**:
```json
{
  "analysis": "The text appears to be neutral in sentiment. Key points identified: request for analysis, focus on sentiment and key points extraction.",
  "metadata": {
    "model": "mistral",
    "processing_time": 0.45,
    "token_count": 32
  }
}
```

## Configuration Reference

### Environment Variables

#### Application Configuration

| Variable | Description | Default | Required |
|----------|-------------|---------|----------|
| SERVER_PORT | Port for the REST API | 8080 | Yes |
| LOG_LEVEL | Application log level | INFO | No |
| CAMEL_DEBUG | Enable Camel debugging | false | No |
| CAMEL_TRACING | Enable Camel tracing | false | No |

#### Email Configuration

| Variable | Description | Default | Required |
|----------|-------------|---------|----------|
| EMAIL_HOST | SMTP host | - | Yes |
| EMAIL_PORT | SMTP port | 587 | Yes |
| EMAIL_USER | SMTP username | - | Yes |
| EMAIL_PASSWORD | SMTP password | - | Yes |
| EMAIL_USE_TLS | Use TLS for SMTP | true | No |
| EMAIL_IMAP_HOST | IMAP host | - | Yes |
| EMAIL_IMAP_PORT | IMAP port | 993 | Yes |
| EMAIL_IMAP_FOLDER | IMAP folder to monitor | INBOX | No |

#### Ollama Configuration

| Variable | Description | Default | Required |
|----------|-------------|---------|----------|
| OLLAMA_HOST | Ollama host | ollama | Yes |
| OLLAMA_PORT | Ollama port | 11434 | Yes |
| OLLAMA_MODEL | Default LLM model | mistral | Yes |
| OLLAMA_API_KEY | API key (if required) | - | No |

#### Database Configuration

| Variable | Description | Default | Required |
|----------|-------------|---------|----------|
| SQLITE_DB_PATH | Path to SQLite database | /data/emails.db | Yes |
| SQLITE_JOURNAL_MODE | SQLite journal mode | WAL | No |
| SQLITE_CACHE_SIZE | SQLite cache size | 102400 | No |
| SQLITE_SYNCHRONOUS | SQLite synchronous setting | NORMAL | No |

## Development Guidelines

### Adding New Routes

To add a new Camel route:

1. Create a new class that extends `RouteBuilder` in the `com.example.emailllm` package
2. Implement the `configure()` method to define your routes
3. Add the `@Component` annotation to ensure Spring discovers the route

Example:

```groovy
package com.example.emailllm

import org.apache.camel.builder.RouteBuilder
import org.springframework.stereotype.Component

@Component
class MyNewRoute extends RouteBuilder {
    @Override
    void configure() {
        from("direct:myNewEndpoint")
            .routeId("myNewRoute")
            .log("Processing request")
            .process { exchange ->
                // Custom processing logic
            }
            .to("log:output")
    }
}
```

### Adding REST Endpoints

To add a new REST endpoint:

1. Choose an existing route class or create a new one
2. Add REST DSL configuration in the `configure()` method

Example:

```groovy
rest("/myapi")
    .get("/resource")
    .produces("application/json")
    .to("direct:getResource")
    
    .post("/resource")
    .consumes("application/json")
    .produces("application/json")
    .to("direct:createResource")
```

### Error Handling

Use Camel's error handling mechanisms to manage exceptions:

```groovy
onException(Exception.class)
    .handled(true)
    .setHeader(Exchange.HTTP_RESPONSE_CODE, constant(500))
    .setBody(simple("{ \"error\": \"${exception.message}\" }"))
    .log(LoggingLevel.ERROR, "Error processing request: ${exception.message}")
```

## Testing

### Running Tests

The project includes several test scripts:

- `test-app.ps1`: Comprehensive test suite for all components
- `test-api.ps1`: Tests only the REST API endpoints
- `test-email.ps1`: Tests email processing functionality

To run tests:

```powershell
# Run all tests
.\test-app.ps1

# Run specific test suite
.\test-api.ps1
```

### Manual Testing

For manual testing:

1. Use the MailHog UI (http://localhost:8026) to send test emails
2. Use curl or Postman to test REST API endpoints
3. Check the SQLite database through Adminer (http://localhost:8081)

## Deployment

### Production Deployment

For production deployment:

1. Create a production `.env` file with appropriate settings
2. Use a real email server instead of MailHog
3. Configure proper security settings (TLS, authentication, etc.)
4. Consider using a more robust database solution
5. Set up monitoring and alerting

### Scaling

To scale the application:

1. Use a container orchestration system like Kubernetes
2. Separate components into individual services
3. Implement a message queue for email processing
4. Use a clustered database solution

### Backup and Recovery

1. Regularly backup the SQLite database
2. Implement a backup rotation strategy
3. Test recovery procedures periodically

```bash
# Example backup script
docker exec camel-groovy-email-llm sqlite3 /data/emails.db ".backup '/data/backups/emails_$(date +%Y%m%d).db'"
```
