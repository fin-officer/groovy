#!/bin/bash
# Skrypt do inicjalizacji projektu Email-LLM z Apache Camel i Groovy
# Autor: Generator struktury projektu
# Data: 2025-05-17

set -e  # Zatrzymaj skrypt przy błędzie

# Kolory do komunikatów
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

# Funkcja wyświetlająca informacje
info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

# Funkcja wyświetlająca sukcesy
success() {
    echo -e "${GREEN}[SUKCES]${NC} $1"
}

# Funkcja wyświetlająca ostrzeżenia
warning() {
    echo -e "${YELLOW}[UWAGA]${NC} $1"
}

# Funkcja wyświetlająca błędy
error() {
    echo -e "${RED}[BŁĄD]${NC} $1"
    exit 1
}

# Funkcja sprawdzająca wymagania
check_requirements() {
    info "Sprawdzanie wymagań systemowych..."

    # Sprawdź Docker
    if ! command -v docker &> /dev/null; then
        error "Docker nie jest zainstalowany. Zainstaluj Docker przed kontynuowaniem."
    fi

    # Sprawdź Docker Compose
    if ! command -v docker-compose &> /dev/null; then
        error "Docker Compose nie jest zainstalowany. Zainstaluj Docker Compose przed kontynuowaniem."
    fi

    # Sprawdź curl
    if ! command -v curl &> /dev/null; then
        error "curl nie jest zainstalowany. Zainstaluj curl przed kontynuowaniem."
    fi

    success "Wszystkie wymagania systemowe są spełnione."
}

# Funkcja tworząca strukturę katalogów
create_directory_structure() {
    info "Tworzenie struktury katalogów..."

    mkdir -p camel-groovy/src/main/groovy/com/example/emailllm
    mkdir -p camel-groovy/src/main/resources
    mkdir -p camel-groovy/scripts
    mkdir -p camel-groovy/routes
    mkdir -p data
    mkdir -p logs

    success "Struktura katalogów została utworzona."
}

# Funkcja zapisująca pliki do odpowiednich ścieżek
create_file() {
    local file_path="$1"
    local content="$2"

    # Utwórz katalog nadrzędny, jeśli nie istnieje
    mkdir -p "$(dirname "$file_path")"

    # Zapisz zawartość do pliku
    echo "$content" > "$file_path"

    # Ustaw uprawnienia wykonywania dla skryptów
    if [[ "$file_path" == *.sh ]]; then
        chmod +x "$file_path"
    fi

    info "Utworzono plik: $file_path"
}

# Główna funkcja instalacji
install_project() {
    info "Rozpoczynam instalację projektu Email-LLM z Apache Camel i Groovy..."

    # Sprawdź wymagania systemowe
    check_requirements

    # Utwórz strukturę katalogów
    create_directory_structure

    # Generuj plik .env
    info "Generowanie pliku .env..."
    create_file ".env" "$(cat <<EOF
# Przykładowy plik .env dla konfiguracji docker-compose i kontenerów
# Konfiguracja serwera email
EMAIL_HOST=test-smtp.example.com
EMAIL_PORT=587
EMAIL_USER=test@example.com
EMAIL_PASSWORD=test_password
EMAIL_USE_TLS=true
EMAIL_IMAP_HOST=test-imap.example.com
EMAIL_IMAP_PORT=993
EMAIL_IMAP_FOLDER=INBOX

# Konfiguracja Ollama
OLLAMA_HOST=http://ollama:11434
OLLAMA_MODEL=mistral
OLLAMA_API_KEY=

# Konfiguracja SQLite
SQLITE_DB_PATH=/data/emails.db
SQLITE_JOURNAL_MODE=WAL
SQLITE_CACHE_SIZE=102400
SQLITE_SYNCHRONOUS=NORMAL

# Konfiguracja Apache Camel
CAMEL_DEBUG=false
CAMEL_TRACING=false
CAMEL_SHUTDOWN_TIMEOUT=10
CAMEL_ROUTES_RELOAD_DIRECTORY=/app/routes
CAMEL_STREAM_CACHE_ENABLED=true

# Konfiguracja aplikacji Spring Boot
SERVER_PORT=8080
SPRING_PROFILES_ACTIVE=dev
EOF
)"

    # Generuj plik docker-compose.yml
    info "Generowanie pliku docker-compose.yml..."
    create_file "docker-compose.yml" "$(cat <<EOF
version: '3.8'

