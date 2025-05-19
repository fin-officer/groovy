# Dokumentacja Projektu Email-LLM Integration

## Spis treści
1. [Przegląd projektu](#przegląd-projektu)
2. [Architektura systemu](#architektura-systemu)
3. [Przepływy danych](#przepływy-danych)
4. [Komponenty systemu](#komponenty-systemu)
5. [Konfiguracja](#konfiguracja)
6. [API REST](#api-rest)
7. [Obsługa SQLite](#obsługa-sqlite)
8. [Integracja z Ollama LLM](#integracja-z-ollama-llm)
9. [Usługi i dostęp](#usługi-i-dostęp)
10. [Rozwijanie systemu](#rozwijanie-systemu)

## Przegląd projektu

Email-LLM Integration to system, który integruje serwer pocztowy z lokalnymi modelami uczenia maszynowego (LLM) za pomocą Apache Camel i języka Groovy. Głównym celem systemu jest automatyczne przetwarzanie przychodzących wiadomości email, analiza ich zawartości za pomocą modeli LLM oraz generowanie odpowiednich odpowiedzi.

System pozwala na:
- Odbieranie i analizowanie wiadomości email
- Przetwarzanie ich treści za pomocą lokalnych modeli LLM (Ollama)
- Automatyczne generowanie odpowiedzi na podstawie analizy
- Zapisywanie danych w bazie SQLite
- Monitorowanie i zarządzanie całym procesem przez interfejs API REST

## Architektura systemu

System składa się z następujących głównych komponentów:

1. **Apache Camel** - silnik integracji, który zarządza przepływami danych i logiką biznesową
2. **Groovy** - język programowania używany do implementacji logiki biznesowej
3. **Spring Boot** - framework do szybkiego tworzenia aplikacji Java/Groovy
4. **Ollama** - lokalny serwer LLM do analizy tekstu
5. **SQLite** - lekka baza danych do przechowywania wiadomości i ich analizy
6. **MailHog** - testowy serwer SMTP/IMAP dla celów deweloperskich
7. **Adminer** - narzędzie administracyjne dla bazy danych

Wszystkie komponenty są uruchamiane jako kontenery Docker i zarządzane za pomocą Docker Compose.

## Przepływy danych

System wykorzystuje trasy (routes) Apache Camel do definiowania przepływów danych:

1. **EmailProcessingRoute** - główna trasa do przetwarzania emaili
    - Pobieranie wiadomości z serwera IMAP
    - Parsowanie treści
    - Przesyłanie do analizy LLM
    - Zapis do bazy danych
    - Opcjonalne generowanie odpowiedzi

2. **MaintenanceRoutes** - trasy do zadań konserwacyjnych
    - Regularne sprawdzanie stanu bazy danych
    - Optymalizacja bazy danych
    - Logowanie operacji konserwacyjnych

3. **OllamaDirectRoute** - dynamicznie ładowana trasa do bezpośredniej interakcji z Ollama LLM
    - Przyjmowanie żądań analizy tekstu
    - Formatowanie zapytań do Ollama
    - Przetwarzanie odpowiedzi
    - Zwracanie wyników analizy

## Komponenty systemu

### EmailLlmIntegrationApplication

Główna klasa aplikacji Spring Boot, która konfiguruje środowisko uruchomieniowe. Zawiera:
- Konfigurację DataSource dla SQLite
- Skanowanie komponentów
- Inicjalizację Spring Boot

### EmailProcessingRoute

Implementuje główną logikę przetwarzania wiadomości email, w tym:
- Endpointy REST API
- Obsługę błędów
- Pobieranie emaili z bazy danych
- Analizę tekstu za pomocą LLM

### MaintenanceRoutes

Zawiera trasy do zadań konserwacyjnych:
- Regularne sprawdzanie stanu systemu
- Optymalizacja bazy danych
- Dokumentacja API

### RestApiConfig

Konfiguruje interfejs REST API, w tym:
- Ścieżki kontekstu
- Formaty danych
- Właściwości API
- Obsługę CORS

### OllamaDirectRoute

Implementuje bezpośrednią integrację z Ollama LLM:
- Endpointy do analizy tekstu
- Formatowanie zapytań dla modelu LLM
- Przetwarzanie odpowiedzi z modelu
- Konwersja wyników do JSON

## Konfiguracja

Konfiguracja systemu jest realizowana głównie poprzez zmienne środowiskowe, które są definiowane w pliku `.env`. Główne kategorie konfiguracji to:

### Konfiguracja serwera email
```
EMAIL_HOST=test-smtp.example.com
EMAIL_PORT=587
EMAIL_USER=test@example.com
EMAIL_PASSWORD=test_password
EMAIL_USE_TLS=true
EMAIL_IMAP_HOST=test-imap.example.com
EMAIL_IMAP_PORT=993
EMAIL_IMAP_FOLDER=INBOX
```

### Konfiguracja Ollama
```
OLLAMA_HOST=http://ollama:11434
OLLAMA_MODEL=mistral
OLLAMA_API_KEY=
```

### Konfiguracja SQLite
```
SQLITE_DB_PATH=/data/emails.db
SQLITE_JOURNAL_MODE=WAL
SQLITE_CACHE_SIZE=102400
SQLITE_SYNCHRONOUS=NORMAL
```

### Konfiguracja Apache Camel
```
CAMEL_DEBUG=false
CAMEL_TRACING=false
CAMEL_SHUTDOWN_TIMEOUT=10
CAMEL_ROUTES_RELOAD_DIRECTORY=/app/routes
CAMEL_STREAM_CACHE_ENABLED=true
```

### Konfiguracja portów usług
```
SERVER_PORT=8080
OLLAMA_PORT=11435
MAILHOG_SMTP_PORT=1026
MAILHOG_UI_PORT=8026
NODERED_PORT=1880
ADMINER_PORT=8081
```

## API REST

System udostępnia następujące endpointy REST API:

| Endpoint | Metoda | Opis | Przykład zapytania |
|----------|--------|------|-------------------|
| `/api/health` | GET | Sprawdzenie stanu aplikacji | `curl http://localhost:8080/api/health` |
| `/api/emails` | GET | Pobieranie listy przetworzonych emaili | `curl http://localhost:8080/api/emails` |
| `/api/llm/direct-analyze` | POST | Bezpośrednia analiza tekstu za pomocą LLM | `curl -X POST -H "Content-Type: application/json" -d '{"text":"Treść wiadomości", "context":"Kontekst"}' http://localhost:8080/api/llm/direct-analyze` |
| `/api/api-doc` | GET | Dokumentacja API w formacie JSON | `curl http://localhost:8080/api/api-doc` |
| `/api/ollama/analyze` | POST | Alternatywny endpoint do analizy tekstu | `curl -X POST -H "Content-Type: application/json" -d '{"text":"Treść wiadomości", "model":"mistral"}' http://localhost:8080/api/ollama/analyze` |

## Obsługa SQLite

System wykorzystuje bazę danych SQLite do przechowywania przetworzonych wiadomości email. Schemat bazy danych zawiera:

### Tabela `processed_emails`
- `id` - unikalne ID rekordu
- `message_id` - unikalne ID wiadomości email
- `subject` - temat wiadomości
- `sender` - nadawca
- `recipients` - odbiorcy
- `received_date` - data otrzymania
- `processed_date` - data przetworzenia
- `body_text` - treść tekstowa
- `body_html` - treść HTML
- `status` - status przetworzenia
- `llm_analysis` - wynik analizy LLM w formacie JSON
- `metadata` - dodatkowe metadane

### Tabela `email_attachments`
- `id` - unikalne ID załącznika
- `email_id` - ID powiązanej wiadomości email
- `filename` - nazwa pliku
- `content_type` - typ MIME
- `size` - rozmiar załącznika
- `content` - zawartość załącznika

## Integracja z Ollama LLM

System integruje się z Ollama - lokalnym serwerem modeli LLM. Domyślnie używany jest model `mistral`, ale można to zmienić w konfiguracji.

Format zapytania do Ollama:
```json
{
  "model": "mistral",
  "prompt": "..."
}
```

Format odpowiedzi analizy:
```json
{
  "intent": "",       // Główny cel wiadomości
  "sentiment": "",    // Pozytywny, negatywny lub neutralny
  "priority": "",     // Wysoki, średni lub niski
  "topics": [],       // Lista głównych tematów
  "suggestedResponse": ""  // Sugerowana odpowiedź
}
```

## Usługi i dostęp

System udostępnia następujące usługi:

| Usługa | URL | Dane logowania | Opis |
|--------|-----|----------------|------|
| API aplikacji | http://localhost:8080/api | Nie wymagane | Główne API systemu |
| Dokumentacja API | http://localhost:8080/api/api-doc | Nie wymagane | Dokumentacja REST API |
| Panel testowej skrzynki email (MailHog) | http://localhost:8026 | Nie wymagane | Interfejs do przeglądania wiadomości testowych |
| Panel administracyjny SQLite (Adminer) | http://localhost:8081 | System: SQLite<br>Serwer: `/data/emails.db`<br>Użytkownik: (puste)<br>Hasło: (puste)<br>Baza: (puste) | Zarządzanie bazą danych SQLite |
| Node-RED | http://localhost:1880 | Nie wymagane | Wizualne programowanie przepływów (jeśli włączone) |

## Rozwijanie systemu

### Dodawanie nowych tras

Aby dodać nową trasę Camel, można:

1. Utworzyć nową klasę implementującą `RouteBuilder` w katalogu `camel-groovy/src/main/groovy/com/example/emailllm/`
2. Dodać dynamicznie ładowaną trasę w katalogu `camel-groovy/routes/`

Przykład trasy:
```groovy
package com.example.emailllm

import org.apache.camel.builder.RouteBuilder
import org.springframework.stereotype.Component

@Component
class MyNewRoute extends RouteBuilder {
    @Override
    void configure() throws Exception {
        from("direct:myNewEndpoint")
            .log("Processing request: ${body}")
            .process { exchange ->
                // Logika przetwarzania
            }
            .to("direct:anotherEndpoint")
    }
}
```

### Rozszerzanie analizy LLM

Aby dostosować analizę LLM:

1. Zmodyfikuj prompt w `OllamaDirectRoute.groovy` lub `EmailProcessingRoute.groovy`
2. Dostosuj przetwarzanie odpowiedzi zgodnie z potrzebami
3. Opcjonalnie, dodaj dodatkowe pola do analizy lub zmień format

### Dodawanie nowych funkcjonalności

1. Zmodyfikuj istniejące lub dodaj nowe klasy w katalogu `camel-groovy/src/main/groovy/com/example/emailllm/`
2. Zaktualizuj konfigurację w `application.yml`
3. Dodaj nowe endpointy REST API w odpowiednich klasach tras
4. Rozszerz schemat bazy danych, jeśli to konieczne

## Rozwiązywanie problemów

### Problem z uruchomieniem Ollama

Jeśli napotkasz problemy z uruchomieniem Ollama:
- Upewnij się, że masz wystarczającą ilość pamięci RAM (min. 4GB)
- Sprawdź logi kontenera: `docker logs ollama`
- Zrestartuj kontener: `docker restart ollama`

### Problem z połączeniem z bazą danych

- Sprawdź, czy ścieżka do bazy danych jest poprawna w zmiennej `SQLITE_DB_PATH`
- Upewnij się, że katalog `/data` istnieje i ma odpowiednie uprawnienia
- Sprawdź logi aplikacji: `docker logs camel-groovy-email-llm`

### Problem z analizą LLM

- Upewnij się, że model Mistral został poprawnie załadowany
- Sprawdź status Ollama: `curl http://localhost:11435/api/health`
- Sprawdź, czy format zapytania jest poprawny