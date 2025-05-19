/*
import org.apache.camel.builder.RouteBuilder
import org.apache.camel.Exchange
import org.apache.camel.Processor
import org.apache.camel.component.mail.MailMessage
import org.apache.camel.LoggingLevel
import org.springframework.beans.factory.annotation.Value
import org.springframework.stereotype.Component
import groovy.json.JsonOutput
import groovy.json.JsonSlurper
import java.time.LocalDateTime
import java.time.format.DateTimeFormatter
import javax.mail.internet.MimeMessage
import javax.mail.internet.MimeMultipart
import javax.mail.BodyPart

 */
/**
 * Trasa procesowania emaili za pomocą Apache Camel w Groovy.
 *//*

@Component
class EmailProcessingRoute extends RouteBuilder {

    @Value('${email.host}')
    String emailHost

    @Value('${email.port}')
    int emailPort

    @Value('${email.user}')
    String emailUser

    @Value('${email.password}')
    String emailPassword

    @Value('${email.use.tls:false}')
    boolean emailUseTls

    @Value('${email.imap.host}')
    String imapHost

    @Value('${email.imap.port}')
    int imapPort

    @Value('${email.imap.folder:INBOX}')
    String imapFolder

    @Value('${email.polling.interval:60000}')
    int pollingInterval

    @Value('${sqlite.db.path}')
    String sqliteDbPath

    @Value('${ollama.host}')
    String ollamaHost

    @Value('${ollama.model}')
    String ollamaModel

    @Override
    void configure() throws Exception {

        // Obsługa błędów
        errorHandler(defaultErrorHandler()
            .logExhaustedMessageHistory(true)
            .maximumRedeliveries(3)
            .redeliveryDelay(1000)
            .backOffMultiplier(2)
            .useExponentialBackOff())

        // Pobieranie emaili z IMAP
        from("imaps://${imapHost}:${imapPort}?" +
             "username=${emailUser}&password=${emailPassword}&" +
             "folderName=${imapFolder}&unseen=true&" +
             "consumer.delay=${pollingInterval}")
            .routeId("email-polling")
            .log(LoggingLevel.INFO, "Odebrano nowy email: \${header.subject}")
            .process(new EmailExtractorProcessor())
            .to("direct:processEmail")

        // Przetwarzanie emaila
        from("direct:processEmail")
            .routeId("process-email")
            .log(LoggingLevel.INFO, "Przetwarzanie emaila: \${body.subject}")
            .setHeader("EmailData", simple("\${body}"))
            .setBody(simple("\${body.bodyText}"))
            .to("direct:analyzeLLM")
            .process(new EmailStoreProcessor())
            .choice()
                .when(simple("\${body.requiresResponse} == true"))
                    .to("direct:sendEmailResponse")
                .otherwise()
                    .log(LoggingLevel.INFO, "Email nie wymaga odpowiedzi")
            .end()

        // Analiza tekstu z użyciem LLM
        from("direct:analyzeLLM")
            .routeId("analyze-llm")
            .log(LoggingLevel.INFO, "Analiza tekstu za pomocą LLM")
            .process { exchange ->
                def emailData = exchange.getIn().getHeader("EmailData", Map.class)
                def bodyText = exchange.getIn().getBody(String.class)

                // Przygotowanie zapytania dla Ollama
                def prompt = """
                Przeanalizuj poniższą wiadomość email i:
                1. Wyodrębnij kluczowe informacje i tematy
                2. Określ priorytet i pilność
                3. Zidentyfikuj czy wymagane są działania lub odpowiedzi
                4. Zaproponuj krótką odpowiedź, jeśli jest potrzebna

                === WIADOMOŚĆ EMAIL ===
                Od: ${emailData.sender}
                Do: ${emailData.recipients}
                Temat: ${emailData.subject}
                Treść:
                ${bodyText}

                Odpowiedz w formacie JSON z następującymi polami:
                {
                  "keyTopics": ["temat1", "temat2"],
                  "priority": "high/medium/low",
                  "requiresResponse": true/false,
                  "actionRequired": true/false,
                  "summary": "krótkie podsumowanie",
                  "suggestedResponse": "proponowana odpowiedź jeśli jest potrzebna"
                }
                """

                // Przygotowanie requestu do Ollama
                def requestBody = [
                    model: ollamaModel,
                    prompt: prompt,
                    stream: false
                ]

                exchange.getIn().setBody(JsonOutput.toJson(requestBody))
                exchange.getIn().setHeader(Exchange.HTTP_METHOD, "POST")
                exchange.getIn().setHeader(Exchange.CONTENT_TYPE, "application/json")
            }
            .to("http://${ollamaHost}/api/generate")
            .unmarshal().json()
            .process { exchange ->
                def response = exchange.getIn().getBody(Map.class)
                def emailData = exchange.getIn().getHeader("EmailData", Map.class)

                def jsonSlurper = new JsonSlurper()
                def analysis

                try {
                    // Próba parsowania JSON z odpowiedzi LLM
                    analysis = jsonSlurper.parseText(response.response)
                } catch (Exception e) {
                    // Jeśli odpowiedź nie jest poprawnym JSON, użyj heurystyki do ekstrakcji danych
                    analysis = [
                        keyTopics: [],
                        priority: "medium",
                        requiresResponse: false,
                        actionRequired: false,
                        summary: response.response.take(200),
                        suggestedResponse: ""
                    ]

                    def responseText = response.response.toLowerCase()

                    if (responseText.contains("wysoki priorytet") || responseText.contains("high priority")) {
                        analysis.priority = "high"
                    } else if (responseText.contains("niski priorytet") || responseText.contains("low priority")) {
                        analysis.priority = "low"
                    }

                    if (responseText.contains("wymaga odpowiedzi") || responseText.contains("response required")) {
                        analysis.requiresResponse = true
                    }

                    if (responseText.contains("wymaga działania") || responseText.contains("action required")) {
                        analysis.actionRequired = true
                    }
                }

                // Połącz dane emaila z analizą LLM
                emailData.llmAnalysis = JsonOutput.toJson(analysis)
                emailData.status = "processed"
                emailData.processedDate = LocalDateTime.now().format(DateTimeFormatter.ISO_LOCAL_DATE_TIME)

                exchange.getIn().setBody(emailData)
            }

        // Wysyłanie odpowiedzi email
        from("direct:sendEmailResponse")
            .routeId("send-email-response")
            .log(LoggingLevel.INFO, "Wysyłanie odpowiedzi na email: \${body.subject}")
            .process { exchange ->
                def emailData = exchange.getIn().getBody(Map.class)
                def analysis = new JsonSlurper().parseText(emailData.llmAnalysis)

                def responseBody = """
                Dziękuję za wiadomość.

                ${analysis.suggestedResponse ?: "Twoja wiadomość została odebrana i jest przetwarzana."}

                Pozdrawiam,
                System Email-LLM
                """

                // Przygotowanie parametrów do wysłania emaila
                exchange.getIn().setHeader("To", emailData.sender)
                exchange.getIn().setHeader("From", emailUser)
                exchange.getIn().setHeader("Subject", "Re: ${emailData.subject}")
                exchange.getIn().setBody(responseBody)
            }
            .to("smtp://${emailHost}:${emailPort}?username=${emailUser}&password=${emailPassword}&ssl=${emailUseTls}")
            .log(LoggingLevel.INFO, "Odpowiedź wysłana pomyślnie")

        // API do pobierania listy emaili
        from("direct:getEmails")
            .routeId("get-emails-api")
            .setBody(simple("SELECT id, message_id, subject, sender, recipients, received_date, processed_date, status FROM processed_emails ORDER BY received_date DESC LIMIT 100"))
            .to("jdbc:dataSource")
            .log(LoggingLevel.DEBUG, "Pobrano ${body.size()} emaili z bazy danych")

        // API do pobierania szczegółów emaila
        from("direct:getEmailById")
            .routeId("get-email-by-id-api")
            .setBody(simple("SELECT * FROM processed_emails WHERE id = ${header.id}"))
            .to("jdbc:dataSource")
            .process { exchange ->
                def results = exchange.getIn().getBody(List.class)
                if (results.isEmpty()) {
                    exchange.getIn().setHeader(Exchange.HTTP_RESPONSE_CODE, 404)
                    exchange.getIn().setBody([error: "Email not found"])
                } else {
                    exchange.getIn().setBody(results[0])
                }
            }
    }

     */
