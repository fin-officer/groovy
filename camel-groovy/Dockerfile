FROM openjdk:17-jdk-slim as build

WORKDIR /build

# Instalacja niezbędnych narzędzi
RUN apt-get update && apt-get install -y curl unzip

# Instalacja Gradle
RUN curl -L https://services.gradle.org/distributions/gradle-8.5-bin.zip -o gradle.zip \
    && unzip gradle.zip -d /opt \
    && ln -s /opt/gradle-8.5/bin/gradle /usr/bin/gradle \
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
