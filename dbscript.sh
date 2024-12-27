#!/bin/bash

# Parse command line arguments
DROP_TABLE=false
while getopts "d" opt; do
  case $opt in
    d) DROP_TABLE=true ;;
    \?) echo "Invalid option -$OPTARG" >&2 ;;
  esac
done

# Check if PostgreSQL is running
if ! pg_isready > /dev/null 2>&1; then
    echo "Starting PostgreSQL service..."
    brew services start postgresql@14
    sleep 5  # Wait for PostgreSQL to start
fi

# Database configuration
DB_NAME="botpress_logs"
DB_USER="botpress_user"
DB_PASSWORD="mypass"

# Create database and user
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

# Connect to the database and create tables
psql -d $DB_NAME <<EOF
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

echo "Database setup completed successfully!"

# Print usage instructions
echo -e "\nUsage:"
echo "  ./dbscript.sh      # Create database and tables if they don't exist"
echo "  ./dbscript.sh -d   # Drop existing tables and recreate them"
