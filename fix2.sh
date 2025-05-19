#!/bin/bash
# Master fix script for Email-LLM Integration project

GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

echo -e "${BLUE}[INFO]${NC} Starting comprehensive fix for Email-LLM Integration..."

# Create directory structure if it doesn't exist
mkdir -p camel-groovy/src/main/groovy/com/example/emailllm
mkdir -p camel-groovy/src/main/resources
mkdir -p camel-groovy/routes

# 1. Fix EmailLlmIntegrationApplication.groovy
echo -e "${BLUE}[INFO]${NC} Updating EmailLlmIntegrationApplication.groovy..."
cat > camel-groovy/src/main/groovy/com/example/emailllm/EmailLlmIntegrationApplication.groovy << 'EOL'
package com.example.emailllm

import org.springframework.boot.SpringApplication
import org.springframework.boot.autoconfigure.SpringBootApplication
import org.springframework.context.annotation.Bean
import org.springframework.context.annotation.ComponentScan
import org.springframework.beans.factory.annotation.Value
import javax.sql.DataSource
import org.springframework.jdbc.datasource.DriverManagerDataSource

@SpringBootApplication
@ComponentScan(["com.example.emailllm"])
class EmailLlmIntegrationApplication {

    static void main(String[] args) {
        SpringApplication.run(EmailLlmIntegrationApplication, args)
    }

    // SQLite DataSource configuration
    @Bean
    DataSource dataSource(
            @Value('${SQLITE_DB_PATH:/data/emails.db}') String sqliteDatabasePath,
            @Value('${SQLITE_CONNECTION_TIMEOUT:30}') int connectionTimeout) {

        String jdbcUrl = "jdbc:sqlite:" + sqliteDatabasePath
        println "Initializing SQLite DataSource: ${jdbcUrl}"

        def dataSource = new DriverManagerDataSource()
        dataSource.driverClassName = "org.sqlite.JDBC"
        dataSource.url = jdbcUrl

        // Connection settings
        dataSource.connectionProperties.setProperty("journal_mode", "WAL")
        dataSource.connectionProperties.setProperty("synchronous", "NORMAL")
        dataSource.connectionProperties.setProperty("cache_size", "-102400")
        dataSource.connectionProperties.setProperty("temp_store", "MEMORY")
        dataSource.connectionProperties.setProperty("busy_timeout", String.valueOf(connectionTimeout * 1000))

        return dataSource
    }
}
EOL
echo -e "${GREEN}[SUCCESS]${NC} Updated EmailLlmIntegrationApplication.groovy"

# 2. Fix EmailProcessingRoute.groovy
echo -e "${BLUE}[INFO]${NC} Fixing EmailProcessingRoute.groovy..."
cat > camel-groovy/src/main/groovy/com/example/emailllm/EmailProcessingRoute.groovy << 'EOL'
package com.example.emailllm

import org.apache.camel.builder.RouteBuilder
import org.apache.camel.Exchange
import org.apache.camel.LoggingLevel
import org.apache.camel.component.jackson.JacksonDataFormat
import org.springframework.stereotype.Component
import java.time.LocalDateTime
import java.time.format.DateTimeFormatter

/**
 * Main route configuration for email processing in the Email-LLM Integration system.
 */
