// OllamaDirectRoute.groovy
// Dynamically loaded Camel route for direct interaction with Ollama LLM

import org.apache.camel.builder.RouteBuilder

class OllamaDirectRoute extends RouteBuilder {
    @Override
    void configure() throws Exception {
        // Define REST endpoints for direct LLM analysis
        rest("/api/llm")
            .post("/direct-analyze")
            .consumes("application/json")
            .produces("application/json")
            .to("direct:analyzeLLM")

        // Route for direct LLM text analysis
        from("direct:analyzeLLM")
            .log("Analyzing text with LLM: ${body}")
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
            .to("http://${ollama.host:localhost}:11434/api/generate")
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
                    timestamp: new Date().toString()
                ]
            }
            .marshal().json()
    }
}
