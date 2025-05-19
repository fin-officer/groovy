#!/bin/bash
# Skrypt do testowania API aplikacji Email-LLM Integration

GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

# Funkcja do wykonywania żądań
call_api() {
    local method=$1
    local endpoint=$2
    local data=$3
    local description=$4

    echo -e "\033[0;34m[TEST]\033[0m $description"

    if [[ -z "$data" ]]; then
        response=$(curl -s -X $method http://localhost:8080$endpoint -H "Content-Type: application/json")
    else
        response=$(curl -s -X $method http://localhost:8080$endpoint -H "Content-Type: application/json" -d "$data")
    fi

    echo -e "\033[1;33mOdpowiedź:\033[0m"
    echo $response | jq '.' || echo $response
    echo ""
}

# Sprawdź, czy jq jest zainstalowane
if ! command -v jq &> /dev/null; then
    echo -e "\033[1;33m[UWAGA]\033[0m Narzędzie jq nie jest zainstalowane. Odpowiedzi JSON nie będą ładnie formatowane."
    jq() { cat; }
fi

# Sprawdź, czy aplikacja jest uruchomiona
echo -e "\033[0;34m[INFO]\033[0m Sprawdzanie, czy aplikacja jest uruchomiona..."
if ! curl -s http://localhost:8080/api/health &> /dev/null; then
    echo -e "\033[0;31m[BŁĄD]\033[0m Aplikacja nie jest uruchomiona. Uruchom aplikację i spróbuj ponownie."
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

echo -e "\033[0;32m[KONIEC]\033[0m Wszystkie testy zakończone."
