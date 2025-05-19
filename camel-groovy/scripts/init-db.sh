#!/bin/bash
# Script to initialize the SQLite database

DB_PATH=${SQLITE_DB_PATH:-/data/emails.db}
DB_DIR=$(dirname "$DB_PATH")

# Create directory if it doesn't exist
mkdir -p "$DB_DIR"
chmod 777 "$DB_DIR"

# Check if database already exists
if [ ! -f "$DB_PATH" ]; then
    echo "Creating SQLite database at $DB_PATH"

    # Create the SQLite database with tables
    sqlite3 "$DB_PATH" <<SQL_SCRIPT
-- Set pragmas
PRAGMA journal_mode=WAL;
PRAGMA synchronous=NORMAL;
PRAGMA cache_size=-102400;
PRAGMA temp_store=MEMORY;
PRAGMA foreign_keys=ON;

-- Create processed_emails table
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

-- Create indexes
CREATE INDEX IF NOT EXISTS idx_processed_emails_message_id ON processed_emails(message_id);
CREATE INDEX IF NOT EXISTS idx_processed_emails_status ON processed_emails(status);
CREATE INDEX IF NOT EXISTS idx_processed_emails_received_date ON processed_emails(received_date);

-- Create attachments table
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
SQL_SCRIPT

    echo "Database created successfully"

    # Set permissions
    chmod 666 "$DB_PATH"
else
    echo "Database already exists at $DB_PATH"
fi