/**
     * Procesor do ekstrakcji danych z emaila.
     *//*

    static class EmailExtractorProcessor implements Processor {
        @Override
        void process(Exchange exchange) throws Exception {
            def mailMessage = exchange.getIn(MailMessage.class)
            def mimeMessage = mailMessage.mimeMessage

            def emailData = [
                messageId: mimeMessage.getMessageID(),
                subject: mimeMessage.getSubject(),
                sender: mimeMessage.getFrom()[0].toString(),
                recipients: mimeMessage.getAllRecipients()*.toString().join(", "),
                receivedDate: mimeMessage.getSentDate() ?
                              mimeMessage.getSentDate().toInstant()
                                  .atZone(java.time.ZoneId.systemDefault())
                                  .toLocalDateTime()
                                  .format(DateTimeFormatter.ISO_LOCAL_DATE_TIME) :
                              LocalDateTime.now().format(DateTimeFormatter.ISO_LOCAL_DATE_TIME),
                bodyText: extractTextFromMessage(mimeMessage),
                bodyHtml: extractHtmlFromMessage(mimeMessage),
                status: "pending",
                processedDate: null,
                llmAnalysis: null,
                metadata: "{}"
            ]

            exchange.getIn().setBody(emailData)
        }

         */
/**
         * Ekstrakcja tekstu z wiadomości.
         *//*

        private String extractTextFromMessage(MimeMessage mimeMessage) {
            try {
                def content = mimeMessage.getContent()
                if (content instanceof String) {
                    return content
                } else if (content instanceof MimeMultipart) {
                    return extractTextFromMultipart(content)
                }
            } catch (Exception e) {
                return "Nie można odczytać treści wiadomości: " + e.message
            }
            return ""
        }

         */
