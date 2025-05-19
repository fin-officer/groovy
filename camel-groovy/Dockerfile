FROM eclipse-temurin:17-jdk as build

WORKDIR /build

# Instalacja niezbędnych narzędzi
RUN apt-get update && apt-get install -y curl unzip

# Instalacja Gradle
RUN curl -L https://services.gradle.org/distributions/gradle-8.5-bin.zip -o gradle.zip \
    && unzip gradle.zip -d /opt \
    && ln -s /opt/gradle-8.5/bin/gradle /usr/bin/gradle \
    && rm gradle.zip

# Kopiowanie plików konfiguracyjnych Gradle (dla lepszego cache)
COPY build.gradle settings.gradle ./

# Argument dla obsługi cache - zmień gdy zmieniają się zależności
ARG DEPS_CHECKSUM=0
ENV DEPS_CHECKSUM=${DEPS_CHECKSUM}

# Pobierz wszystkie zależności (cache)
RUN echo "Deps checksum: ${DEPS_CHECKSUM}" && gradle dependencies --no-daemon

# Kopiowanie kodu źródłowego
COPY src ./src

# Ustawienie opcji Gradle dla optymalizacji
ARG GRADLE_OPTS="-Dorg.gradle.daemon=false -Dorg.gradle.caching=true"
ENV GRADLE_OPTS=${GRADLE_OPTS}

# Budowanie aplikacji
RUN gradle clean build -x test --no-daemon --build-cache

# Obraz docelowy
FROM eclipse-temurin:17-jre

WORKDIR /app

# Instalacja niezbędnych narzędzi
RUN apt-get update && apt-get install -y sqlite3 curl jq bash && rm -rf /var/lib/apt/lists/*

# Kopiowanie zbudowanej aplikacji
COPY --from=build /build/build/libs/*.jar app.jar

# Kopiowanie skryptów i plików konfiguracyjnych
COPY scripts /app/scripts
# Ensure scripts have correct line endings and are executable
RUN sed -i 's/\r$//' /app/scripts/*.sh && chmod +x /app/scripts/*.sh

# Kopiowanie plików Groovy
COPY routes /app/routes

# Tworzenie katalogów
RUN mkdir -p /data /logs

# Ekspozycja portu
EXPOSE 8080

# Punkt wejścia
ENTRYPOINT ["/app/scripts/entrypoint.sh"]