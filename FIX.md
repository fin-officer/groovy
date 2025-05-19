# Troubleshooting Guide for Email-LLM Integration Project

## Problem Summary

The Email-LLM Integration project is failing to build due to two main issues:

1. **Missing Docker Images**: The original Dockerfile references deprecated Docker images (`openjdk:17-jdk-slim` and `openjdk:17-jre-slim`).
2. **Dependency Conflicts**: There's a conflict between Groovy versions - the project uses Groovy 3.0.19 while Apache Camel 4.1.0 requires Apache Groovy 4.0.15.
3. **Missing Source Files**: The required Java/Groovy source files are missing or contain errors.

## Step-by-Step Solution

### 1. Update the Dockerfile

Replace the original Dockerfile with one that uses Eclipse Temurin images instead of the deprecated OpenJDK images:

```dockerfile
# Build stage
FROM eclipse-temurin:17-jdk as build

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
FROM eclipse-temurin:17-jre

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
```

### 2. Fix the build.gradle File

Update the build.gradle file to use Apache Groovy 4.0.15 instead of Codehaus Groovy 3.0.19:

```groovy
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

configurations.all {
    resolutionStrategy {
        // Force all Groovy modules to use Apache Groovy 4.0.15 version
        force 'org.apache.groovy:groovy:4.0.15'
        force 'org.apache.groovy:groovy-json:4.0.15'
        force 'org.apache.groovy:groovy-xml:4.0.15'
    }
}

dependencies {
    // Spring Boot
    implementation 'org.springframework.boot:spring-boot-starter-web'
    implementation 'org.springframework.boot:spring-boot-starter-actuator'
    implementation 'org.springframework.boot:spring-boot-starter-mail'

    // Groovy - use Apache Groovy 4.x instead of Codehaus Groovy 3.x
    implementation 'org.apache.groovy:groovy-all:4.0.15'

    // Apache Camel
    implementation "org.apache.camel.springboot:camel-spring-boot-starter:${camelVersion}"
    implementation "org.apache.camel.springboot:camel-groovy-starter:${camelVersion}"
    implementation "org.apache.camel.springboot:camel-mail-starter:${camelVersion}"
    implementation "org.apache.camel.springboot:camel-http-starter:${camelVersion}"
    implementation "org.apache.camel.springboot:camel-jdbc-starter:${camelVersion}"
    implementation "org.apache.camel.springboot:camel-sql-starter:${camelVersion}"
    implementation "org.apache.camel.springboot:camel-jackson-starter:${camelVersion}"
    implementation "org.apache.camel.springboot:camel-file-starter:${camelVersion}"
    implementation "org.apache.camel.springboot:camel-direct-starter:${camelVersion}"
    implementation "org.apache.camel.springboot:camel-stream-starter:${camelVersion}"
    implementation "org.apache.camel.springboot:camel-rest-starter:${camelVersion}"
    implementation "org.apache.camel.springboot:camel-servlet-starter:${camelVersion}"
    implementation "org.apache.camel.springboot:camel-quartz-starter:${camelVersion}"

    // Jakarta Mail API (for Jakarta EE 9+)
    implementation 'com.sun.mail:jakarta.mail:2.0.1'

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
    testImplementation "org.apache.camel:camel-test-spring-junit5:${camelVersion}"
}

test {
    useJUnitPlatform()
}
```

### 3. Create Required Source Files

Create all the necessary source files and directories:

1. Create the main application class (`EmailLlmIntegrationApplication.groovy`)
2. Create the routes configuration (`EmailProcessingRoute.groovy`) without javax.mail imports
3. Create maintenance routes (`MaintenanceRoutes.groovy`)
4. Create REST API configuration (`RestApiConfig.groovy`)
5. Create application configuration (`application.yml`)
6. Create a dynamic Ollama route (`OllamaDirectRoute.groovy`)

### 4. Automated Fix

To simplify the process, use the provided `fix-project.sh` script to automatically fix all the issues:

1. Download the fix script:
   ```bash
   # Create the fix script
   vi fix-project.sh
   # Paste the content of the script and save
   chmod +x fix-project.sh
   ```

2. Run the fix script:
   ```bash
   ./fix-project.sh
   ```

3. After the script completes, start the application:
   ```bash
   ./start.sh
   ```

## What the Fix Does

1. **Updates the Dockerfile**: Replaces deprecated OpenJDK images with Eclipse Temurin images.
2. **Updates build.gradle**: Changes the Groovy dependency from version 3.0.19 to 4.0.15 and adds resolution strategy.
3. **Adds missing source files**: Creates all the necessary Groovy classes and configuration files.
4. **Fixes the javax.mail import issue**: Creates a modified version of the route without the problematic imports.

## Verification

After applying the fixes, the application should build and start successfully. You should be able to access:

- API application: http://localhost:8080/api
- API documentation: http://localhost:8080/api/api-doc
- Test email panel: http://localhost:8025
- SQLite admin panel: http://localhost:8081

## Additional Resources

- [Eclipse Temurin Docker Images](https://hub.docker.com/_/eclipse-temurin)
- [Apache Groovy Documentation](https://groovy-lang.org/documentation.html)
- [Apache Camel Documentation](https://camel.apache.org/manual/camel-4x-upgrade-guide.html)