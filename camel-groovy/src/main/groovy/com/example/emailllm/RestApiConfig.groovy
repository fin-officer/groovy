package com.example.emailllm

import org.apache.camel.builder.RouteBuilder
import org.apache.camel.model.rest.RestBindingMode
import org.springframework.stereotype.Component
import org.springframework.beans.factory.annotation.Value

/**
 * REST API configuration for Email-LLM Integration system
 */
@Component
class RestApiConfig extends RouteBuilder {

    @Value('${SERVER_PORT:8080}')
    int serverPort

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
        // Dodanie szczegółów autentykacji dla Swagger UI (opcjonalnie)
                .apiProperty("api.description",
                        "API for Email-LLM Integration: Automated email processing with LLM analysis")
                .apiProperty("host", "localhost:" + serverPort)
                .apiProperty("schemes", "http")
        // Dodajemy logowanie błędów
                .onException(Exception.class)
                .handled(true)
                .logStackTrace(true)
                .logExhaustedMessageHistory(true)
                .logExhausted(true)
                .logHandled(true)
                .end()

        // Logowanie konfiguracji REST
        log.info("REST API configured on port: " + serverPort)
    }
}