/**
         * Ekstrakcja HTML z wiadomości.
         *//*

        private String extractHtmlFromMessage(MimeMessage mimeMessage) {
            try {
                def content = mimeMessage.getContent()
                if (content instanceof MimeMultipart) {
                    return extractHtmlFromMultipart(content)
                }
            } catch (Exception e) {
                return ""
            }
            return ""
        }

         */
/**
         * Ekstrakcja tekstu z części multipart.
         *//*

        private String extractTextFromMultipart(MimeMultipart multipart) {
            StringBuilder result = new StringBuilder()
            int count = multipart.getCount()

            for (int i = 0; i < count; i++) {
                BodyPart bodyPart = multipart.getBodyPart(i)
                if (bodyPart.isMimeType("text/plain")) {
                    result.append(bodyPart.getContent())
                } else if (bodyPart.isMimeType("text/html")) {
                    // Jeśli nie znaleziono tekstu, użyj HTML
                    if (result.length() == 0) {
                        result.append(extractTextFromHtml(bodyPart.getContent().toString()))
                    }
                } else if (bodyPart.getContent() instanceof MimeMultipart) {
                    result.append(extractTextFromMultipart((MimeMultipart) bodyPart.getContent()))
                }
            }

            return result.toString()
        }

         */
/**
         * Ekstrakcja HTML z części multipart.
         *//*

        private String extractHtmlFromMultipart(MimeMultipart multipart) {
            int count = multipart.getCount()

            for (int i = 0; i < count; i++) {
                BodyPart bodyPart = multipart.getBodyPart(i)
                if (bodyPart.isMimeType("text/html")) {
                    return bodyPart.getContent().toString()
                } else if (bodyPart.getContent() instanceof MimeMultipart) {
                    String html = extractHtmlFromMultipart((MimeMultipart) bodyPart.getContent())
                    if (html) {
                        return html
                    }
                }
            }

            return ""
        }

         */
/**
         * Prosta konwersja HTML do tekstu.
         *//*

        private String extractTextFromHtml(String html) {
            return html.replaceAll("\\<.*?\\>", "")
                        .replaceAll("&nbsp;", " ")
                        .replaceAll("&lt;", "<")
                        .replaceAll("&gt;", ">")
                        .replaceAll("&amp;", "&")
        }
    }

     */
