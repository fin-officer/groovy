#!/bin/bash
set -e

# Ścieżka do bazy danych
DB_PATH=${SQLITE_DB_PATH:-/data/emails.db}

# Sprawdź, czy baza danych istnieje
if [ ! -f "$DB_PATH" ]; then
    echo "Inicjalizacja bazy danych SQLite..."

    # Utwórz katalog dla bazy danych, jeśli nie istnieje
    mkdir -p $(dirname "$DB_PATH")

    # Inicjalizacja bazy danych z optymalizacjami
    sqlite3 "$DB_PATH" <<EOSQL
PRAGMA journal_mode=${SQLITE_JOURNAL_MODE:-WAL};
PRAGMA synchronous=${SQLITE_SYNCHRONOUS:-NORMAL};
PRAGMA cache_size=-${SQLITE_CACHE_SIZE:-102400};
PRAGMA temp_store=MEMORY;
PRAGMA mmap_size=1073741824;

-- Tabela dla przetworzonych emaili
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
);

-- Indeksy
CREATE INDEX IF NOT EXISTS idx_processed_emails_message_id ON processed_emails(message_id);
CREATE INDEX IF NOT EXISTS idx_processed_emails_status ON processed_emails(status);
CREATE INDEX IF NOT EXISTS idx_processed_emails_received_date ON processed_emails(received_date);

-- Tabela dla załączników
CREATE TABLE IF NOT EXISTS email_attachments (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    email_id INTEGER,
    filename TEXT,
    content_type TEXT,
    size INTEGER,
    content BLOB,
    FOREIGN KEY (email_id) REFERENCES processed_emails(id) ON DELETE CASCADE
);

VACUUM;
EOSQL

    echo "Baza danych utworzona i zoptymalizowana."
fi

# Uruchom aplikację
exec java -jar /app/app.jar
