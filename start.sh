#!/bin/bash
# Skrypt uruchamiający projekt Email-LLM Integration

GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

echo -e "\033[0;34m[INFO]\033[0m Uruchamianie projektu Email-LLM Integration..."

# Sprawdź, czy Docker działa
if ! docker info > /dev/null 2>&1; then
    echo -e "\033[0;31m[BŁĄD]\033[0m Docker nie jest uruchomiony. Uruchom Docker i spróbuj ponownie."
    exit 1
fi

# Uruchom docker-compose
echo -e "\033[0;34m[INFO]\033[0m Uruchamianie kontenerów..."
docker-compose up -d

# Poczekaj na uruchomienie Ollama
echo -e "\033[0;34m[INFO]\033[0m Czekam na uruchomienie Ollama..."
until docker exec -i ollama curl -s http://localhost:11434/api/health &> /dev/null; do
    echo -n "."
    sleep 2
done
echo ""

# Pobierz model, jeśli nie istnieje
if ! docker exec -i ollama ollama list | grep -q mistral; then
    echo -e "\033[0;34m[INFO]\033[0m Pobieranie modelu Mistral (może to potrwać kilka minut)..."
    docker exec -i ollama ollama pull mistral
fi

# Poczekaj na uruchomienie aplikacji
echo -e "\033[0;34m[INFO]\033[0m Czekam na uruchomienie aplikacji..."
until curl -s http://localhost:8080/api/health &> /dev/null; do
    echo -n "."
    sleep 2
done
echo ""

echo -e "\033[0;32m[SUKCES]\033[0m Projekt uruchomiony pomyślnie!"
echo ""
echo "Dostępne usługi:"
echo -e "\033[0;34m* API aplikacji:\033[0m http://localhost:8080/api"
echo -e "\033[0;34m* Dokumentacja API:\033[0m http://localhost:8080/api/api-doc"
echo -e "\033[0;34m* Panel testowej skrzynki email:\033[0m http://localhost:8025"
echo -e "\033[0;34m* Panel administracyjny SQLite:\033[0m http://localhost:8081"
echo ""
echo -e "\033[1;33mAby zatrzymać aplikację, użyj polecenia:\033[0m docker-compose down"
