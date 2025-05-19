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
        rest().get("/api/health")
                .produces("application/json")
                .to("direct:healthCheck")

        from("direct:healthCheck")
                .setBody().constant([
                status: "UP",
                timestamp: LocalDateTime.now().format(DateTimeFormatter.ISO_DATE_TIME),
                version: "0.1.0"
        ])

        // Endpoint for direct LLM analysis
        rest().post("/api/llm/direct-analyze")
                .consumes("application/json")
                .produces("application/json")
                .to("direct:analyzeLLM")

        // Endpoint to fetch emails
        rest().get("/api/emails")
                .produces("application/json")
                .to("direct:getEmails")

        // Error handler route - simplified to avoid variable access issues
        from("direct:errorHandler")
                .log(LoggingLevel.ERROR, "Error occurred in processing")
                .process { exchange ->
                    // Access the exception through the exchange property
                    def exception = exchange.getProperty(Exchange.EXCEPTION_CAUGHT, Exception.class)
                    def errorMessage = exception ? exception.getMessage() : "Unknown error"

                    exchange.getMessage().setBody([
                            error: errorMessage,
                            timestamp: new Date().format("yyyy-MM-dd'T'HH:mm:ss.SSSZ")
                    ])
                }
                .marshal().json()
                .setHeader(Exchange.CONTENT_TYPE, constant("application/json"))
                .setHeader(Exchange.HTTP_RESPONSE_CODE, constant(500))

        // Get emails route
        from("direct:getEmails")
                .log("Fetching emails from database")
                .setBody().constant("SELECT id, message_id, subject, sender, recipients, received_date, processed_date, status, llm_analysis FROM processed_emails ORDER BY received_date DESC LIMIT 50")
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
                .toD("http://${System.getenv('OLLAMA_HOST') ?: 'ollama'}:${System.getenv('OLLAMA_PORT') ?: '11434'}/api/generate")
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
                            timestamp: LocalDateTime.now().format(DateTimeFormatter.ISO_DATE_TIME)
                    ]
                }
    }
}