#!/bin/bash

# Parse command line arguments
DROP_TABLE=false
while getopts "d" opt; do
  case $opt in
    d) DROP_TABLE=true ;;
    \?) echo "Invalid option -$OPTARG" >&2 ;;
  esac
done

# Detect OS
OS="unknown"
if [[ "$OSTYPE" == "darwin"* ]]; then
    OS="macos"
elif [[ -f /etc/centos-release ]]; then
    OS="centos"
else
    echo "Unsupported operating system. This script supports macOS and CentOS."
    exit 1
fi

# Set PostgreSQL service and paths for CentOS
if [[ "$OS" == "centos" ]]; then
    PG_SERVICE="postgresql-14"
    export PGDATA="/var/lib/pgsql/14/data"
    export PATH="/usr/pgsql-14/bin:$PATH"
else
    PG_SERVICE="postgresql@14"
fi

# Check if PostgreSQL is running
if ! sudo -u postgres pg_isready -q; then
    echo "Starting PostgreSQL service $PG_SERVICE..."
    if [[ "$OS" == "macos" ]]; then
        brew services start $PG_SERVICE
    elif [[ "$OS" == "centos" ]]; then
        sudo systemctl start $PG_SERVICE
    fi
    sleep 5  # Wait for PostgreSQL to start
fi

# Database configuration
DB_NAME="botpress_logs"
DB_USER="botpress_user"
DB_PASSWORD="mypass"

# Function to create tables
create_tables() {
    local psql_cmd=$1
    $psql_cmd <<EOF
-- Grant schema privileges
GRANT ALL ON SCHEMA public TO $DB_USER;

$(if [ "$DROP_TABLE" = true ]; then echo "DROP TABLE IF EXISTS conversation_logs CASCADE;"; fi)

-- Create conversation_logs table if not exists
CREATE TABLE IF NOT EXISTS conversation_logs (
    id SERIAL PRIMARY KEY,
    conversation_id VARCHAR NOT NULL,
    user_id VARCHAR,
    transcript TEXT NOT NULL,
    timestamp TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    message_metadata JSONB,
    CONSTRAINT conversation_id_idx UNIQUE (conversation_id)
);

-- Create indexes
CREATE INDEX IF NOT EXISTS idx_conversation_id ON conversation_logs(conversation_id);
CREATE INDEX IF NOT EXISTS idx_user_id ON conversation_logs(user_id);
CREATE INDEX IF NOT EXISTS idx_timestamp ON conversation_logs(timestamp);

-- Grant table privileges
GRANT ALL PRIVILEGES ON ALL TABLES IN SCHEMA public TO $DB_USER;
GRANT USAGE, SELECT ON ALL SEQUENCES IN SCHEMA public TO $DB_USER;
EOF
}

if [[ "$OS" == "centos" ]]; then
    # CentOS: Use postgres user for operations
    echo "Setting up database as postgres user..."
    
    # Create user and database
    sudo -u postgres psql -v ON_ERROR_STOP=1 <<EOF
-- Create user if not exists
DO \$\$
BEGIN
  IF NOT EXISTS (SELECT FROM pg_user WHERE usename = '$DB_USER') THEN
    CREATE USER $DB_USER WITH PASSWORD '$DB_PASSWORD';
  END IF;
END
\$\$;

-- Create database if not exists
SELECT 'CREATE DATABASE $DB_NAME'
WHERE NOT EXISTS (SELECT FROM pg_database WHERE datname = '$DB_NAME')\gexec

-- Grant privileges
GRANT ALL PRIVILEGES ON DATABASE $DB_NAME TO $DB_USER;
EOF

    if [ $? -ne 0 ]; then
        echo "Error: Database setup failed. Please check PostgreSQL logs."
        exit 1
    fi

    # Create tables as postgres user
    create_tables "sudo -u postgres psql -d $DB_NAME"

    # Update pg_hba.conf to allow password authentication
    PG_HBA_CONF="$PGDATA/pg_hba.conf"
    if [ -f "$PG_HBA_CONF" ]; then
        echo "Updating PostgreSQL authentication configuration..."
        # Backup the original file
        sudo cp "$PG_HBA_CONF" "${PG_HBA_CONF}.bak"
        # Add MD5 authentication line if it doesn't exist
        if ! sudo grep -q "^host.*all.*all.*127.0.0.1/32.*md5" "$PG_HBA_CONF"; then
            sudo sed -i '/^host.*all.*all.*ident/i host    all             all             127.0.0.1/32            md5' "$PG_HBA_CONF"
            sudo systemctl reload $PG_SERVICE
        fi
    else
        echo "Warning: Could not find pg_hba.conf at $PG_HBA_CONF. You may need to configure authentication manually."
    fi
else
    # macOS: Standard operations
    psql postgres <<EOF
-- Create user if not exists
DO \$\$
BEGIN
  IF NOT EXISTS (SELECT FROM pg_user WHERE usename = '$DB_USER') THEN
    CREATE USER $DB_USER WITH PASSWORD '$DB_PASSWORD';
  END IF;
END
\$\$;

-- Create database if not exists
SELECT 'CREATE DATABASE $DB_NAME'
WHERE NOT EXISTS (SELECT FROM pg_database WHERE datname = '$DB_NAME')\gexec

-- Grant privileges
GRANT ALL PRIVILEGES ON DATABASE $DB_NAME TO $DB_USER;
EOF

    # Create tables
    create_tables "psql -d $DB_NAME"
fi

echo "Database setup completed successfully!"

# Print usage instructions
echo -e "\nUsage:"
echo "  ./dbscript.sh      # Create database and tables if they don't exist"
echo "  ./dbscript.sh -d   # Drop existing tables and recreate them"
