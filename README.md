# Email-LLM Integration z Apache Camel i Groovy

## Opis projektu
Ten projekt integruje obsługę emaili z modelami LLM (Large Language Models) za pomocą Apache Camel i Groovy. Wykorzystuje lokalny model Ollama do analizy treści wiadomości email i automatycznego generowania odpowiedzi.

## Wymagania
- Docker i Docker Compose
- Minimum 4GB RAM dla kontenera Ollama

## Szybki start

### 1. Skonfiguruj zmienne środowiskowe
Edytuj plik `.env` według potrzeb.

### 2. Uruchom aplikację
```bash
./start.sh
```

### 3. Testowanie API
```bash
./test-api.sh
```

### 4. Zatrzymanie aplikacji
```bash
./stop.sh
```

## Dostępne usługi
* API aplikacji: http://localhost:8080/api
* Dokumentacja API: http://localhost:8080/api/api-doc
* Panel testowej skrzynki email: http://localhost:8025
* Panel administracyjny SQLite: http://localhost:8081

## Struktura projektu
```
├── .env                                           # Plik z zmiennymi środowiskowymi
├── docker-compose.yml                             # Konfiguracja Docker Compose
├── start.sh                                       # Skrypt uruchamiający
├── stop.sh                                        # Skrypt zatrzymujący
├── test-api.sh                                    # Skrypt testujący API
├── documentation.md                               # Pełna dokumentacja
└── camel-groovy/                                  # Katalog główny aplikacji
    ├── Dockerfile                                 # Dockerfile dla aplikacji
    ├── build.gradle                               # Konfiguracja Gradle
    ├── settings.gradle                            # Ustawienia projektu Gradle
    ├── scripts/
    │   └── entrypoint.sh                          # Skrypt startowy
    ├── routes/
    │   └── OllamaDirectRoute.groovy               # Dynamicznie ładowana trasa
    └── src/
        └── main/
            ├── groovy/com/example/emailllm/
            │   ├── EmailLlmIntegrationApplication.groovy
            │   ├── EmailProcessingRoute.groovy
            │   ├── MaintenanceRoutes.groovy
            │   └── RestApiConfig.groovy
            └── resources/
                └── application.yml                # Konfiguracja aplikacji
```

## Rozwijanie projektu
Aby rozszerzyć funkcjonalność aplikacji, edytuj pliki .groovy w katalogach:
- `camel-groovy/src/main/groovy/com/example/emailllm/` - główne klasy aplikacji
- `camel-groovy/routes/` - dynamicznie ładowane trasy Camel

Wszystkie miejsca wymagające uzupełnienia są oznaczone komentarzami "TO-DO".

## Dokumentacja
Pełna dokumentacja znajduje się w pliku `documentation.md`.
