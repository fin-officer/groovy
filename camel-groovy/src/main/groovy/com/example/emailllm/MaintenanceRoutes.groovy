/*
import org.apache.camel.builder.RouteBuilder
import org.apache.camel.LoggingLevel
import org.springframework.beans.factory.annotation.Value
import org.springframework.stereotype.Component
import groovy.json.JsonOutput
import java.time.LocalDateTime
import java.time.format.DateTimeFormatter

 */
/**
 * Trasa do regularnego sprawdzania i czyszczenia starych emaili.
 *//*

@Component
class MaintenanceRoutes extends RouteBuilder {

    @Value('${maintenance.cleanup.interval:86400000}')  // Domyślnie co 24h (w milisekundach)
    long cleanupInterval

    @Value('${maintenance.email.retention.days:30}')
    int emailRetentionDays

    @Override
    void configure() throws Exception {
        // Trasa do regularnego czyszczenia starych emaili
        from("timer:emailCleanup?period=${cleanupInterval}")
            .routeId("email-cleanup")
            .log(LoggingLevel.INFO, "Uruchomiono czyszczenie starych emaili")
            .process { exchange ->
                // Obliczenie daty granicznej
                def cutoffDate = LocalDateTime.now().minusDays(emailRetentionDays)
                        .format(DateTimeFormatter.ISO_LOCAL_DATE_TIME)

                exchange.getIn().setHeader("cutoffDate", cutoffDate)
            }
            .setBody(simple("DELETE FROM processed_emails WHERE received_date < '\${header.cutoffDate}' AND status IN ('processed', 'failed')"))
            .to("jdbc:dataSource")
            .log(LoggingLevel.INFO, "Usunięto \${body} starych emaili")

        // Trasa do wykonywania optymalizacji bazy SQLite
        from("timer:dbMaintenance?period=604800000")  // Co tydzień (w milisekundach)
            .routeId("db-maintenance")
            .log(LoggingLevel.INFO, "Uruchomiono konserwację bazy danych")
            .process { exchange ->
                def sqlCommands = [
                    "PRAGMA optimize;",
                    "VACUUM;",
                    "ANALYZE;"
                ]

                exchange.getIn().setBody(sqlCommands)
            }
            .split(body())
            .to("jdbc:dataSource")
            .end()
            .log(LoggingLevel.INFO, "Zakończono konserwację bazy danych")

        // Endpoint do ręcznego wywołania zadań konserwacyjnych
        rest("/maintenance")
            .post("/cleanup")
                .description("Ręczne wywołanie czyszczenia starych emaili")
                .route()
                .to("direct:manualCleanup")
                .endRest()
            .post("/optimize")
                .description("Ręczne wywołanie optymalizacji bazy danych")
                .route()
                .to("direct:manualOptimize")
                .endRest()

        // Trasy dla ręcznych zadań konserwacyjnych
        from("direct:manualCleanup")
            .log(LoggingLevel.INFO, "Ręcznie uruchomiono czyszczenie starych emaili")
            .process { exchange ->
                def cutoffDays = exchange.getIn().getHeader("days", Integer.class) ?: emailRetentionDays
                def cutoffDate = LocalDateTime.now().minusDays(cutoffDays)
                        .format(DateTimeFormatter.ISO_LOCAL_DATE_TIME)

                exchange.getIn().setHeader("cutoffDate", cutoffDate)
            }
            .setBody(simple("DELETE FROM processed_emails WHERE received_date < '\${header.cutoffDate}' AND status IN ('processed', 'failed')"))
            .to("jdbc:dataSource")
            .setBody(simple([
                success: true,
                message: "Usunięto ${body} starych emaili",
                timestamp: LocalDateTime.now().format(DateTimeFormatter.ISO_LOCAL_DATE_TIME)
            ]))

        from("direct:manualOptimize")
            .log(LoggingLevel.INFO, "Ręcznie uruchomiono optymalizację bazy danych")
            .process { exchange ->
                def sqlCommands = [
                    "PRAGMA optimize;",
                    "VACUUM;",
                    "ANALYZE;"
                ]

                exchange.getIn().setBody(sqlCommands)
            }
            .split(body())
            .to("jdbc:dataSource")
            .end()
            .setBody(simple([
                success: true,
                message: "Zakończono optymalizację bazy danych",
                timestamp: LocalDateTime.now().format(DateTimeFormatter.ISO_LOCAL_DATE_TIME)
            ]))
    }
} */

