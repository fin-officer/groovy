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
                .component("servlet")
                .bindingMode(RestBindingMode.json)
                .dataFormatProperty("prettyPrint", "true")
                .apiContextPath("/api-docs")
                .apiProperty("api.title", "Email-LLM Integration API")
                .apiProperty("api.version", "0.1.0")
                .apiProperty("cors", "true")
                .host("localhost:" + serverPort)
                .contextPath("/")
                .enableCORS(true)
    }
}