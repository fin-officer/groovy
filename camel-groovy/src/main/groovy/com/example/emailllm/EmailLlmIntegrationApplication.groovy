package com.example.emailllm

import org.springframework.boot.SpringApplication
import org.springframework.boot.autoconfigure.SpringBootApplication
import org.springframework.context.annotation.Bean
import org.springframework.context.annotation.ComponentScan
import org.springframework.beans.factory.annotation.Value
import org.springframework.boot.context.properties.EnableConfigurationProperties
import javax.sql.DataSource
import org.springframework.jdbc.datasource.DriverManagerDataSource
import org.springframework.context.annotation.PropertySource

@SpringBootApplication
@ComponentScan(["com.example.emailllm"])
@EnableConfigurationProperties
@PropertySource(value = "file:/app/application-override.properties", ignoreResourceNotFound = true)
class EmailLlmIntegrationApplication {

    private static final List<String> REQUIRED_ENV_VARIABLES = [
            "OLLAMA_HOST",
            "OLLAMA_PORT",
            "SQLITE_DB_PATH",
            "SERVER_PORT"
    ]

    static void main(String[] args) {
        logApplicationStartup()
        logEnvironmentVariables()
        SpringApplication.run(EmailLlmIntegrationApplication.class, args)
    }

    private static void logApplicationStartup() {
        println "Starting Email-LLM Integration Application..."
        println "Java version: ${System.getProperty('java.version')}"
        println "Current directory: ${new File('.').absolutePath}"
    }

    private static void logEnvironmentVariables() {
        REQUIRED_ENV_VARIABLES.each { variableName ->
            def value = System.getenv(variableName) ?: 'not set'
            println "${variableName}: ${value}"
        }
    }

    // SQLite DataSource configuration
    @Bean
    DataSource dataSource(
            @Value('${SQLITE_DB_PATH:/data/emails.db}') String sqliteDatabasePath,
            @Value('${SQLITE_CONNECTION_TIMEOUT:30}') int connectionTimeout) {

        String jdbcUrl = "jdbc:sqlite:" + sqliteDatabasePath
        println "Initializing SQLite DataSource: ${jdbcUrl}"

        def dataSource = new DriverManagerDataSource()
        dataSource.driverClassName = "org.sqlite.JDBC"
        dataSource.url = jdbcUrl

        // Connection settings
        dataSource.connectionProperties.setProperty("journal_mode", "WAL")
        dataSource.connectionProperties.setProperty("synchronous", "NORMAL")
        dataSource.connectionProperties.setProperty("cache_size", "-102400")
        dataSource.connectionProperties.setProperty("temp_store", "MEMORY")
        dataSource.connectionProperties.setProperty("busy_timeout", String.valueOf(connectionTimeout * 1000))

        // Sprawdź, czy baza danych istnieje, jeśli nie, utwórz ją
        try {
            def connection = dataSource.connection
            println "Successfully connected to SQLite database: ${jdbcUrl}"
            connection.close()
        } catch (Exception e) {
            println "Warning: Error connecting to SQLite database: ${e.message}"
            println "Make sure the database file path is accessible and writable"
        }

        return dataSource
    }
}