import org.apache.camel.builder.RouteBuilder
import org.apache.camel.LoggingLevel
import org.springframework.beans.factory.annotation.Value
import org.springframework.stereotype.Component
import groovy.json.JsonOutput
import java.time.LocalDateTime
import java.time.format.DateTimeFormatter

/**
 * Trasa do regularnego sprawdzania i czyszczenia starych emaili.
 */
@Component
class MaintenanceRoutes extends RouteBuilder {

    @Value('${maintenance.cleanup.interval:86400000}')  // Domyślnie co 24h (w milisekundach)
    long cleanupInterval

    @Value('${maintenance.email.retention.days:30}')
    int emailRetentionDays

    @Override
    void configure() throws Exception {
        // Trasa do regularnego czyszczenia starych emaili
        from("timer:emailCleanup?period=${cleanupInterval}")
            .routeId("email-cleanup")
            .log(LoggingLevel.INFO, "Uruchomiono czyszczenie starych emaili")
            .process { exchange ->
                // Obliczenie daty granicznej
                def cutoffDate = LocalDateTime.now().minusDays(emailRetentionDays)
                        .format(DateTimeFormatter.ISO_LOCAL_DATE_TIME)

                exchange.getIn().setHeader("cutoffDate", cutoffDate)
            }
            .setBody(simple("DELETE FROM processed_emails WHERE received_date < '\${header.cutoffDate}' AND status IN ('processed', 'failed')"))
            .to("jdbc:dataSource")
            .log(LoggingLevel.INFO, "Usunięto \${body} starych emaili")

        // Trasa do wykonywania optymalizacji bazy SQLite
        from("timer:dbMaintenance?period=604800000")  // Co tydzień (w milisekundach)
            .routeId("db-maintenance")
            .log(LoggingLevel.INFO, "Uruchomiono konserwację bazy danych")
            .process { exchange ->
                def sqlCommands = [
                    "PRAGMA optimize;",
                    "VACUUM;",
                    "ANALYZE;"
                ]

                exchange.getIn().setBody(sqlCommands)
            }
            .split(body())
            .to("jdbc:dataSource")
            .end()
            .log(LoggingLevel.INFO, "Zakończono konserwację bazy danych")

        // Endpoint do ręcznego wywołania zadań konserwacyjnych
        rest("/maintenance")
            .post("/cleanup")
                .description("Ręczne wywołanie czyszczenia starych emaili")
                .route()
                .to("direct:manualCleanup")
                .endRest()
            .post("/optimize")
                .description("Ręczne wywołanie optymalizacji bazy danych")
                .route()
                .to("direct:manualOptimize")
                .endRest()

        // Trasy dla ręcznych zadań konserwacyjnych
        from("direct:manualCleanup")
            .log(LoggingLevel.INFO, "Ręcznie uruchomiono czyszczenie starych emaili")
            .process { exchange ->
                def cutoffDays = exchange.getIn().getHeader("days", Integer.class) ?: emailRetentionDays
                def cutoffDate = LocalDateTime.now().minusDays(cutoffDays)
                        .format(DateTimeFormatter.ISO_LOCAL_DATE_TIME)

                exchange.getIn().setHeader("cutoffDate", cutoffDate)
            }
            .setBody(simple("DELETE FROM processed_emails WHERE received_date < '\${header.cutoffDate}' AND status IN ('processed', 'failed')"))
            .to("jdbc:dataSource")
            .setBody(simple([
                success: true,
                message: "Usunięto ${body} starych emaili",
                timestamp: LocalDateTime.now().format(DateTimeFormatter.ISO_LOCAL_DATE_TIME)
            ]))

        from("direct:manualOptimize")
            .log(LoggingLevel.INFO, "Ręcznie uruchomiono optymalizację bazy danych")
            .process { exchange ->
                def sqlCommands = [
                    "PRAGMA optimize;",
                    "VACUUM;",
                    "ANALYZE;"
                ]

                exchange.getIn().setBody(sqlCommands)
            }
            .split(body())
            .to("jdbc:dataSource")
            .end()
            .setBody(simple([
                success: true,
                message: "Zakończono optymalizację bazy danych",
                timestamp: LocalDateTime.now().format(DateTimeFormatter.ISO_LOCAL_DATE_TIME)
            ]))
    }
}