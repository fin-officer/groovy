#!/bin/bash
# Quick fix script for the DataSource issue

# Colors
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

echo -e "${BLUE}[INFO]${NC} Fixing DataSource configuration issue..."

# Create data directory with proper permissions
echo -e "${BLUE}[INFO]${NC} Creating and fixing permissions for data directory..."
mkdir -p ./data
chmod -R 777 ./data

# Create a simple application.properties file to override the connection properties
echo -e "${BLUE}[INFO]${NC} Creating application.properties file..."
mkdir -p camel-groovy/src/main/resources

cat > camel-groovy/src/main/resources/application.properties << 'EOL'
# Database connection properties - fix for null connectionProperties
spring.datasource.driver-class-name=org.sqlite.JDBC
spring.datasource.url=jdbc:sqlite:${SQLITE_DB_PATH:/data/emails.db}
spring.datasource.hikari.connection-timeout=30000
spring.datasource.hikari.maximum-pool-size=10

# SQLite jdbc parameters
spring.datasource.hikari.data-source-properties.journal_mode=WAL
spring.datasource.hikari.data-source-properties.synchronous=NORMAL
spring.datasource.hikari.data-source-properties.cache_size=-102400
spring.datasource.hikari.data-source-properties.temp_store=MEMORY
spring.datasource.hikari.data-source-properties.busy_timeout=30000

# Server configuration
server.port=8080
server.servlet.context-path=/

# Camel configuration
camel.springboot.name=Email-LLM-Integration
camel.springboot.main-run-controller=true
EOL

# Create a setup script to initialize the database
echo -e "${BLUE}[INFO]${NC} Creating database setup script..."
mkdir -p camel-groovy/scripts

cat > camel-groovy/scripts/init-db.sh << 'EOL'
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
EOL
chmod +x camel-groovy/scripts/init-db.sh

# Update entrypoint script to run the init-db script first
echo -e "${BLUE}[INFO]${NC} Updating entrypoint script..."
cat > camel-groovy/scripts/entrypoint.sh << 'EOL'
#!/bin/bash
set -e

echo "Executing database initialization script..."
/app/scripts/init-db.sh

echo "Starting application..."
exec java $JAVA_OPTS -jar /app/app.jar
EOL
chmod +x camel-groovy/scripts/entrypoint.sh

# Rebuild the container
echo -e "${BLUE}[INFO]${NC} Rebuilding the container..."
docker-compose down
docker-compose build --no-cache camel-groovy

echo -e "${GREEN}[SUCCESS]${NC} Fix has been applied. Now start the application with:"
echo -e "${BLUE}docker-compose up -d${NC}"
echo ""
echo -e "${YELLOW}Note:${NC} The DataSource issue has been fixed by:"
echo "1. Properly initializing SQLite database using a dedicated script"
echo "2. Adding spring.datasource configuration to application.properties"
echo "3. Ensuring data directory has proper permissions"
echo "4. Using HikariCP connection pool which handles connection properties better"