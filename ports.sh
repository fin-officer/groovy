#!/bin/bash
# Skrypt do sprawdzania i zmiany zajętego portu w konfiguracji

GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

ENV_FILE=".env"
DEFAULT_PORT="8083"

echo -e "${BLUE}[INFO]${NC} Sprawdzanie dostępności portów..."

# Funkcja sprawdzająca, czy port jest używany
is_port_in_use() {
    if command -v nc &> /dev/null; then
        nc -z localhost $1 &> /dev/null
        return $?
    elif command -v lsof &> /dev/null; then
        lsof -i :$1 &> /dev/null
        return $?
    else
        # Prosta metoda - próba otwarcia gniazda
        (echo > /dev/tcp/localhost/$1) &> /dev/null
        return $?
    fi
}

# Funkcja znajdująca wolny port
find_free_port() {
    local port=$1
    while is_port_in_use $port; do
        echo -e "${YELLOW}[UWAGA]${NC} Port $port jest zajęty, próbuję innego portu..."
        port=$((port + 1))
    done
    echo $port
}

# Sprawdź i zaktualizuj port API aplikacji
if [ -f "$ENV_FILE" ]; then
    CURRENT_PORT=$(grep "SERVER_PORT=" "$ENV_FILE" | cut -d '=' -f2)
    if [ -z "$CURRENT_PORT" ]; then
        CURRENT_PORT=$DEFAULT_PORT
    fi

    echo -e "${BLUE}[INFO]${NC} Obecny port API aplikacji: $CURRENT_PORT"

    if is_port_in_use $CURRENT_PORT; then
        NEW_PORT=$(find_free_port $CURRENT_PORT)
        echo -e "${YELLOW}[UWAGA]${NC} Port $CURRENT_PORT jest zajęty. Zmieniam na port $NEW_PORT."

        # Aktualizuj plik .env
        if grep -q "SERVER_PORT=" "$ENV_FILE"; then
            sed -i "s/SERVER_PORT=.*/SERVER_PORT=$NEW_PORT/" "$ENV_FILE"
        else
            echo "SERVER_PORT=$NEW_PORT" >> "$ENV_FILE"
        fi

        echo -e "${GREEN}[SUKCES]${NC} Zaktualizowano port API w pliku $ENV_FILE na $NEW_PORT."
    else
        echo -e "${GREEN}[SUKCES]${NC} Port $CURRENT_PORT jest dostępny dla API aplikacji."
    fi
else
    echo -e "${RED}[BŁĄD]${NC} Nie znaleziono pliku $ENV_FILE."
    exit 1
fi

# Sprawdź i zaktualizuj inne porty używane w projekcie
for PORT_VAR in "MAILHOG_UI_PORT" "ADMINER_PORT" "OLLAMA_EXTERNAL_PORT"; do
    if [ -f "$ENV_FILE" ]; then
        PORT_VALUE=$(grep "$PORT_VAR=" "$ENV_FILE" | cut -d '=' -f2)
        if [ -n "$PORT_VALUE" ]; then
            echo -e "${BLUE}[INFO]${NC} Sprawdzam port $PORT_VAR: $PORT_VALUE"

            if is_port_in_use $PORT_VALUE; then
                NEW_PORT_VALUE=$(find_free_port $PORT_VALUE)
                echo -e "${YELLOW}[UWAGA]${NC} Port $PORT_VALUE ($PORT_VAR) jest zajęty. Zmieniam na port $NEW_PORT_VALUE."

                # Aktualizuj plik .env
                sed -i "s/$PORT_VAR=.*/$PORT_VAR=$NEW_PORT_VALUE/" "$ENV_FILE"

                echo -e "${GREEN}[SUKCES]${NC} Zaktualizowano $PORT_VAR w pliku $ENV_FILE na $NEW_PORT_VALUE."
            else
                echo -e "${GREEN}[SUKCES]${NC} Port $PORT_VALUE ($PORT_VAR) jest dostępny."
            fi
        fi
    fi
done

echo -e "${GREEN}[ZAKOŃCZONO]${NC} Wszystkie porty zostały sprawdzone i zaktualizowane."