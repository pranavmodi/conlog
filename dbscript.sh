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
    # Change to a directory where we have access
    cd /tmp
    
    # Use full paths for PostgreSQL commands
    PG_ISREADY="/usr/pgsql-14/bin/pg_isready"
    PSQL="/usr/pgsql-14/bin/psql"
    
    # Set PGDATA only if we have permission to access it
    if sudo test -d "/var/lib/pgsql/14/data"; then
        export PGDATA="/var/lib/pgsql/14/data"
    fi
else
    PG_SERVICE="postgresql@14"
    PG_ISREADY="pg_isready"
    PSQL="psql"
fi

# Check if PostgreSQL is running
if ! sudo -u postgres $PG_ISREADY -q; then
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
    sudo -u postgres $PSQL -v ON_ERROR_STOP=1 <<EOF
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
    create_tables "sudo -u postgres $PSQL -d $DB_NAME"

    # Try multiple possible locations for pg_hba.conf
    PG_HBA_PATHS=(
        "/var/lib/pgsql/14/data/pg_hba.conf"
        "$(sudo -u postgres $PSQL -t -P format=unaligned -c 'SHOW hba_file' 2>/dev/null)"
    )
    
    PG_HBA_CONF=""
    for path in "${PG_HBA_PATHS[@]}"; do
        if sudo test -f "$path"; then
            PG_HBA_CONF="$path"
            break
        fi
    done

    if [ -n "$PG_HBA_CONF" ]; then
        echo "Found pg_hba.conf at $PG_HBA_CONF"
        echo "Updating PostgreSQL authentication configuration..."
        # Backup the original file
        sudo cp "$PG_HBA_CONF" "${PG_HBA_CONF}.bak"
        # Add MD5 authentication line if it doesn't exist
        if ! sudo grep -q "^host.*all.*all.*127.0.0.1/32.*md5" "$PG_HBA_CONF"; then
            sudo sed -i '/^host.*all.*all.*ident/i host    all             all             127.0.0.1/32            md5' "$PG_HBA_CONF"
            sudo systemctl reload $PG_SERVICE
        fi
    else
        echo "Note: Could not find pg_hba.conf. If you experience connection issues, you may need to configure authentication manually."
        echo "Typical locations checked:"
        printf '%s\n' "${PG_HBA_PATHS[@]}"
    fi
else
    # macOS: Standard operations
    $PSQL postgres <<EOF
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
    create_tables "$PSQL -d $DB_NAME"
fi

echo "Database setup completed successfully!"

# Print usage instructions
echo -e "\nUsage:"
echo "  ./dbscript.sh      # Create database and tables if they don't exist"
echo "  ./dbscript.sh -d   # Drop existing tables and recreate them"