/**
     * Procesor do zapisania danych emaila w bazie SQLite.
     *//*

    static class EmailStoreProcessor implements Processor {
        @Override
        void process(Exchange exchange) throws Exception {
            def emailData = exchange.getIn().getBody(Map.class)

            // Przygotowanie zapytania SQL
            def sql = """
            INSERT INTO processed_emails
            (message_id, subject, sender, recipients, received_date, processed_date, body_text, body_html, status, llm_analysis, metadata)
            VALUES
            (:message_id, :subject, :sender, :recipients, :received_date, :processed_date, :body_text, :body_html, :status, :llm_analysis, :metadata)
            ON CONFLICT(message_id) DO UPDATE SET
            processed_date = :processed_date,
            status = :status,
            llm_analysis = :llm_analysis
            """

            // Parametry do zapytania SQL
            def parameters = [
                message_id: emailData.messageId,
                subject: emailData.subject,
                sender: emailData.sender,
                recipients: emailData.recipients,
                received_date: emailData.receivedDate,
                processed_date: emailData.processedDate,
                body_text: emailData.bodyText,
                body_html: emailData.bodyHtml ?: "",
                status: emailData.status,
                llm_analysis: emailData.llmAnalysis,
                metadata: emailData.metadata
            ]

            // Ustawienie parametrów dla zapytania SQL
            exchange.getIn().setHeader("CamelSqlQuery", sql)
            exchange.getIn().setHeader("CamelSqlParameters", parameters)
            exchange.getIn().setBody(parameters)

            // Wykonanie zapytania
            exchange.getIn().setHeader(Exchange.DESTINATION_OVERRIDE_URL, "sql:dummy?dataSource=dataSource")

            // Analiza JSON do decyzji o odpowiedzi
            def analysis = new JsonSlurper().parseText(emailData.llmAnalysis)
            emailData.requiresResponse = analysis.requiresResponse

            exchange.getIn().setBody(emailData)
        }
    }
} */

import org.apache.camel.builder.RouteBuilder
import org.apache.camel.Exchange
import org.apache.camel.Processor
import org.apache.camel.component.mail.MailMessage
import org.apache.camel.LoggingLevel
import org.springframework.beans.factory.annotation.Value
import org.springframework.stereotype.Component
import groovy.json.JsonOutput
import groovy.json.JsonSlurper
import java.time.LocalDateTime
import java.time.format.DateTimeFormatter
import javax.mail.internet.MimeMessage
import javax.mail.internet.MimeMultipart
import javax.mail.BodyPart

/**
 * Trasa procesowania emaili za pomocą Apache Camel w Groovy.
 */
@Component
class EmailProcessingRoute extends RouteBuilder {

    @Value('${email.host}')
    String emailHost

    @Value('${email.port}')
    int emailPort

    @Value('${email.user}')
    String emailUser

    @Value('${email.password}')
    String emailPassword

    @Value('${email.use.tls:false}')
    boolean emailUseTls

    @Value('${email.imap.host}')
    String imapHost

    @Value('${email.imap.port}')
    int imapPort

    @Value('${email.imap.folder:INBOX}')
    String imapFolder

    @Value('${email.polling.interval:60000}')
    int pollingInterval

    @Value('${sqlite.db.path}')
    String sqliteDbPath

    @Value('${ollama.host}')
    String ollamaHost

    @Value('${ollama.model}')
    String ollamaModel