@Component
class EmailProcessingRoute extends RouteBuilder {
    @Override
    void configure() throws Exception {
        // Define error handling strategy
        errorHandler(deadLetterChannel("direct:errorHandler")
            .maximumRedeliveries(3)
            .redeliveryDelay(1000)
            .backOffMultiplier(2)
            .useOriginalMessage()
            .logRetryAttempted(true)
            .logExhausted(true)
            .logStackTrace(true))

        // Health check endpoint
        rest("/api")
            .get("/health")
            .produces("application/json")
            .route()
            .setBody(constant([
                status: "UP",
                timestamp: LocalDateTime.now().format(DateTimeFormatter.ISO_DATE_TIME),
                version: "0.1.0"
            ]))
            .endRest()

        // Endpoint for direct LLM analysis
        rest("/api/llm")
            .post("/direct-analyze")
            .consumes("application/json")
            .produces("application/json")
            .route()
            .to("direct:analyzeLLM")
            .endRest()

        // Endpoint to fetch emails
        rest("/api/emails")
            .get()
            .produces("application/json")
            .route()
            .to("direct:getEmails")
            .endRest()

        // Error handler route - FIXED VERSION
        from("direct:errorHandler")
            .log(LoggingLevel.ERROR, "Error occurred: ${exception.message}")
            .process { exchange ->
                def errorMessage = exchange.getProperty(Exchange.EXCEPTION_CAUGHT, Exception.class).message
                exchange.in.body = [
                    error: errorMessage,
                    timestamp: new Date().format("yyyy-MM-dd'T'HH:mm:ss.SSSZ")
                ]
            }
            .marshal().json()
            .setHeader(Exchange.CONTENT_TYPE, constant("application/json"))
            .setHeader(Exchange.HTTP_RESPONSE_CODE, constant(500))

        // Get emails route
        from("direct:getEmails")
            .log("Fetching emails from database")
            .setBody(constant("SELECT id, message_id, subject, sender, recipients, received_date, processed_date, status, llm_analysis FROM processed_emails ORDER BY received_date DESC LIMIT 50"))
            .to("jdbc:dataSource")
            .process { exchange ->
                def emails = exchange.in.body.collect { row ->
                    def analysis = row.llm_analysis ? new groovy.json.JsonSlurper().parseText(row.llm_analysis) : [:]
                    [
                        id: row.id,
                        messageId: row.message_id,
                        subject: row.subject,
                        sender: row.sender,
                        recipients: row.recipients,
                        receivedDate: row.received_date,
                        processedDate: row.processed_date,
                        status: row.status,
                        analysis: analysis
                    ]
                }
                exchange.in.body = [
                    emails: emails,
                    total: emails.size(),
                    timestamp: LocalDateTime.now().format(DateTimeFormatter.ISO_DATE_TIME)
                ]
            }

        // LLM analysis route
        from("direct:analyzeLLM")
            .log("Analyzing text with LLM")
            .process { exchange ->
                def requestBody = exchange.in.body
                def text = requestBody.text ?: ""
                def context = requestBody.context ?: ""

                // Prepare prompt for the LLM
                def prompt = """
                Analyze the following message and provide insights:

                MESSAGE: "${text}"

                CONTEXT: "${context}"

                Provide analysis in JSON format with the following structure:
                {
                  "intent": "",       // The primary intent of the message
                  "sentiment": "",    // Positive, negative, or neutral
                  "priority": "",     // High, medium, or low
                  "topics": [],       // List of main topics
                  "suggestedResponse": ""  // Brief suggested response
                }
                """

                exchange.in.body = [
                    model: System.getenv("OLLAMA_MODEL") ?: "mistral",
                    prompt: prompt
                ]
            }
            .marshal().json()
            .removeHeaders("CamelHttp*")
            .setHeader("Content-Type", constant("application/json"))
            // Call Ollama API
            .toD("http://${System.getenv('OLLAMA_HOST') ?: 'ollama:11434'}/api/generate")
            .unmarshal().json()
            // Extract response
            .process { exchange ->
                def response = exchange.in.body
                def responseText = response.response ?: ""

                // Try to extract JSON from response
                def jsonStart = responseText.indexOf('{')
                def jsonEnd = responseText.lastIndexOf('}')

                if (jsonStart >= 0 && jsonEnd >= 0) {
                    responseText = responseText.substring(jsonStart, jsonEnd + 1)
                }

                exchange.in.body = [
                    analysis: responseText,
                    model: System.getenv("OLLAMA_MODEL") ?: "mistral",
                    timestamp: LocalDateTime.now().format(DateTimeFormatter.ISO_DATE_TIME)
                ]
            }
    }
}
EOL
echo -e "${GREEN}[SUCCESS]${NC} Fixed EmailProcessingRoute.groovy"

# 3. Fix MaintenanceRoutes.groovy
echo -e "${BLUE}[INFO]${NC} Fixing MaintenanceRoutes.groovy..."
cat > camel-groovy/src/main/groovy/com/example/emailllm/MaintenanceRoutes.groovy << 'EOL'
package com.example.emailllm

import org.apache.camel.builder.RouteBuilder
import org.apache.camel.LoggingLevel
import org.springframework.stereotype.Component
import java.time.LocalDateTime
import java.time.format.DateTimeFormatter

/**
 * Maintenance routes for scheduled jobs and system maintenance tasks
 */
