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
