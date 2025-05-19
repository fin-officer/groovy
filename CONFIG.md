# Instrukcja konfiguracji i dostępu do usług Email-LLM Integration

## Spis treści
1. [Przegląd projektu](#przegląd-projektu)
2. [Adresy i dane dostępowe](#adresy-i-dane-dostępowe)
3. [Konfiguracja](#konfiguracja)
4. [Uruchamianie i zarządzanie](#uruchamianie-i-zarządzanie)
5. [Rozwiązywanie problemów](#rozwiązywanie-problemów)

## Przegląd projektu

Email-LLM Integration to system integrujący obsługę wiadomości email z modelami językowym LLM (Large Language Models) przy użyciu Apache Camel i Groovy. System umożliwia automatyczne przetwarzanie wiadomości email, analizę ich treści oraz generowanie odpowiedzi.

## Adresy i dane dostępowe

### API aplikacji
- **URL**: http://localhost:8080/api
- **Dokumentacja API**: http://localhost:8080/api/api-doc
- **Uwierzytelnianie**: Brak (w środowisku deweloperskim)

### Panel administracyjny SQLite (Adminer)
- **URL**: http://localhost:8081
- **Dane logowania**:
    - **System**: SQLite
    - **Serwer**: `/data/emails.db`
    - **Użytkownik**: admin
    - **Hasło**: email_llm_admin
    - **Baza danych**: (puste pole)

  **Uwaga**: SQLite nie wymaga faktycznego uwierzytelniania, ponieważ jest to plik, a nie serwer bazy danych. Dane logowania są używane tylko do celów informacyjnych.

### Panel testowej skrzynki email (MailHog)
- **URL**: http://localhost:8026
- **Dane logowania**: Brak (domyślnie)
- **SMTP**: localhost:1026
- **IMAP**: Niedostępny w MailHog (tylko web UI)

### Serwer Ollama LLM
- **URL API**: http://localhost:11435/api
- **Modele**:
    - mistral (domyślny)
    - inne modele można pobrać poprzez `docker exec -i ollama ollama pull [nazwa_modelu]`

### Node-RED (opcjonalnie)
- **URL**: http://localhost:1880
- **Dane logowania**: Brak (domyślnie)

## Konfiguracja

Projekt jest konfigurowany poprzez zmienne środowiskowe w pliku `.env`. Najważniejsze z nich to:

### Porty usług
```
SERVER_PORT=8080            # Port API aplikacji
OLLAMA_EXTERNAL_PORT=11435  # Port zewnętrzny dla Ollama
MAILHOG_SMTP_PORT=1026      # Port SMTP dla MailHog
MAILHOG_UI_PORT=8026        # Port interfejsu użytkownika MailHog
ADMINER_PORT=8081           # Port Adminer (panel SQLite)
NODERED_PORT=1880           # Port Node-RED (opcjonalnie)
```

### Konfiguracja Ollama
```
OLLAMA_HOST=ollama          # Nazwa hosta Ollama (wewnątrz Docker)
OLLAMA_PORT=11434           # Port wewnętrzny Ollama
OLLAMA_MODEL=mistral        # Domyślny model LLM
```

### Konfiguracja SQLite
```
SQLITE_DB_PATH=/data/emails.db  # Ścieżka do pliku bazy danych
```

### Dane logowania
```
ADMINER_USERNAME=admin                # Użytkownik dla Adminer
ADMINER_PASSWORD=email_llm_admin      # Hasło dla Adminer
```

## Uruchamianie i zarządzanie

### Uruchamianie systemu
```bash
./start.sh
```

### Zatrzymywanie systemu
```bash
./stop.sh
```

### Sprawdzanie logów
```bash
# Logi aplikacji Camel
docker logs -f camel-groovy-email-llm

# Logi Ollama
docker logs -f ollama

# Logi serwera pocztowego
docker logs -f mailserver
```

### Testowanie API
```bash
# Sprawdzenie stanu aplikacji
curl http://localhost:8080/api/health

# Analiza tekstu za pomocą LLM
curl -X POST -H "Content-Type: application/json" \
  -d '{"text":"Dzień dobry, chciałbym zapytać o status mojego zamówienia #12345.", "context":"Klient wielokrotnie kontaktował się w sprawie zamówienia."}' \
  http://localhost:8080/api/llm/direct-analyze
```

## Rozwiązywanie problemów

### Problem z dostępem do bazy danych
- Sprawdź, czy katalog `./data` istnieje i ma odpowiednie uprawnienia
- Zweryfikuj, czy zmienne `SQLITE_DB_PATH` i `DATA_DIR` są poprawnie ustawione
- Sprawdź logi aplikacji: `docker logs camel-groovy-email-llm`

### Problem z Ollama
- Upewnij się, że masz wystarczająco dużo pamięci RAM (minimum 4GB)
- Sprawdź, czy model został pobrany: `docker exec -i ollama ollama list`
- W razie potrzeby, pobierz model ręcznie: `docker exec -i ollama ollama pull mistral`

### Problem z połączeniem z usługami
- Sprawdź, czy porty nie są zajęte przez inne aplikacje
- Upewnij się, że zmienne portów w pliku `.env` są zgodne z faktycznie dostępnymi portami
- Sprawdź status kontenerów: `docker ps`

### Problem z uwierzytelnianiem do Adminer
- Pamiętaj, że SQLite nie wymaga faktycznego uwierzytelniania - pola logowania są używane tylko do celów informacyjnych
- W polu "Serwer" wprowadź `/data/emails.db`
- Pozostaw pole "Baza danych" puste