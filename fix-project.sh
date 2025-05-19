#!/bin/bash
# Script to update the project files

# Colors for output
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

# Function to create a file with content
create_file() {
    local file_path="$1"
    local content="$2"

    # Create directory if it doesn't exist
    mkdir -p "$(dirname "$file_path")"

    # Write content to file
    echo "$content" > "$file_path"

    echo -e "${BLUE}[INFO]${NC} Created file: $file_path"
}

echo -e "${BLUE}[INFO]${NC} Setting up project files..."

# Create directory structure if it doesn't exist
mkdir -p camel-groovy/src/main/groovy/com/example/emailllm
mkdir -p camel-groovy/src/main/resources
mkdir -p camel-groovy/routes

# Update build.gradle
cat > camel-groovy/build.gradle << 'EOL'
plugins {
    id 'groovy'
    id 'org.springframework.boot' version '3.2.0'
    id 'io.spring.dependency-management' version '1.1.4'
}

group = 'com.example'
version = '0.1.0-SNAPSHOT'
sourceCompatibility = '17'

repositories {
    mavenCentral()
}

ext {
    camelVersion = '4.1.0'
}

configurations.all {
    resolutionStrategy {
        // Force all Groovy modules to use Apache Groovy 4.0.15 version
        force 'org.apache.groovy:groovy:4.0.15'
        force 'org.apache.groovy:groovy-json:4.0.15'
        force 'org.apache.groovy:groovy-xml:4.0.15'
    }
}

dependencies {
    // Spring Boot
    implementation 'org.springframework.boot:spring-boot-starter-web'
    implementation 'org.springframework.boot:spring-boot-starter-actuator'
    implementation 'org.springframework.boot:spring-boot-starter-mail'

    // Groovy - use Apache Groovy 4.x instead of Codehaus Groovy 3.x
    implementation 'org.apache.groovy:groovy-all:4.0.15'

    // Apache Camel
    implementation "org.apache.camel.springboot:camel-spring-boot-starter:${camelVersion}"
    implementation "org.apache.camel.springboot:camel-groovy-starter:${camelVersion}"
    implementation "org.apache.camel.springboot:camel-mail-starter:${camelVersion}"
    implementation "org.apache.camel.springboot:camel-http-starter:${camelVersion}"
    implementation "org.apache.camel.springboot:camel-jdbc-starter:${camelVersion}"
    implementation "org.apache.camel.springboot:camel-sql-starter:${camelVersion}"
    implementation "org.apache.camel.springboot:camel-jackson-starter:${camelVersion}"
    implementation "org.apache.camel.springboot:camel-file-starter:${camelVersion}"
    implementation "org.apache.camel.springboot:camel-direct-starter:${camelVersion}"
    implementation "org.apache.camel.springboot:camel-stream-starter:${camelVersion}"
    implementation "org.apache.camel.springboot:camel-rest-starter:${camelVersion}"
    implementation "org.apache.camel.springboot:camel-servlet-starter:${camelVersion}"
    implementation "org.apache.camel.springboot:camel-quartz-starter:${camelVersion}"

    // Jakarta Mail API (for Jakarta EE 9+)
    implementation 'com.sun.mail:jakarta.mail:2.0.1'

    // SQLite
    implementation 'org.xerial:sqlite-jdbc:3.43.0.0'

    // Jackson for JSON processing
    implementation 'com.fasterxml.jackson.core:jackson-databind:2.15.2'
    implementation 'com.fasterxml.jackson.datatype:jackson-datatype-jsr310:2.15.2'

    // Commons
    implementation 'commons-io:commons-io:2.15.0'
    implementation 'org.apache.commons:commons-lang3:3.13.0'

    // Testing
    testImplementation 'org.springframework.boot:spring-boot-starter-test'
    testImplementation "org.apache.camel:camel-test-spring-junit5:${camelVersion}"
}

test {
    useJUnitPlatform()
}
EOL
echo -e "${BLUE}[INFO]${NC} Updated build.gradle"

# Create EmailLlmIntegrationApplication.groovy
cat > camel-groovy/src/main/groovy/com/example/emailllm/EmailLlmIntegrationApplication.groovy << 'EOL'
package com.example.emailllm

import org.springframework.boot.SpringApplication
import org.springframework.boot.autoconfigure.SpringBootApplication

@SpringBootApplication
class EmailLlmIntegrationApplication {
    static void main(String[] args) {
        SpringApplication.run(EmailLlmIntegrationApplication, args)
    }
}
EOL
echo -e "${BLUE}[INFO]${NC} Created EmailLlmIntegrationApplication.groovy"

# Create EmailProcessingRoute.groovy
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

        // Error handler route
        from("direct:errorHandler")
            .log(LoggingLevel.ERROR, "Error occurred: ${exception.message}")
            .setBody(simple("{\"error\": \"${exception.message}\", \"timestamp\": \"${date:now:yyyy-MM-dd'T'HH:mm:ss.SSSZ}\"}"))
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
echo -e "${BLUE}[INFO]${NC} Created EmailProcessingRoute.groovy"

# Create MaintenanceRoutes.groovy
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
            .setBody(simple("PRAGMA quick_check;"))
            .to("jdbc:dataSource")
            .log(LoggingLevel.INFO, "Database health check completed: ${body}")
            .setBody(simple("{\"status\":\"OK\",\"timestamp\":\"${date:now:yyyy-MM-dd'T'HH:mm:ss.SSSZ}\"}"))
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
            .setBody(simple("{\"status\":\"Database optimized\",\"timestamp\":\"${date:now:yyyy-MM-dd'T'HH:mm:ss.SSSZ}\"}"))
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
echo -e "${BLUE}[INFO]${NC} Created MaintenanceRoutes.groovy"

# Create RestApiConfig.groovy
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
echo -e "${BLUE}[INFO]${NC} Created RestApiConfig.groovy"

# Create application.yml
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
        include: health,info
  endpoint:
    health:
      show-details: always

# Logging configuration
logging:
  level:
    root: INFO
    com.example.emailllm: DEBUG
    org.apache.camel: ${CAMEL_DEBUG:INFO}
EOL
echo -e "${BLUE}[INFO]${NC} Created application.yml"

# Create OllamaDirectRoute.groovy
cat > camel-groovy/routes/OllamaDirectRoute.groovy << 'EOL'
// OllamaDirectRoute.groovy
// Dynamically loaded Camel route for direct interaction with Ollama LLM

import org.apache.camel.builder.RouteBuilder

class OllamaDirectRoute extends RouteBuilder {
    @Override
    void configure() throws Exception {
        // Define REST endpoints for direct LLM analysis
        rest("/api/llm")
            .post("/direct-analyze")
            .consumes("application/json")
            .produces("application/json")
            .to("direct:analyzeLLM")

        // Route for direct LLM text analysis
        from("direct:analyzeLLM")
            .log("Analyzing text with LLM: ${body}")
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
            .to("http://${ollama.host:localhost}:11434/api/generate")
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
                    timestamp: new Date().toString()
                ]
            }
            .marshal().json()
    }
}
EOL
echo -e "${BLUE}[INFO]${NC} Created OllamaDirectRoute.groovy"

echo -e "${GREEN}[SUKCES]${NC} All project files have been created successfully."
echo ""
echo -e "${YELLOW}Now try running:${NC}"
echo -e "  ${BLUE}./start.sh${NC}"

chmod +x fix-project.sh