services:
  # Serwer Ollama z lokalnym LLM
  ollama:
    image: ollama/ollama:latest
    container_name: ollama
    ports:
      - "11434:11434"
    volumes:
      - ollama_models:/root/.ollama
    restart: unless-stopped
    networks:
      - app-network
    healthcheck:
      test: ["CMD", "curl", "-f", "http://localhost:11434/api/health"]
      interval: 10s
      timeout: 5s
      retries: 5

  # Testowy serwer email (MailHog)
  mailserver:
    image: mailhog/mailhog:latest
    container_name: mailserver
    ports:
      - "1025:1025"  # SMTP port
      - "8025:8025"  # Web UI port
    networks:
      - app-network
    restart: unless-stopped
    # Na produkcji zastąpić rzeczywistym serwerem

  # Aplikacja Camel z Groovy integrująca email z LLM
  camel-groovy:
    build:
      context: ./camel-groovy
      dockerfile: Dockerfile
    container_name: camel-groovy-email-llm
    ports:
      - "\${SERVER_PORT:-8080}:8080"
    depends_on:
      - ollama
      - mailserver
    env_file:
      - .env
    volumes:
      - ./data:/data
      - ./camel-groovy/routes:/app/routes
      - ./logs:/logs
    restart: unless-stopped
    networks:
      - app-network
    healthcheck:
      test: ["CMD", "curl", "-f", "http://localhost:8080/api/health"]
      interval: 30s
      timeout: 10s
      retries: 3

  # Narzędzie administracyjne dla bazy SQLite
  adminer:
    image: adminer:latest
    container_name: adminer
    ports:
      - "8081:8080"
    environment:
      - ADMINER_DEFAULT_DRIVER=sqlite
    volumes:
      - ./data:/data:ro
    restart: unless-stopped
    networks:
      - app-network

volumes:
  ollama_models:

networks:
  app-network:
    driver: bridge
EOF
)"

    # Generuj plik Dockerfile
    info "Generowanie pliku Dockerfile..."
    create_file "camel-groovy/Dockerfile" "$(cat <<EOF
FROM openjdk:17-jdk-slim as build

WORKDIR /build

# Instalacja niezbędnych narzędzi
RUN apt-get update && apt-get install -y curl unzip

# Instalacja Gradle
RUN curl -L https://services.gradle.org/distributions/gradle-8.5-bin.zip -o gradle.zip \\
    && unzip gradle.zip -d /opt \\
    && ln -s /opt/gradle-8.5/bin/gradle /usr/bin/gradle \\
    && rm gradle.zip

# Kopiowanie plików projektu
COPY build.gradle settings.gradle ./
COPY src ./src

# Budowanie aplikacji
RUN gradle clean build -x test

# Obraz docelowy
FROM openjdk:17-jre-slim

WORKDIR /app

