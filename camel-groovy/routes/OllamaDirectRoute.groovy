// OllamaDirectRoute.groovy
// Dynamically loaded Camel route for direct interaction with Ollama LLM

import org.apache.camel.builder.RouteBuilder
import java.time.LocalDateTime
import java.time.format.DateTimeFormatter

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

                    def outputData = [:]

                    if (jsonStart >= 0 && jsonEnd >= 0) {
                        responseText = responseText.substring(jsonStart, jsonEnd + 1)

                        try {
                            // Try to validate JSON
                            new groovy.json.JsonSlurper().parseText(responseText)
                            outputData.status = "success"
                        } catch (Exception e) {
                            // If JSON is invalid
                            outputData.status = "error"
                            outputData.error = "Invalid JSON response: ${e.message}"
                        }
                    } else {
                        outputData.status = "error"
                        outputData.error = "No JSON found in response"
                    }

                    // Set the output
                    outputData.analysis = responseText
                    outputData.model = response.model ?: System.getenv("OLLAMA_MODEL") ?: "mistral"
                    outputData.timestamp = LocalDateTime.now().format(DateTimeFormatter.ISO_DATE_TIME)

                    exchange.in.body = outputData
                }
                .marshal().json()
                .log("Analysis completed with model: ${body.model}")
    }
}