    @Override
    void configure() throws Exception {

        // Obsługa błędów
        errorHandler(defaultErrorHandler()
            .logExhaustedMessageHistory(true)
            .maximumRedeliveries(3)
            .redeliveryDelay(1000)
            .backOffMultiplier(2)
            .useExponentialBackOff())

        // Pobieranie emaili z IMAP
        from("imaps://${imapHost}:${imapPort}?" +
             "username=${emailUser}&password=${emailPassword}&" +
             "folderName=${imapFolder}&unseen=true&" +
             "consumer.delay=${pollingInterval}")
            .routeId("email-polling")
            .log(LoggingLevel.INFO, "Odebrano nowy email: \${header.subject}")
            .process(new EmailExtractorProcessor())
            .to("direct:processEmail")

        // Przetwarzanie emaila
        from("direct:processEmail")
            .routeId("process-email")
            .log(LoggingLevel.INFO, "Przetwarzanie emaila: \${body.subject}")
            .setHeader("EmailData", simple("\${body}"))
            .setBody(simple("\${body.bodyText}"))
            .to("direct:analyzeLLM")
            .process(new EmailStoreProcessor())
            .choice()
                .when(simple("\${body.requiresResponse} == true"))
                    .to("direct:sendEmailResponse")
                .otherwise()
                    .log(LoggingLevel.INFO, "Email nie wymaga odpowiedzi")
            .end()

        // Analiza tekstu z użyciem LLM
        from("direct:analyzeLLM")
            .routeId("analyze-llm")
            .log(LoggingLevel.INFO, "Analiza tekstu za pomocą LLM")
            .process { exchange ->
                def emailData = exchange.getIn().getHeader("EmailData", Map.class)
                def bodyText = exchange.getIn().getBody(String.class)

                // Przygotowanie zapytania dla Ollama
                def prompt = """
                Przeanalizuj poniższą wiadomość email i:
                1. Wyodrębnij kluczowe informacje i tematy
                2. Określ priorytet i pilność
                3. Zidentyfikuj czy wymagane są działania lub odpowiedzi
                4. Zaproponuj krótką odpowiedź, jeśli jest potrzebna

                === WIADOMOŚĆ EMAIL ===
                Od: ${emailData.sender}
                Do: ${emailData.recipients}
                Temat: ${emailData.subject}
                Treść:
                ${bodyText}

                Odpowiedz w formacie JSON z następującymi polami:
                {
                  "keyTopics": ["temat1", "temat2"],
                  "priority": "high/medium/low",
                  "requiresResponse": true/false,
                  "actionRequired": true/false,
                  "summary": "krótkie podsumowanie",
                  "suggestedResponse": "proponowana odpowiedź jeśli jest potrzebna"
                }
                """

                // Przygotowanie requestu do Ollama
                def requestBody = [
                    model: ollamaModel,
                    prompt: prompt,
                    stream: false
                ]

                exchange.getIn().setBody(JsonOutput.toJson(requestBody))
                exchange.getIn().setHeader(Exchange.HTTP_METHOD, "POST")
                exchange.getIn().setHeader(Exchange.CONTENT_TYPE, "application/json")
            }
            .to("http://${ollamaHost}/api/generate")
            .unmarshal().json()
            .process { exchange ->
                def response = exchange.getIn().getBody(Map.class)
                def emailData = exchange.getIn().getHeader("EmailData", Map.class)

                def jsonSlurper = new JsonSlurper()
                def analysis

                try {
                    // Próba parsowania JSON z odpowiedzi LLM
                    analysis = jsonSlurper.parseText(response.response)
                } catch (Exception e) {
                    // Jeśli odpowiedź nie jest poprawnym JSON, użyj heurystyki do ekstrakcji danych
                    analysis = [
                        keyTopics: [],
                        priority: "medium",
                        requiresResponse: false,
                        actionRequired: false,
                        summary: response.response.take(200),
                        suggestedResponse: ""
                    ]

                    def responseText = response.response.toLowerCase()

                    if (responseText.contains("wysoki priorytet") || responseText.contains("high priority")) {
                        analysis.priority = "high"
                    } else if (responseText.contains("niski priorytet") || responseText.contains("low priority")) {
                        analysis.priority = "low"
                    }

                    if (responseText.contains("wymaga odpowiedzi") || responseText.contains("response required")) {
                        analysis.requiresResponse = true
                    }

                    if (responseText.contains("wymaga działania") || responseText.contains("action required")) {
                        analysis.actionRequired = true
                    }
                }

                // Połącz dane emaila z analizą LLM
                emailData.llmAnalysis = JsonOutput.toJson(analysis)
                emailData.status = "processed"
                emailData.processedDate = LocalDateTime.now().format(DateTimeFormatter.ISO_LOCAL_DATE_TIME)

                exchange.getIn().setBody(emailData)
            }

        // Wysyłanie odpowiedzi email
        from("direct:sendEmailResponse")
            .routeId("send-email-response")
            .log(LoggingLevel.INFO, "Wysyłanie odpowiedzi na email: \${body.subject}")
            .process { exchange ->
                def emailData = exchange.getIn().getBody(Map.class)
                def analysis = new JsonSlurper().parseText(emailData.llmAnalysis)

                def responseBody = """
                Dziękuję za wiadomość.

                ${analysis.suggestedResponse ?: "Twoja wiadomość została odebrana i jest przetwarzana."}

                Pozdrawiam,
                System Email-LLM
                """

                // Przygotowanie parametrów do wysłania emaila
                exchange.getIn().setHeader("To", emailData.sender)
                exchange.getIn().setHeader("From", emailUser)
                exchange.getIn().setHeader("Subject", "Re: ${emailData.subject}")
                exchange.getIn().setBody(responseBody)
            }
            .to("smtp://${emailHost}:${emailPort}?username=${emailUser}&password=${emailPassword}&ssl=${emailUseTls}")
            .log(LoggingLevel.INFO, "Odpowiedź wysłana pomyślnie")

        // API do pobierania listy emaili
        from("direct:getEmails")
            .routeId("get-emails-api")
            .setBody(simple("SELECT id, message_id, subject, sender, recipients, received_date, processed_date, status FROM processed_emails ORDER BY received_date DESC LIMIT 100"))
            .to("jdbc:dataSource")
            .log(LoggingLevel.DEBUG, "Pobrano ${body.size()} emaili z bazy danych")

        // API do pobierania szczegółów emaila
        from("direct:getEmailById")
            .routeId("get-email-by-id-api")
            .setBody(simple("SELECT * FROM processed_emails WHERE id = ${header.id}"))
            .to("jdbc:dataSource")
            .process { exchange ->
                def results = exchange.getIn().getBody(List.class)
                if (results.isEmpty()) {
                    exchange.getIn().setHeader(Exchange.HTTP_RESPONSE_CODE, 404)
                    exchange.getIn().setBody([error: "Email not found"])
                } else {
                    exchange.getIn().setBody(results[0])
                }
            }
    }

