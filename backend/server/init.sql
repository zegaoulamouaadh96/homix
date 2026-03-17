-- Create app user if not exists
DO $$ BEGIN
    IF NOT EXISTS (SELECT FROM pg_user WHERE usename = 'app') THEN
        CREATE USER app WITH PASSWORD 'app123';
    END IF;
END $$;

-- Create smarthome database if not exists
DO $$ BEGIN
    IF NOT EXISTS (SELECT FROM pg_database WHERE datname = 'smarthome') THEN
        CREATE DATABASE smarthome OWNER app;
    END IF;
END $$;

-- Grant privileges
GRANT ALL PRIVILEGES ON DATABASE smarthome TO app;
ALTER USER app CREATEDB;
