#!/bin/bash
# Script do debugowania i naprawy połączenia z API

GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

SERVER_PORT=$(grep "SERVER_PORT=" .env 2>/dev/null | cut -d '=' -f2 | sed 's/#.*$//' | xargs || echo "8083")
API_URL="http://localhost:${SERVER_PORT}/api"

echo -e "${BLUE}[INFO]${NC} Rozpoczynam diagnostykę API na: ${API_URL}"

# Sprawdź status kontenerów
echo -e "${BLUE}[INFO]${NC} Sprawdzanie statusu kontenerów..."
docker ps | grep -E 'camel-groovy|ollama'

# Sprawdź logi aplikacji
echo -e "${BLUE}[INFO]${NC} Ostatnie logi aplikacji:"
docker logs camel-groovy-email-llm --tail 50

# Sprawdź połączenie z wewnątrz kontenera
echo -e "${BLUE}[INFO]${NC} Testowanie połączenia wewnątrz kontenera..."
docker exec -i camel-groovy-email-llm curl -s http://localhost:8080/api/health || echo -e "${RED}[BŁĄD]${NC} Nie można połączyć się z API wewnątrz kontenera!"

# Sprawdź czy mamy przekierowanie portów
echo -e "${BLUE}[INFO]${NC} Sprawdzanie mapowania portów..."
docker port camel-groovy-email-llm

# Sprawdź bezpośrednio HTTP
echo -e "${BLUE}[INFO]${NC} Próba połączenia z API z hosta..."
curl -v ${API_URL}/health

# Sprawdź konfigurację sieci Dockera
echo -e "${BLUE}[INFO]${NC} Informacje o sieci Docker..."
docker network inspect groovy_app-network

# Sprawdź, czy port jest faktycznie nasłuchiwany
echo -e "${BLUE}[INFO]${NC} Sprawdzanie nasłuchujących portów wewnątrz kontenera..."
docker exec -i camel-groovy-email-llm netstat -tulpn | grep 8080 || echo "Netstat niedostępny, instalowanie..." && docker exec -i camel-groovy-email-llm apt-get update && docker exec -i camel-groovy-email-llm apt-get install -y net-tools && docker exec -i camel-groovy-email-llm netstat -tulpn | grep 8080

# Spróbuj zrestartować kontener
echo -e "${YELLOW}[AKCJA]${NC} Próba ponownego uruchomienia kontenera..."
docker restart camel-groovy-email-llm

# Poczekaj na restart
echo -e "${BLUE}[INFO]${NC} Oczekiwanie na ponowne uruchomienie..."
sleep 15

# Sprawdź ponownie połączenie
echo -e "${BLUE}[INFO]${NC} Ponowna próba połączenia z API..."
curl -v ${API_URL}/health

echo -e "${GREEN}[ZAKOŃCZONO]${NC} Diagnostyka zakończona. Jeśli problem nadal występuje, sprawdź:"
echo "1. Czy wszystkie wymagane porty są dostępne"
echo "2. Czy aplikacja poprawnie się uruchamia (sprawdź logi)"
echo "3. Czy konfiguracja sieciowa Dockera jest poprawna"
echo "4. Spróbuj przebudować kontener z nową konfiguracją:"
echo -e "   ${BLUE}docker-compose down && docker-compose build --no-cache camel-groovy && docker-compose up -d${NC}"