@Component
class MaintenanceRoutes extends RouteBuilder {
    @Override
    void configure() throws Exception {
        // Scheduled health check
        from("quartz:maintenance/healthCheck?cron=0+0/30+*+*+*+?")
            .routeId("scheduledHealthCheck")
            .log(LoggingLevel.INFO, "Running scheduled health check")
            .setBody(constant("PRAGMA quick_check;"))
            .to("jdbc:dataSource")
            .log(LoggingLevel.INFO, "Database health check completed: ${body}")
            .process { exchange ->
                exchange.in.body = [
                    status: "OK",
                    timestamp: new Date().format("yyyy-MM-dd'T'HH:mm:ss.SSSZ")
                ]
            }
            .marshal().json()
            .to("direct:logMaintenance")

        // Maintenance logging
        from("direct:logMaintenance")
            .routeId("maintenanceLogger")
            .log(LoggingLevel.DEBUG, "Maintenance operation: ${body}")

        // Regular database optimization
        from("quartz:maintenance/dbOptimize?cron=0+0+0+*+*+?") // Daily at midnight
            .routeId("dbOptimizer")
            .log(LoggingLevel.INFO, "Running database optimization")
            .process { exchange ->
                def queries = [
                    "PRAGMA analyze;",
                    "PRAGMA optimize;",
                    "VACUUM;"
                ]
                exchange.in.body = queries
            }
            .split(body())
            .to("jdbc:dataSource")
            .end()
            .process { exchange ->
                exchange.in.body = [
                    status: "Database optimized",
                    timestamp: new Date().format("yyyy-MM-dd'T'HH:mm:ss.SSSZ")
                ]
            }
            .marshal().json()
            .to("direct:logMaintenance")

        // API documentation endpoint
        rest("/api")
            .get("/api-doc")
            .produces("application/json")
            .route()
            .process { exchange ->
                exchange.in.body = [
                    name: "Email-LLM Integration API",
                    version: "0.1.0",
                    description: "API for Email-LLM Integration with Apache Camel and Groovy",
                    endpoints: [
                        [path: "/api/health", method: "GET", description: "Health check endpoint"],
                        [path: "/api/emails", method: "GET", description: "Get processed emails"],
                        [path: "/api/llm/direct-analyze", method: "POST", description: "Direct LLM analysis"]
                    ],
                    timestamp: LocalDateTime.now().format(DateTimeFormatter.ISO_DATE_TIME)
                ]
            }
            .marshal().json()
            .endRest()
    }
}
EOL
echo -e "${GREEN}[SUCCESS]${NC} Fixed MaintenanceRoutes.groovy"

# 4. Create RestApiConfig.groovy
echo -e "${BLUE}[INFO]${NC} Creating RestApiConfig.groovy..."
cat > camel-groovy/src/main/groovy/com/example/emailllm/RestApiConfig.groovy << 'EOL'
package com.example.emailllm

import org.apache.camel.builder.RouteBuilder
import org.apache.camel.model.rest.RestBindingMode
import org.springframework.stereotype.Component

/**
 * REST API configuration for Email-LLM Integration system
 */
@Component
class RestApiConfig extends RouteBuilder {
    @Override
    void configure() throws Exception {
        // Configure REST DSL
        restConfiguration()
            .contextPath("/api")
            .apiContextPath("/api-docs")
            .apiProperty("api.title", "Email-LLM Integration API")
            .apiProperty("api.version", "0.1.0")
            .apiProperty("cors", "true")
            .bindingMode(RestBindingMode.json)
            .dataFormatProperty("prettyPrint", "true")
            .enableCORS(true)
    }
}
EOL
echo -e "${GREEN}[SUCCESS]${NC} Created RestApiConfig.groovy"

# 5. Fix application.yml
echo -e "${BLUE}[INFO]${NC} Updating application.yml..."
cat > camel-groovy/src/main/resources/application.yml << 'EOL'
spring:
  application:
    name: email-llm-integration
  datasource:
    url: jdbc:sqlite:${SQLITE_DB_PATH:/data/emails.db}
    driver-class-name: org.sqlite.JDBC
  mail:
    host: ${EMAIL_HOST:test-smtp.example.com}
    port: ${EMAIL_PORT:587}
    username: ${EMAIL_USER:test@example.com}
    password: ${EMAIL_PASSWORD:test_password}
    properties:
      mail:
        smtp:
          auth: true
          starttls:
            enable: ${EMAIL_USE_TLS:true}

server:
  port: ${SERVER_PORT:8080}
  servlet:
    context-path: /

