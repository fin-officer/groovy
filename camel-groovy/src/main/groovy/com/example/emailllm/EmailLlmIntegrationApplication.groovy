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
import java.util.Properties

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
        SpringApplication.run(EmailLlmIntegrationApplication, args)
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

        // Sprawdź, czy katalog dla bazy danych istnieje
        File dbDir = new File(sqliteDatabasePath).parentFile
        if (dbDir != null && !dbDir.exists()) {
            println "Creating directory for SQLite database: ${dbDir.absolutePath}"
            dbDir.mkdirs()
        }

        // Utworzenie datasource
        DriverManagerDataSource dataSource = new DriverManagerDataSource()
        dataSource.setDriverClassName("org.sqlite.JDBC")
        dataSource.setUrl(jdbcUrl)

        // Utworzenie properties - wcześniej był tu null
        Properties props = new Properties()
        props.setProperty("journal_mode", "WAL")
        props.setProperty("synchronous", "NORMAL")
        props.setProperty("cache_size", "-102400")
        props.setProperty("temp_store", "MEMORY")
        props.setProperty("busy_timeout", String.valueOf(connectionTimeout * 1000))

        // Przypisanie properties
        dataSource.setConnectionProperties(props)

        // Próba połączenia
        try {
            def connection = dataSource.getConnection()
            println "Successfully connected to SQLite database: ${jdbcUrl}"

            // Sprawdź, czy tabele istnieją, jeśli nie, utwórz je
            def statement = connection.createStatement()

            // Sprawdź czy tabela processed_emails istnieje
            def result = statement.executeQuery(
                    "SELECT name FROM sqlite_master WHERE type='table' AND name='processed_emails'"
            )

            if (!result.next()) {
                println "Creating tables in SQLite database..."

                // Utwórz tabelę processed_emails
                statement.execute("""
                    CREATE TABLE IF NOT EXISTS processed_emails (
                        id INTEGER PRIMARY KEY AUTOINCREMENT,
                        message_id TEXT UNIQUE,
                        subject TEXT,
                        sender TEXT,
                        recipients TEXT,
                        received_date TEXT,
                        processed_date TEXT,
                        body_text TEXT,
                        body_html TEXT,
                        status TEXT,
                        llm_analysis TEXT,
                        metadata TEXT
                    )
                """)

                // Utwórz indeksy
                statement.execute("CREATE INDEX IF NOT EXISTS idx_processed_emails_message_id ON processed_emails(message_id)")
                statement.execute("CREATE INDEX IF NOT EXISTS idx_processed_emails_status ON processed_emails(status)")
                statement.execute("CREATE INDEX IF NOT EXISTS idx_processed_emails_received_date ON processed_emails(received_date)")

                // Utwórz tabelę email_attachments
                statement.execute("""
                    CREATE TABLE IF NOT EXISTS email_attachments (
                        id INTEGER PRIMARY KEY AUTOINCREMENT,
                        email_id INTEGER,
                        filename TEXT,
                        content_type TEXT,
                        size INTEGER,
                        content BLOB,
                        FOREIGN KEY (email_id) REFERENCES processed_emails(id) ON DELETE CASCADE
                    )
                """)

                println "Tables created successfully"
            }

            connection.close()
        } catch (Exception e) {
            println "Warning: Error connecting to SQLite database: ${e.message}"
            println "Make sure the database file path is accessible and writable: ${sqliteDatabasePath}"

            // Nie rzucaj wyjątku - pozwól aplikacji kontynuować
            // Baza zostanie stworzona przy pierwszym zapytaniu
        }

        return dataSource
    }
}