    /**
     * Procesor do ekstrakcji danych z emaila.
     */
    static class EmailExtractorProcessor implements Processor {
        @Override
        void process(Exchange exchange) throws Exception {
            def mailMessage = exchange.getIn(MailMessage.class)
            def mimeMessage = mailMessage.mimeMessage

            def emailData = [
                messageId: mimeMessage.getMessageID(),
                subject: mimeMessage.getSubject(),
                sender: mimeMessage.getFrom()[0].toString(),
                recipients: mimeMessage.getAllRecipients()*.toString().join(", "),
                receivedDate: mimeMessage.getSentDate() ?
                              mimeMessage.getSentDate().toInstant()
                                  .atZone(java.time.ZoneId.systemDefault())
                                  .toLocalDateTime()
                                  .format(DateTimeFormatter.ISO_LOCAL_DATE_TIME) :
                              LocalDateTime.now().format(DateTimeFormatter.ISO_LOCAL_DATE_TIME),
                bodyText: extractTextFromMessage(mimeMessage),
                bodyHtml: extractHtmlFromMessage(mimeMessage),
                status: "pending",
                processedDate: null,
                llmAnalysis: null,
                metadata: "{}"
            ]

            exchange.getIn().setBody(emailData)
        }

        /**
         * Ekstrakcja tekstu z wiadomości.
         */
        private String extractTextFromMessage(MimeMessage mimeMessage) {
            try {
                def content = mimeMessage.getContent()
                if (content instanceof String) {
                    return content
                } else if (content instanceof MimeMultipart) {
                    return extractTextFromMultipart(content)
                }
            } catch (Exception e) {
                return "Nie można odczytać treści wiadomości: " + e.message
            }
            return ""
        }