# Camel configuration
camel:
  springboot:
    main-run-controller: true
  component:
    servlet:
      mapping:
        context-path: /api/*
    http:
      connection-request-timeout: 30000
      connection-timeout: 30000
      socket-timeout: 60000
  dataformat:
    json:
      library: jackson
  routes:
    include-pattern: classpath:routes/*.groovy
    reload-directory: ${CAMEL_ROUTES_RELOAD_DIRECTORY:/app/routes}
  stream:
    cache:
      enabled: ${CAMEL_STREAM_CACHE_ENABLED:true}

# Actuator endpoints
management:
  endpoints:
    web:
      exposure:
        include: health,info,camelroutes
  endpoint:
    health:
      show-details: always
    camelroutes:
      enabled: true
      read-only: false

# Logging configuration
logging:
  level:
    root: INFO
    com.example.emailllm: DEBUG
    org.apache.camel: ${CAMEL_DEBUG:INFO}
EOL
echo -e "${GREEN}[SUCCESS]${NC} Updated application.yml"

# 6. Create dynamic Ollama route
echo -e "${BLUE}[INFO]${NC} Creating OllamaDirectRoute.groovy..."
cat > camel-groovy/routes/OllamaDirectRoute.groovy << 'EOL'
// OllamaDirectRoute.groovy
// Dynamically loaded Camel route for direct interaction with Ollama LLM

import org.apache.camel.builder.RouteBuilder

class OllamaDirectRoute extends RouteBuilder {
    @Override
    void configure() throws Exception {
        // Define REST endpoints for direct LLM analysis
        rest("/api/ollama")
            .post("/analyze")
            .consumes("application/json")
            .produces("application/json")
            .route()
            .to("direct:ollamaAnalyze")
            .endRest()

        // Route for direct LLM text analysis
        from("direct:ollamaAnalyze")
            .log("Analyzing text with Ollama LLM: ${body}")
            .process { exchange ->
                def requestBody = exchange.in.body
                def text = requestBody.text ?: ""
                def context = requestBody.context ?: ""
                def model = requestBody.model ?: System.getenv("OLLAMA_MODEL") ?: "mistral"

                // Prepare prompt for the LLM
                def prompt = """
                Analyze the following message and provide insights:

                MESSAGE: "${text}"

                CONTEXT: "${context}"

                Provide analysis in JSON format with the following structure:
                {
                  "intent": "",       // The primary intent of the message
                  "sentiment": "",    // Positive, negative, or neutral
                  "priority": "",     // High, medium, or low
                  "topics": [],       // List of main topics
                  "suggestedResponse": ""  // Brief suggested response
                }
                """

                exchange.in.body = [
                    model: model,
                    prompt: prompt
                ]
            }
            .marshal().json()
            .removeHeaders("CamelHttp*")
            .setHeader("Content-Type", constant("application/json"))
            // Call Ollama API
            .to("http://ollama:11434/api/generate")
            .unmarshal().json()
            // Extract response
            .process { exchange ->
                def response = exchange.in.body
                def responseText = response.response ?: ""

                // Try to extract JSON from response
                def jsonStart = responseText.indexOf('{')
                def jsonEnd = responseText.lastIndexOf('}')

                if (jsonStart >= 0 && jsonEnd >= 0) {
                    responseText = responseText.substring(jsonStart, jsonEnd + 1)
                }

                exchange.in.body = [
                    analysis: responseText,
                    model: response.model ?: System.getenv("OLLAMA_MODEL") ?: "mistral",
                    timestamp: new Date().format("yyyy-MM-dd'T'HH:mm:ss.SSSZ")
                ]
            }
            .marshal().json()
    }
}
EOL
echo -e "${GREEN}[SUCCESS]${NC} Created OllamaDirectRoute.groovy"

# 7. Create improved start.sh script
echo -e "${BLUE}[INFO]${NC} Creating improved start.sh script..."
cat > start.sh << 'EOL'
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
EOL
chmod +x start.sh
echo -e "${GREEN}[SUCCESS]${NC} Created improved start.sh script"

echo -e "${GREEN}[ALL FIXES COMPLETE]${NC} Project files have been fixed."
echo ""
echo -e "${YELLOW}[NEXT STEPS]${NC} Try starting the system:"
echo -e "${BLUE}./start.sh${NC}"

# Make the script executable
chmod +x "$0"