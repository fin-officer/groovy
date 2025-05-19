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
                .setBody().constant("PRAGMA quick_check;")
                .to("jdbc:dataSource")
                .log(LoggingLevel.INFO, "Database health check completed")
                // Fixed to remove body reference in string interpolation
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
                .log(LoggingLevel.DEBUG, "Maintenance operation completed")
                // Changed to static message to avoid body reference issue

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
                .split().body()
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
        rest().get("/api/api-doc")
                .produces("application/json")
                .to("direct:apiDoc")

        from("direct:apiDoc")
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
    }
}