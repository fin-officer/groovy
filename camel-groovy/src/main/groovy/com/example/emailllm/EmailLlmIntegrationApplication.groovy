/*
package com.example.emailllm

import org.springframework.boot.SpringApplication
import org.springframework.boot.autoconfigure.SpringBootApplication
import org.springframework.boot.context.properties.ConfigurationProperties
import org.springframework.context.annotation.Bean
import org.springframework.context.annotation.ComponentScan
import javax.sql.DataSource
import org.springframework.jdbc.datasource.DriverManagerDataSource

@SpringBootApplication
@ComponentScan(["com.example.emailllm"])
class EmailLlmIntegrationApplication {

    static void main(String[] args) {
        SpringApplication.run(EmailLlmIntegrationApplication.class, args)
    }

    // Konfiguracja DataSource dla SQLite
    @Bean
    DataSource dataSource(
            @org.springframework.beans.factory.annotation.Value('${sqlite.db.path}') String sqliteDatabasePath,
            @org.springframework.beans.factory.annotation.Value('${sqlite.connection.timeout:30}') int connectionTimeout) {

        String jdbcUrl = "jdbc:sqlite:" + sqliteDatabasePath
        println "Inicjalizacja DataSource SQLite: ${jdbcUrl}"

        def dataSource = new DriverManagerDataSource()
        dataSource.driverClassName = "org.sqlite.JDBC"
        dataSource.url = jdbcUrl

        // Konfiguracja połączenia
        dataSource.connectionProperties.setProperty("journal_mode", "WAL")
        dataSource.connectionProperties.setProperty("synchronous", "NORMAL")
        dataSource.connectionProperties.setProperty("cache_size", "-102400")
        dataSource.connectionProperties.setProperty("temp_store", "MEMORY")
        dataSource.connectionProperties.setProperty("busy_timeout", String.valueOf(connectionTimeout * 1000))

        return dataSource
    }
} */

package com.example.emailllm

import org.springframework.boot.SpringApplication
import org.springframework.boot.autoconfigure.SpringBootApplication
import org.springframework.boot.context.properties.ConfigurationProperties
import org.springframework.context.annotation.Bean
import org.springframework.context.annotation.ComponentScan
import javax.sql.DataSource
import org.springframework.jdbc.datasource.DriverManagerDataSource

@SpringBootApplication
@ComponentScan(["com.example.emailllm"])
class EmailLlmIntegrationApplication {

    static void main(String[] args) {
        SpringApplication.run(EmailLlmIntegrationApplication, args)
    }

    // Konfiguracja DataSource dla SQLite
    @Bean
    DataSource dataSource(
            @org.springframework.beans.factory.annotation.Value('${sqlite.db.path}') String sqliteDatabasePath,
            @org.springframework.beans.factory.annotation.Value('${sqlite.connection.timeout:30}') int connectionTimeout) {

        String jdbcUrl = "jdbc:sqlite:" + sqliteDatabasePath
        println "Inicjalizacja DataSource SQLite: ${jdbcUrl}"

        def dataSource = new DriverManagerDataSource()
        dataSource.driverClassName = "org.sqlite.JDBC"
        dataSource.url = jdbcUrl

        // Konfiguracja połączenia
        dataSource.connectionProperties.setProperty("journal_mode", "WAL")
        dataSource.connectionProperties.setProperty("synchronous", "NORMAL")
        dataSource.connectionProperties.setProperty("cache_size", "-102400")
        dataSource.connectionProperties.setProperty("temp_store", "MEMORY")
        dataSource.connectionProperties.setProperty("busy_timeout", String.valueOf(connectionTimeout * 1000))

        return dataSource
    }
}