# Instalacja niezbędnych narzędzi
RUN apt-get update && apt-get install -y sqlite3 curl jq bash && rm -rf /var/lib/apt/lists/*

# Kopiowanie zbudowanej aplikacji
COPY --from=build /build/build/libs/*.jar app.jar

# Kopiowanie skryptów i plików konfiguracyjnych
COPY scripts /app/scripts
RUN chmod +x /app/scripts/*.sh

# Kopiowanie plików Groovy
COPY routes /app/routes

# Tworzenie katalogów
RUN mkdir -p /data /logs

# Ekspozycja portu
EXPOSE 8080

# Punkt wejścia
ENTRYPOINT ["/app/scripts/entrypoint.sh"]
EOF
)"

    # Generuj plik entrypoint.sh
    info "Generowanie pliku entrypoint.sh..."
    create_file "camel-groovy/scripts/entrypoint.sh" "$(cat <<EOF
#!/bin/bash
set -e

# Ścieżka do bazy danych
DB_PATH=\${SQLITE_DB_PATH:-/data/emails.db}

# Sprawdź, czy baza danych istnieje
if [ ! -f "\$DB_PATH" ]; then
    echo "Inicjalizacja bazy danych SQLite..."

    # Utwórz katalog dla bazy danych, jeśli nie istnieje
    mkdir -p \$(dirname "\$DB_PATH")

    # Inicjalizacja bazy danych z optymalizacjami
    sqlite3 "\$DB_PATH" <<EOSQL
PRAGMA journal_mode=\${SQLITE_JOURNAL_MODE:-WAL};
PRAGMA synchronous=\${SQLITE_SYNCHRONOUS:-NORMAL};
PRAGMA cache_size=-\${SQLITE_CACHE_SIZE:-102400};
PRAGMA temp_store=MEMORY;
PRAGMA mmap_size=1073741824;

-- Tabela dla przetworzonych emaili
CREATE TABLE IF NOT EXISTS processed_emails (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    message_id TEXT UNIQUE,
    subject TEXT,
    sender TEXT,
    recipients TEXT,
    received_date TEXT,
    processed_date TEXT,
    body_text TEXT,
    body_html TEXT,
    status TEXT,
    llm_analysis TEXT,
    metadata TEXT
);

-- Indeksy
CREATE INDEX IF NOT EXISTS idx_processed_emails_message_id ON processed_emails(message_id);
CREATE INDEX IF NOT EXISTS idx_processed_emails_status ON processed_emails(status);
CREATE INDEX IF NOT EXISTS idx_processed_emails_received_date ON processed_emails(received_date);

-- Tabela dla załączników
CREATE TABLE IF NOT EXISTS email_attachments (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    email_id INTEGER,
    filename TEXT,
    content_type TEXT,
    size INTEGER,
    content BLOB,
    FOREIGN KEY (email_id) REFERENCES processed_emails(id) ON DELETE CASCADE
);

VACUUM;
EOSQL

    echo "Baza danych utworzona i zoptymalizowana."
fi

# Uruchom aplikację
exec java -jar /app/app.jar
EOF
)"

    # Generuj plik build.gradle
    info "Generowanie pliku build.gradle..."
    create_file "camel-groovy/build.gradle" "$(cat <<EOF
plugins {
    id 'groovy'
    id 'org.springframework.boot' version '3.2.0'
    id 'io.spring.dependency-management' version '1.1.4'
}

group = 'com.example'
version = '0.1.0-SNAPSHOT'
sourceCompatibility = '17'

repositories {
    mavenCentral()
}

ext {
    camelVersion = '4.1.0'
}

dependencies {
    // Spring Boot
    implementation 'org.springframework.boot:spring-boot-starter-web'
    implementation 'org.springframework.boot:spring-boot-starter-actuator'

    // Groovy
    implementation 'org.codehaus.groovy:groovy-all:3.0.19'

    // Apache Camel
    implementation "org.apache.camel.springboot:camel-spring-boot-starter:\${camelVersion}"
    implementation "org.apache.camel.springboot:camel-groovy-starter:\${camelVersion}"
    implementation "org.apache.camel.springboot:camel-mail-starter:\${camelVersion}"
    implementation "org.apache.camel.springboot:camel-http-starter:\${camelVersion}"
    implementation "org.apache.camel.springboot:camel-jdbc-starter:\${camelVersion}"
    implementation "org.apache.camel.springboot:camel-sql-starter:\${camelVersion}"
    implementation "org.apache.camel.springboot:camel-jackson-starter:\${camelVersion}"
    implementation "org.apache.camel.springboot:camel-file-starter:\${camelVersion}"
    implementation "org.apache.camel.springboot:camel-direct-starter:\${camelVersion}"
    implementation "org.apache.camel.springboot:camel-stream-starter:\${camelVersion}"
    implementation "org.apache.camel.springboot:camel-rest-starter:\${camelVersion}"
    implementation "org.apache.camel.springboot:camel-servlet-starter:\${camelVersion}"
    implementation "org.apache.camel.springboot:camel-quartz-starter:\${camelVersion}"

    // SQLite
    implementation 'org.xerial:sqlite-jdbc:3.43.0.0'

    // Jackson for JSON processing
    implementation 'com.fasterxml.jackson.core:jackson-databind:2.15.2'
    implementation 'com.fasterxml.jackson.datatype:jackson-datatype-jsr310:2.15.2'

    // Commons
    implementation 'commons-io:commons-io:2.15.0'
    implementation 'org.apache.commons:commons-lang3:3.13.0'

    // Testing
    testImplementation 'org.springframework.boot:spring-boot-starter-test'
    testImplementation "org.apache.camel:camel-test-spring-junit5:\${camelVersion}"
}

test {
    useJUnitPlatform()
}
EOF
)"

    # Generuj plik settings.gradle
    info "Generowanie pliku settings.gradle..."
    create_file "camel-groovy/settings.gradle" "$(cat <<EOF
rootProject.name = 'email-llm-integration'
EOF
)"

    # Przygotuj skrypty pomocnicze
    info "Generowanie skryptów pomocniczych..."

    # Skrypt start.sh do uruchamiania aplikacji
    create_file "start.sh" "$(cat <<EOF
#!/bin/bash
# Skrypt uruchamiający projekt Email-LLM Integration

GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

echo -e "${BLUE}[INFO]${NC} Uruchamianie projektu Email-LLM Integration..."

# Sprawdź, czy Docker działa
if ! docker info > /dev/null 2>&1; then
    echo -e "${RED}[BŁĄD]${NC} Docker nie jest uruchomiony. Uruchom Docker i spróbuj ponownie."
    exit 1
fi

# Uruchom docker-compose
echo -e "${BLUE}[INFO]${NC} Uruchamianie kontenerów..."
docker-compose up -d

# Poczekaj na uruchomienie Ollama
echo -e "${BLUE}[INFO]${NC} Czekam na uruchomienie Ollama..."
until docker exec -i ollama curl -s http://localhost:11434/api/health &> /dev/null; do
    echo -n "."
    sleep 2
done
echo ""

# Pobierz model, jeśli nie istnieje
if ! docker exec -i ollama ollama list | grep -q mistral; then
    echo -e "${BLUE}[INFO]${NC} Pobieranie modelu Mistral (może to potrwać kilka minut)..."
    docker exec -i ollama ollama pull mistral
fi

# Poczekaj na uruchomienie aplikacji
echo -e "${BLUE}[INFO]${NC} Czekam na uruchomienie aplikacji..."
until curl -s http://localhost:8080/api/health &> /dev/null; do
    echo -n "."
    sleep 2
done
echo ""

echo -e "${GREEN}[SUKCES]${NC} Projekt uruchomiony pomyślnie!"
echo ""
echo "Dostępne usługi:"
echo -e "${BLUE}* API aplikacji:${NC} http://localhost:8080/api"
echo -e "${BLUE}* Dokumentacja API:${NC} http://localhost:8080/api/api-doc"
echo -e "${BLUE}* Panel testowej skrzynki email:${NC} http://localhost:8025"
echo -e "${BLUE}* Panel administracyjny SQLite:${NC} http://localhost:8081"
echo ""
echo -e "${YELLOW}Aby zatrzymać aplikację, użyj polecenia:${NC} docker-compose down"
EOF
)"
    chmod +x start.sh

    # Skrypt stop.sh do zatrzymywania aplikacji
    create_file "stop.sh" "$(cat <<EOF
#!/bin/bash
# Skrypt zatrzymujący projekt Email-LLM Integration

GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

echo -e "${BLUE}[INFO]${NC} Zatrzymywanie projektu Email-LLM Integration..."

docker-compose down

echo -e "${GREEN}[SUKCES]${NC} Projekt zatrzymany pomyślnie!"
EOF
)"
    chmod +x stop.sh

    # Skrypt test-api.sh do testowania API
    create_file "test-api.sh" "$(cat <<EOF
#!/bin/bash
# Skrypt do testowania API aplikacji Email-LLM Integration

GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

# Funkcja do wykonywania żądań
call_api() {
    local method=\$1
    local endpoint=\$2
    local data=\$3
    local description=\$4

    echo -e "${BLUE}[TEST]${NC} \$description"

    if [[ -z "\$data" ]]; then
        response=\$(curl -s -X \$method http://localhost:8080\$endpoint -H "Content-Type: application/json")
    else
        response=\$(curl -s -X \$method http://localhost:8080\$endpoint -H "Content-Type: application/json" -d "\$data")
    fi

    echo -e "${YELLOW}Odpowiedź:${NC}"
    echo \$response | jq '.' || echo \$response
    echo ""
}

# Sprawdź, czy jq jest zainstalowane
if ! command -v jq &> /dev/null; then
    echo -e "${YELLOW}[UWAGA]${NC} Narzędzie jq nie jest zainstalowane. Odpowiedzi JSON nie będą ładnie formatowane."
    jq() { cat; }
fi

# Sprawdź, czy aplikacja jest uruchomiona
echo -e "${BLUE}[INFO]${NC} Sprawdzanie, czy aplikacja jest uruchomiona..."
if ! curl -s http://localhost:8080/api/health &> /dev/null; then
    echo -e "${RED}[BŁĄD]${NC} Aplikacja nie jest uruchomiona. Uruchom aplikację i spróbuj ponownie."
    exit 1
fi

# Testowanie endpointów
call_api "GET" "/api/health" "" "Sprawdzanie stanu aplikacji"

# Test analizy tekstu przez LLM
call_api "POST" "/api/llm/direct-analyze" '{
  "text": "Dzień dobry, chciałbym zapytać o status mojego zamówienia #12345. Potrzebuję pilnej odpowiedzi.",
  "context": "Klient wielokrotnie kontaktował się w sprawie zamówienia."
}' "Testowanie analizy LLM"

# Pobieranie listy emaili
call_api "GET" "/api/emails" "" "Pobieranie listy emaili"

echo -e "${GREEN}[KONIEC]${NC} Wszystkie testy zakończone."
EOF
)"
    chmod +x test-api.sh

    # Kopiowanie dokumentacji
    info "Kopiowanie dokumentacji..."
    create_file "documentation.md" "$(curl -s https://raw.githubusercontent.com/yourusername/email-llm-integration/main/documentation.md || cat <<EOF
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
9. [Rozszerzanie systemu](#rozszerzanie-systemu)
10. [Najlepsze praktyki](#najlepsze-praktyki)

## Przegląd projektu

Email-LLM Integration to system, który integruje serwer pocztowy z lokalnymi modelami uczenia maszynowego (LLM) za pomocą Apache Camel i języka Groovy. Głównym celem systemu jest automatyczne przetwarzanie przychodzących wiadomości email, analiza ich zawartości za pomocą modeli LLM oraz generowanie odpowiednich odpowiedzi.

Pełna dokumentacja zostanie umieszczona tutaj.
EOF
)"

    # Tworzenie pliku README.md
    info "Generowanie pliku README.md..."
    create_file "README.md" "$(cat <<EOF
# Email-LLM Integration z Apache Camel i Groovy

## Opis projektu
Ten projekt integruje obsługę emaili z modelami LLM (Large Language Models) za pomocą Apache Camel i Groovy. Wykorzystuje lokalny model Ollama do analizy treści wiadomości email i automatycznego generowania odpowiedzi.

## Wymagania
- Docker i Docker Compose
- Minimum 4GB RAM dla kontenera Ollama

## Szybki start

### 1. Skonfiguruj zmienne środowiskowe
Edytuj plik \`.env\` według potrzeb.

### 2. Uruchom aplikację
\`\`\`bash
./start.sh
\`\`\`

### 3. Testowanie API
\`\`\`bash
./test-api.sh
\`\`\`

### 4. Zatrzymanie aplikacji
\`\`\`bash
./stop.sh
\`\`\`

## Dostępne usługi
* API aplikacji: http://localhost:8080/api
* Dokumentacja API: http://localhost:8080/api/api-doc
* Panel testowej skrzynki email: http://localhost:8025
* Panel administracyjny SQLite: http://localhost:8081

## Struktura projektu
\`\`\`
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
\`\`\`

## Rozwijanie projektu
Aby rozszerzyć funkcjonalność aplikacji, edytuj pliki .groovy w katalogach:
- \`camel-groovy/src/main/groovy/com/example/emailllm/\` - główne klasy aplikacji
- \`camel-groovy/routes/\` - dynamicznie ładowane trasy Camel

Wszystkie miejsca wymagające uzupełnienia są oznaczone komentarzami "TO-DO".

## Dokumentacja
Pełna dokumentacja znajduje się w pliku \`documentation.md\`.
EOF
)"

    # Podsumowanie
    success "Instalacja zakończona! Struktura projektu została utworzona."
    echo ""
    echo -e "${YELLOW}NASTĘPNE KROKI:${NC}"
    echo "1. Przejrzyj i dostosuj plik .env i docker-compose.yml do swoich potrzeb"
    echo "2. Uruchom aplikację za pomocą polecenia:"
    echo -e "   ${BLUE}./start.sh${NC}"
    echo "3. Dostęp do interfejsów:"
    echo "   - API aplikacji: http://localhost:8080/api"
    echo "   - Dokumentacja API: http://localhost:8080/api/api-doc"
    echo "   - Panel testowej skrzynki email: http://localhost:8025"
    echo "   - Panel administracyjny SQLite: http://localhost:8081"
    echo "4. Testowanie API:"
    echo -e "   ${BLUE}./test-api.sh${NC}"
    echo "5. Zatrzymanie aplikacji:"
    echo -e "   ${BLUE}./stop.sh${NC}"
    echo ""
    echo -e "${GREEN}Powodzenia z implementacją projektu!${NC}"
}

# Uruchomienie instalacji
install_project