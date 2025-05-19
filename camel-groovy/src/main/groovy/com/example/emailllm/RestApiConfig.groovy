/*
import org.apache.camel.builder.RouteBuilder
import org.apache.camel.model.rest.RestBindingMode
import org.springframework.beans.factory.annotation.Value
import org.springframework.stereotype.Component

 */
/**
 * Konfiguracja REST API za pomocą Groovy.
 *//*

@Component
class RestApiConfig extends RouteBuilder {
    @Value('${server.port:8080}')
    int serverPort

    @Value('${camel.component.servlet.mapping.context-path:/api */
/*}')
    String contextPath

    @Override
    void configure() throws Exception {
        // Konfiguracja komponentu REST DSL
        restConfiguration()
            .component("servlet")
            .bindingMode(RestBindingMode.json)
            .dataFormatProperty("prettyPrint", "true")
            .port(serverPort)
            .contextPath(contextPath)
            // Konfiguracja OpenAPI
            .apiContextPath("/api-doc")
            .apiProperty("api.title", "Email LLM Integration API")
            .apiProperty("api.version", "1.0.0")
            .apiProperty("api.description", "REST API dla integracji email z modelami LLM")
            .apiProperty("cors", "true")

        // Rest API do obsługi emaili
        rest("/emails")
            .description("API do zarządzania emailami")
            .consumes("application/json")
            .produces("application/json")

            .get()
                .description("Pobierz listę emaili")
                .outType(List.class)
                .to("direct:getEmails")

            .get("/{id}")
                .description("Pobierz szczegóły emaila")
                .outType(Map.class)
                .to("direct:getEmailById")

            .post()
                .description("Utwórz nowy email")
                .type(Map.class)
                .outType(Map.class)
                .to("direct:createEmail")

        // Rest API do obsługi LLM
        rest("/llm")
            .description("API do operacji LLM")
            .consumes("application/json")
            .produces("application/json")

            .post("/analyze")
                .description("Analizuj tekst za pomocą LLM")
                .type(Map.class)
                .outType(Map.class)
                .to("direct:analyzeLLM")

        // Endpoint zdrowia aplikacji
        rest("/health")
            .get()
                .produces("application/json")
                .route()
                .setBody(constant([status: "UP", time: new Date().format("yyyy-MM-dd HH:mm:ss")]))
                .endRest()
    }
} */

import org.apache.camel.builder.RouteBuilder
import org.apache.camel.model.rest.RestBindingMode
import org.springframework.beans.factory.annotation.Value
import org.springframework.stereotype.Component

/**
 * Konfiguracja REST API za pomocą Groovy.
 */
@Component
class RestApiConfig extends RouteBuilder {
    @Value('${server.port:8080}')
    int serverPort

    @Value('${camel.component.servlet.mapping.context-path:/api/*}')
    String contextPath

    @Override
    void configure() throws Exception {
        // Konfiguracja komponentu REST DSL
        restConfiguration()
            .component("servlet")
            .bindingMode(RestBindingMode.json)
            .dataFormatProperty("prettyPrint", "true")
            .port(serverPort)
            .contextPath(contextPath)
            // Konfiguracja OpenAPI
            .apiContextPath("/api-doc")
            .apiProperty("api.title", "Email LLM Integration API")
            .apiProperty("api.version", "1.0.0")
            .apiProperty("api.description", "REST API dla integracji email z modelami LLM")
            .apiProperty("cors", "true")

        // Rest API do obsługi emaili
        rest("/emails")
            .description("API do zarządzania emailami")
            .consumes("application/json")
            .produces("application/json")

            .get()
                .description("Pobierz listę emaili")
                .outType(List)
                .to("direct:getEmails")

            .get("/{id}")
                .description("Pobierz szczegóły emaila")
                .outType(Map)
                .to("direct:getEmailById")

            .post()
                .description("Utwórz nowy email")
                .type(Map)
                .outType(Map)
                .to("direct:createEmail")

        // Rest API do obsługi LLM
        rest("/llm")
            .description("API do operacji LLM")
            .consumes("application/json")
            .produces("application/json")

            .post("/analyze")
                .description("Analizuj tekst za pomocą LLM")
                .type(Map)
                .outType(Map)
                .to("direct:analyzeLLM")

        // Endpoint zdrowia aplikacji
        rest("/health")
            .get()
                .produces("application/json")
                .route()
                .setBody(constant([status: "UP", time: new Date().format("yyyy-MM-dd HH:mm:ss")]))
                .endRest()
    }
}