Wygląda na to, że aplikacja nadal ma problemy z działaniem pomimo udanego uruchomienia kontenerów. Problem z komunikacją może być spowodowany kilkoma czynnikami. Sprawdźmy i naprawmy te problemy.

Najpierw sprawdźmy logi aplikacji, żeby zidentyfikować problemy:

1. **Sprawdź logi kontenera camel-groovy-email-llm**:
   ```bash
   docker logs camel-groovy-email-llm
   ```

2. **Sprawdź czy kontener faktycznie działa i nasłuchuje na porcie 8083**:
   ```bash
   docker ps | grep camel-groovy
   ```

W międzyczasie przygotujmy kilka rozwiązań:

Wygląda na to, że masz problem z dostępem do API aplikacji, pomimo że kontenery zostały uruchomione. Przygotowałem kilka rozwiązań, które powinny pomóc naprawić ten problem:

## 1. Skrypt diagnostyczny

Stworzyłem skrypt `debug-api.sh`, który pomoże zdiagnozować problemy z połączeniem do API. Ten skrypt sprawdza:
- Status kontenerów
- Logi aplikacji
- Połączenie wewnątrz kontenera
- Mapowanie portów
- Próbuje bezpośrednie połączenie z API
- Sprawdza konfigurację sieci Docker
- Próbuje zrestartować kontener

Aby go użyć:
```bash
chmod +x debug-api.sh
./debug-api.sh
```

## 2. Poprawiony plik docker-compose.yml

Wprowadziłem kilka kluczowych zmian w pliku docker-compose.yml:

1. **Poprawione mapowanie portów**:
   ```yaml
   ports:
     - "${SERVER_PORT:-8083}:8080"
   ```
   Mapuje zewnętrzny port 8083 na wewnętrzny port 8080 kontenera.

2. **Bezpośrednie przekazanie zmiennych środowiskowych**:
   ```yaml
   environment:
     - SERVER_PORT=8080  # Wewnętrzny port w kontenerze zawsze 8080
   ```
   Zapewnia, że aplikacja wewnątrz kontenera zawsze nasłuchuje na porcie 8080.

3. **Dodane start_period do healthcheck**:
   ```yaml
   healthcheck:
     start_period: 20s
   ```
   Daje więcej czasu na uruchomienie aplikacji przed pierwszym sprawdzeniem zdrowia.

4. **Konfiguracja logowania**:
   ```yaml
   logging:
     driver: "json-file"
     options:
       max-size: "10m"
       max-file: "3"
   ```
   Zapewnia lepsze przechowywanie logów.

## 3. Zaktualizowany plik application.yml

Zmodyfikowałem plik application.yml, aby poprawić konfigurację serwera:

1. **Stały port wewnętrzny**:
   ```yaml
   server:
     port: 8080
   ```
   Zapewnia, że aplikacja nasłuchuje na porcie 8080 niezależnie od zmiennych środowiskowych.

2. **Dodane logi dostępu Tomcat**:
   ```yaml
   tomcat:
     accesslog:
       enabled: true
   ```
   Włącza dodatkowe logowanie, co pomoże debugować problemy z połączeniem.

3. **Poprawione konfiguracje czasów oczekiwania**:
   ```yaml
   connection-timeout: 20000
   ```
   Zapobiega przedwczesnemu zamykaniu połączeń.

## Jak naprawić problem:

1. **Zastosuj poprawiony docker-compose.yml**:
   Zastąp obecny plik nową wersją.

2. **Umieść zaktualizowany application.yml w kontenerze**:
   Utwórz plik `camel-groovy/src/main/resources/application.yml` z nową zawartością.

3. **Uruchom skrypt diagnostyczny**:
   ```bash
   ./debug-api.sh
   ```

4. **Przebuduj i uruchom ponownie kontenery**:
   ```bash
   docker-compose down
   docker-compose build --no-cache camel-groovy
   docker-compose up -d
   ```

5. **Jeśli problem nadal występuje**:
   Sprawdź logi kontenera:
   ```bash
   docker logs camel-groovy-email-llm
   ```

   Można również spróbować uzyskać dostęp bezpośrednio z wewnątrz kontenera:
   ```bash
   docker exec -it camel-groovy-email-llm curl http://localhost:8080/api/health
   ```

Prawdopodobną przyczyną problemu jest niedopasowanie między portami wewnętrznymi a zewnętrznymi lub niepoprawna konfiguracja Camel REST API. Powyższe zmiany powinny naprawić te problemy, zapewniając spójną konfigurację portów i lepsze logowanie do diagnostyki.