        /**
         * Ekstrakcja HTML z wiadomości.
         */
        private String extractHtmlFromMessage(MimeMessage mimeMessage) {
            try {
                def content = mimeMessage.getContent()
                if (content instanceof MimeMultipart) {
                    return extractHtmlFromMultipart(content)
                }
            } catch (Exception e) {
                return ""
            }
            return ""
        }

        /**
         * Ekstrakcja tekstu z części multipart.
         */
        private String extractTextFromMultipart(MimeMultipart multipart) {
            StringBuilder result = new StringBuilder()
            int count = multipart.getCount()

            for (int i = 0; i < count; i++) {
                BodyPart bodyPart = multipart.getBodyPart(i)
                if (bodyPart.isMimeType("text/plain")) {
                    result.append(bodyPart.getContent())
                } else if (bodyPart.isMimeType("text/html")) {
                    // Jeśli nie znaleziono tekstu, użyj HTML
                    if (result.length() == 0) {
                        result.append(extractTextFromHtml(bodyPart.getContent().toString()))
                    }
                } else if (bodyPart.getContent() instanceof MimeMultipart) {
                    result.append(extractTextFromMultipart((MimeMultipart) bodyPart.getContent()))
                }
            }

            return result.toString()
        }

        /**
         * Ekstrakcja HTML z części multipart.
         */
        private String extractHtmlFromMultipart(MimeMultipart multipart) {
            int count = multipart.getCount()

            for (int i = 0; i < count; i++) {
                BodyPart bodyPart = multipart.getBodyPart(i)
                if (bodyPart.isMimeType("text/html")) {
                    return bodyPart.getContent().toString()
                } else if (bodyPart.getContent() instanceof MimeMultipart) {
                    String html = extractHtmlFromMultipart((MimeMultipart) bodyPart.getContent())
                    if (html) {
                        return html
                    }
                }
            }

            return ""
        }

        /**
         * Prosta konwersja HTML do tekstu.
         */
        private String extractTextFromHtml(String html) {
            return html.replaceAll("\\<.*?\\>", "")
                        .replaceAll("&nbsp;", " ")
                        .replaceAll("&lt;", "<")
                        .replaceAll("&gt;", ">")
                        .replaceAll("&amp;", "&")
        }
    }

    /**
     * Procesor do zapisania danych emaila w bazie SQLite.
     */
    static class EmailStoreProcessor implements Processor {
        @Override
        void process(Exchange exchange) throws Exception {
            def emailData = exchange.getIn().getBody(Map.class)

            // Przygotowanie zapytania SQL
            def sql = """
            INSERT INTO processed_emails
            (message_id, subject, sender, recipients, received_date, processed_date, body_text, body_html, status, llm_analysis, metadata)
            VALUES
            (:message_id, :subject, :sender, :recipients, :received_date, :processed_date, :body_text, :body_html, :status, :llm_analysis, :metadata)
            ON CONFLICT(message_id) DO UPDATE SET
            processed_date = :processed_date,
            status = :status,
            llm_analysis = :llm_analysis
            """

            // Parametry do zapytania SQL
            def parameters = [
                message_id: emailData.messageId,
                subject: emailData.subject,
                sender: emailData.sender,
                recipients: emailData.recipients,
                received_date: emailData.receivedDate,
                processed_date: emailData.processedDate,
                body_text: emailData.bodyText,
                body_html: emailData.bodyHtml ?: "",
                status: emailData.status,
                llm_analysis: emailData.llmAnalysis,
                metadata: emailData.metadata
            ]

            // Ustawienie parametrów dla zapytania SQL
            exchange.getIn().setHeader("CamelSqlQuery", sql)
            exchange.getIn().setHeader("CamelSqlParameters", parameters)
            exchange.getIn().setBody(parameters)

            // Wykonanie zapytania
            exchange.getIn().setHeader(Exchange.DESTINATION_OVERRIDE_URL, "sql:dummy?dataSource=dataSource")

            // Analiza JSON do decyzji o odpowiedzi
            def analysis = new JsonSlurper().parseText(emailData.llmAnalysis)
            emailData.requiresResponse = analysis.requiresResponse

            exchange.getIn().setBody(emailData)
        }
    }
}