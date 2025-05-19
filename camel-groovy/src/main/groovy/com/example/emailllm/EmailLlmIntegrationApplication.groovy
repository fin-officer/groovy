package com.example.emailllm

import org.springframework.boot.SpringApplication
import org.springframework.boot.autoconfigure.SpringBootApplication
import org.springframework.context.annotation.Bean
import org.springframework.context.annotation.ComponentScan
import org.springframework.beans.factory.annotation.Value
import javax.sql.DataSource
import org.springframework.jdbc.datasource.DriverManagerDataSource

@SpringBootApplication
@ComponentScan(["com.example.emailllm"])
class EmailLlmIntegrationApplication {

    static void main(String[] args) {
        SpringApplication.run(EmailLlmIntegrationApplication, args)
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

        return dataSource
    }
}