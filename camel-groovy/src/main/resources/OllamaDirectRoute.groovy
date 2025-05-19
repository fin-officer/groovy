// OllamaDirectRoute.groovy
// Dynamically loaded Camel route for direct interaction with Ollama LLM

import org.apache.camel.builder.RouteBuilder
import java.time.LocalDateTime
import java.time.format.DateTimeFormatter

/**
 * Dynamic route for direct interaction with Ollama LLM API
 */
class OllamaDirectRoute extends RouteBuilder {
    @Override
    void configure() throws Exception {
        // Define REST endpoints for direct LLM analysis
        rest("/api/llm")
                .post("/direct-analyze")
                .consumes("application/json")
                .produces("application/json")
                .route()
                .to("direct:analyzeLLM")
                .endRest()

        // Additional endpoint with clearer name
        rest("/api/ollama")
                .post("/analyze")
                .consumes("application/json")
                .produces("application/json")
                .route()
                .to("direct:analyzeLLM")
                .endRest()

        // Route for direct LLM text analysis
        from("direct:analyzeLLM")
                .log("Analyzing text with LLM: ${body}")
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
        // Call Ollama API using environment variable or fallback to service name
                .toD("http://${System.getenv('OLLAMA_HOST') ?: 'ollama'}:11434/api/generate")
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

                    try {
                        // Try to parse it as JSON to validate
                        def jsonSlurper = new groovy.json.JsonSlurper()
                        def parsedJson = jsonSlurper.parseText(responseText)

                        // Return the formatted response
                        exchange.in.body = [
                                analysis: responseText,
                                model: response.model ?: System.getenv("OLLAMA_MODEL") ?: "mistral",
                                timestamp: LocalDateTime.now().format(DateTimeFormatter.ISO_DATE_TIME),
                                status: "success"
                        ]
                    } catch (Exception e) {
                        // If parsing fails, return the raw response
                        exchange.in.body = [
                                rawResponse: responseText,
                                model: response.model ?: System.getenv("OLLAMA_MODEL") ?: "mistral",
                                timestamp: LocalDateTime.now().format(DateTimeFormatter.ISO_DATE_TIME),
                                status: "error",
                                error: "Failed to parse JSON response: ${e.message}"
                        ]
                    }
                }
                .marshal().json()
                .log("Analysis completed with model: ${body.model}")
    }
}