import org.apache.camel.CamelContext
import org.apache.camel.builder.RouteBuilder
import org.springframework.beans.factory.annotation.Value
import org.springframework.stereotype.Component
import groovy.json.JsonOutput
import groovy.json.JsonSlurper
import java.time.LocalDateTime
import java.time.format.DateTimeFormatter

/**
 * Trasa do bezpośredniej integracji Ollama LLM do analizy emaili.
 *
 * Ten plik można umieścić w katalogu routes i zostanie automatycznie załadowany.
 * Pokazuje elastyczność Camel z Groovy - można dynamicznie dodawać trasy.
 */

// Dostęp do zmiennych z pliku .env
def ollamaHost = System.getenv('OLLAMA_HOST') ?: 'ollama:11434'
def ollamaModel = System.getenv('OLLAMA_MODEL') ?: 'mistral'

// Definiowanie trasy
def route = {
    // Endpoint REST API dla bezpośredniej analizy tekstu przez LLM
    rest('/llm')
        .post('/direct-analyze')
            .description('Bezpośrednia analiza tekstu za pomocą LLM')
            .consumes('application/json')
            .produces('application/json')
            .type(Map.class)
            .outType(Map.class)
            .route()
                .process { exchange ->
                    def body = exchange.getIn().getBody(Map.class)
                    def text = body.text
                    def context = body.context ?: ""

                    // Przygotowanie zapytania dla Ollama
                    def prompt = """
                    Przeanalizuj poniższy tekst i udziel odpowiedzi:

                    === TEKST ===
                    ${text}

                    ${context ? "=== KONTEKST ===\n${context}" : ""}

                    Odpowiedz w formacie JSON z następującymi polami:
                    {
                      "keyTopics": ["temat1", "temat2"],
                      "sentiment": "positive/neutral/negative",
                      "summary": "krótkie podsumowanie",
                      "tags": ["tag1", "tag2"],
                      "suggestions": ["sugestia1", "sugestia2"]
                    }
                    """

                    // Przygotowanie requestu do Ollama
                    def requestBody = [
                        model: ollamaModel,
                        prompt: prompt,
                        stream: false
                    ]

                    exchange.getIn().setBody(JsonOutput.toJson(requestBody))
                    exchange.getIn().setHeader('CamelHttpMethod', 'POST')
                    exchange.getIn().setHeader('Content-Type', 'application/json')
                }
                .to("http://${ollamaHost}/api/generate")
                .unmarshal().json()
                .process { exchange ->
                    def response = exchange.getIn().getBody(Map.class)
                    def jsonSlurper = new JsonSlurper()
                    def result

                    try {
                        // Próba parsowania JSON z odpowiedzi LLM
                        result = jsonSlurper.parseText(response.response)
                    } catch (Exception e) {
                        // Jeśli odpowiedź nie jest poprawnym JSON, zwróć surową odpowiedź
                        result = [
                            raw_response: response.response,
                            processed: false,
                            error: "Nie można sparsować odpowiedzi jako JSON",
                            timestamp: LocalDateTime.now().format(DateTimeFormatter.ISO_LOCAL_DATE_TIME)
                        ]
                    }

                    exchange.getIn().setBody([
                        result: result,
                        model: response.model,
                        processing_time: response.processing_time,
                        timestamp: LocalDateTime.now().format(DateTimeFormatter.ISO_LOCAL_DATE_TIME)
                    ])
                }
            .endRest()
}

// Zwrócenie definicji trasy do automatycznego załadowania
return route