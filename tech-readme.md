brew services start postgresql@14

# Connect to PostgreSQL as the postgres user
psql postgres

# Inside psql, create a new database
CREATE DATABASE botpress_logs;

# Create a new user with a password
CREATE USER botpress_user WITH PASSWORD 'your_secure_password';

# Grant privileges to the user on the database
GRANT ALL PRIVILEGES ON DATABASE botpress_logs TO botpress_user;

# Connect to the botpress_logs database
\c botpress_logs

# Grant schema privileges to the user
GRANT ALL ON SCHEMA public TO botpress_user;