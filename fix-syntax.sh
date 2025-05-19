#!/bin/bash
# Quick fix script for EmailProcessingRoute.groovy

# Colors for output
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

echo -e "${BLUE}[INFO]${NC} Fixing the simple expression issue in EmailProcessingRoute.groovy..."

# Create directory structure if it doesn't exist
mkdir -p camel-groovy/src/main/groovy/com/example/emailllm

# Create a new fixed version of EmailProcessingRoute.groovy
cat > camel-groovy/src/main/groovy/com/example/emailllm/EmailProcessingRoute.groovy << 'EOL'
package com.example.emailllm

import org.apache.camel.builder.RouteBuilder
import org.apache.camel.Exchange
import org.apache.camel.LoggingLevel
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

# Also fix MaintenanceRoutes.groovy to be safe
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

# Show instructions
echo -e "${YELLOW}[NEXT STEPS]${NC} Try rebuilding and running the project:"
echo -e "${BLUE}./start.sh${NC}"

# Make the script executable
chmod +x "$0"