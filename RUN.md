# Wykonywanie projektu "Email-LLM Integration"

## Przygotowanie środowiska

### Krok 1: Instalacja wymaganych narzędzi

Przed uruchomieniem projektu upewnij się, że masz zainstalowane następujące narzędzia:

1. **Docker** - do konteneryzacji aplikacji
   ```bash
   # Sprawdź, czy Docker jest zainstalowany
   docker --version
   
   # Jeśli nie, zainstaluj Docker według instrukcji ze strony https://docs.docker.com/get-docker/
   ```

2. **Docker Compose** - do orkiestracji kontenerów
   ```bash
   # Sprawdź, czy Docker Compose jest zainstalowany
   docker-compose --version
   
   # Jeśli nie, zainstaluj Docker Compose według instrukcji ze strony https://docs.docker.com/compose/install/
   ```

3. **curl** - do testowania API
   ```bash
   # Sprawdź, czy curl jest zainstalowany
   curl --version
   
   # Jeśli nie, zainstaluj curl
   # Na Ubuntu/Debian:
   sudo apt-get update && sudo apt-get install -y curl
   
   # Na macOS (używając Homebrew):
   brew install curl
   ```

4. **jq** (opcjonalnie) - do formatowania odpowiedzi JSON
   ```bash
   # Sprawdź, czy jq jest zainstalowany
   jq --version
   
   # Jeśli nie, zainstaluj jq
   # Na Ubuntu/Debian:
   sudo apt-get update && sudo apt-get install -y jq
   
   # Na macOS (używając Homebrew):
   brew install jq
   ```

### Krok 2: Przygotowanie projektu

1. Sklonuj repozytorium projektu (jeśli jest dostępne) lub utwórz strukturę projektu:
   ```bash
   # Utwórz strukturę projektu za pomocą skryptu instalacyjnego
   chmod +x setup.sh
   ./setup.sh
   ```

2. Dostosuj plik `.env` do swoich potrzeb:
   ```bash
   # Otwórz plik .env w edytorze tekstu
   nano .env
   
   # Dostosuj ustawienia, szczególnie w sekcji EMAIL_* i OLLAMA_*
   ```

## Uruchamianie projektu

### Krok 1: Uruchomienie aplikacji

Użyj przygotowanego skryptu startowego:
```bash
# Nadaj uprawnienia wykonywania skryptowi
chmod +x start.sh

# Uruchom skrypt
./start.sh
```

Skrypt wykonuje następujące działania:
1. Uruchamia kontenery Docker za pomocą docker-compose
2. Czeka na uruchomienie serwera Ollama
3. Pobiera model LLM, jeśli jest to konieczne (to może zająć kilka minut)
4. Czeka na uruchomienie aplikacji
5. Wyświetla dostępne endpointy

### Krok 2: Sprawdzenie stanu aplikacji

Po uruchomieniu aplikacji, sprawdź czy wszystkie usługi działają poprawnie:

1. **API aplikacji**: Otwórz w przeglądarce http://localhost:8080/api/health
   - Powinieneś zobaczyć odpowiedź JSON ze statusem "UP"

2. **Dokumentacja API**: Otwórz w przeglądarce http://localhost:8080/api/api-doc
   - Powinieneś zobaczyć interaktywną dokumentację API

3. **Panel testowej skrzynki email**: Otwórz w przeglądarce http://localhost:8025
   - MailHog zapewnia interfejs webowy do podglądu testowych wiadomości email

4. **Panel administracyjny SQLite**: Otwórz w przeglądarce http://localhost:8081
   - Wybierz SQLite jako typ bazy danych
   - Jako server podaj "/data/emails.db"
   - Pozostaw hasło puste
   - Kliknij "Login" aby zarządzać bazą danych

### Krok 3: Testowanie API

Użyj przygotowanego skryptu do testowania API:
```bash
# Nadaj uprawnienia wykonywania skryptowi
chmod +x test-api.sh

# Uruchom skrypt
./test-api.sh
```

Skrypt wykonuje następujące zapytania:
1. Sprawdza stan aplikacji (GET /api/health)
2. Testuje analizę tekstu przez LLM (POST /api/llm/direct-analyze)
3. Pobiera listę emaili (GET /api/emails)

## Rozwijanie projektu

### Edytowanie tras Camel

Głównym zadaniem projektu jest zdefiniowanie tras w Apache Camel, które określają przepływ danych w systemie. Trasy można edytować w następujących miejscach:

1. **Główne klasy aplikacji** w katalogu `camel-groovy/src/main/groovy/com/example/emailllm/`:
   - `EmailProcessingRoute.groovy` - trasy do przetwarzania emaili
   - `MaintenanceRoutes.groovy` - trasy dla zadań konserwacyjnych
   - `RestApiConfig.groovy` - konfiguracja API REST

2. **Dynamicznie ładowane trasy** w katalogu `camel-groovy/routes/`:
   - `OllamaDirectRoute.groovy` - trasa do bezpośredniej integracji z Ollama LLM

Każdy plik zawiera komentarze "TO-DO", które wskazują miejsca wymagające uzupełnienia.

### Przykład implementacji analizy LLM

W pliku `camel-groovy/routes/OllamaDirectRoute.groovy` zaimplementuj pełną integrację z Ollama LLM:

