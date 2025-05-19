FROM ollama/ollama:latest

# Ustaw zmienne środowiskowe dla szybszego uruchamiania
ENV OLLAMA_HOST=0.0.0.0
ENV OLLAMA_KEEP_ALIVE=1

# Utwórz skrypt startowy
RUN echo '#!/bin/sh \n\
# Uruchom serwer Ollama w tle \n\
ollama serve & \n\
# Zaczekaj na uruchomienie serwera \n\
echo "Czekam na uruchomienie serwera Ollama..." \n\
sleep 10 \n\
# Pobierz model, jeśli nie istnieje \n\
MODEL=${MODEL:-phi3:mini} \n\
if ! ollama list | grep -q "$MODEL"; then \n\
    echo "Pobieranie modelu $MODEL..." \n\
    ollama pull $MODEL \n\
fi \n\
# Czekaj na zakończenie procesu w tle \n\
wait' > /entrypoint.sh && \
    chmod +x /entrypoint.sh

HEALTHCHECK --interval=10s --timeout=5s --start-period=20s --retries=5 \
  CMD curl -f http://localhost:11434/api/health || exit 1

ENTRYPOINT ["/entrypoint.sh"]