```groovy
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
                Przeanalizuj poniższy tekst i:
                1. Wyodrębnij kluczowe informacje i tematy
                2. Określ priorytet i pilność
                3. Zidentyfikuj czy wymagane są działania lub odpowiedzi
                
                === TEKST ===
                ${text}
                
                ${context ? "=== KONTEKST ===\n${context}" : ""}
                
                Odpowiedz w formacie JSON z następującymi polami:
                {
                  "keyTopics": ["temat1", "temat2"],
                  "priority": "high/medium/low",
                  "requiresResponse": true/false,
                  "actionRequired": true/false,
                  "summary": "krótkie podsumowanie"
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
                def analysis
                
                try {
                    // Próba parsowania JSON z odpowiedzi LLM
                    analysis = jsonSlurper.parseText(response.response)
                } catch (Exception e) {
                    // Jeśli odpowiedź nie jest poprawnym JSON, zwróć surową odpowiedź
                    analysis = [
                        raw_response: response.response,
                        processed: false,
                        error: "Nie można sparsować odpowiedzi jako JSON"
                    ]
                }
                
                exchange.getIn().setBody([
                    result: analysis,
                    model: response.model,
                    processing_time: response.processing_time,
                    timestamp: LocalDateTime.now().format(DateTimeFormatter.ISO_LOCAL_DATE_TIME)
                ])
            }
        .endRest()
```

### Przykład implementacji przetwarzania emaili

W pliku `camel-groovy/src/main/groovy/com/example/emailllm/EmailProcessingRoute.groovy` zaimplementuj trasę do przetwarzania emaili:

```groovy
// Trasa do monitorowania emaili
from("imaps://${imapHost}:${imapPort}?" +
     "username=${emailUser}&password=${emailPassword}&" +
     "folderName=${imapFolder}&unseen=true&" +
     "consumer.delay=60000")
    .routeId("email-polling")
    .log(LoggingLevel.INFO, "Odebrano nowy email: ${header.subject}")
    .process { exchange ->
        // Pobierz wiadomość email
        def mailMessage = exchange.getIn()
        def mimeMessage = mailMessage.getBody(javax.mail.internet.MimeMessage.class)
        
        // Ekstrahuj dane z wiadomości
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
            status: "pending"
        ]
        
        exchange.getIn().setBody(emailData)
    }
    .to("direct:analyzeLLM")
    .process { exchange ->
        def emailData = exchange.getIn().getBody(Map.class)
        def llmAnalysis = exchange.getIn().getHeader("LLMAnalysis", Map.class)
        
        // Połącz dane emaila z analizą LLM
        emailData.llmAnalysis = JsonOutput.toJson(llmAnalysis)
        emailData.status = "processed"
        emailData.processedDate = LocalDateTime.now().format(DateTimeFormatter.ISO_LOCAL_DATE_TIME)
        
        exchange.getIn().setBody(emailData)
    }
    .to("sql:INSERT INTO processed_emails (message_id, subject, sender, recipients, received_date, processed_date, body_text, status, llm_analysis) VALUES (:#messageId, :#subject, :#sender, :#recipients, :#receivedDate, :#processedDate, :#bodyText, :#status, :#llmAnalysis)?dataSource=dataSource")
    .log(LoggingLevel.INFO, "Email zapisany w bazie danych: ${body.messageId}")
```

## Zatrzymywanie projektu

Aby zatrzymać projekt, użyj skryptu zatrzymującego:
```bash
# Nadaj uprawnienia wykonywania skryptowi
chmod +x stop.sh

# Uruchom skrypt
./stop.sh
```

Skrypt zatrzymuje wszystkie kontenery Docker uruchomione przez docker-compose.

## Rozwiązywanie problemów

### Problem: Nie można połączyć się z serwerem Ollama

**Objaw**: Aplikacja zgłasza błędy połączenia z serwerem Ollama

**Rozwiązanie**:
1. Sprawdź, czy kontener Ollama jest uruchomiony:
   ```bash
   docker ps | grep ollama
   ```
2. Sprawdź logi kontenera Ollama:
   ```bash
   docker logs ollama
   ```
3. Upewnij się, że Ollama ma wystarczającą ilość pamięci (co najmniej 4GB):
   ```bash
   docker stats ollama
   ```

### Problem: Baza danych nie jest inicjalizowana

**Objaw**: Zapytania do bazy danych zwracają błędy lub puste wyniki

**Rozwiązanie**:
1. Sprawdź, czy katalog `data` istnieje i ma odpowiednie uprawnienia:
   ```bash
   ls -la data
   ```
2. Sprawdź logi kontenera aplikacji:
   ```bash
   docker logs camel-groovy-email-llm
   ```
3. Spróbuj ręcznie utworzyć bazę danych:
   ```bash
   docker exec -it camel-groovy-email-llm /app/scripts/entrypoint.sh
   ```

### Problem: Aplikacja nie odpowiada

**Objaw**: Nie można połączyć się z API aplikacji

**Rozwiązanie**:
1. Sprawdź, czy kontener aplikacji jest uruchomiony:
   ```bash
   docker ps | grep camel-groovy
   ```
2. Sprawdź logi kontenera aplikacji:
   ```bash
   docker logs camel-groovy-email-llm
   ```
3. Uruchom ponownie kontener aplikacji:
   ```bash
   docker restart camel-groovy-email-llm
   ```

## Dalsza dokumentacja

Pełna dokumentacja projektu znajduje się w pliku `documentation.md`, który zawiera:
- Szczegółowe diagramy przepływu danych
- Opis architektury systemu
- Dokumentację API REST
- Najlepsze praktyki