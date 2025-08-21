-- Initialize database for local development
-- Create database if it doesn't exist (PostgreSQL compatible syntax)
SELECT 'CREATE DATABASE appdb' WHERE NOT EXISTS (SELECT FROM pg_database WHERE datname = 'appdb')\gexec
SELECT 'CREATE DATABASE airflow_db' WHERE NOT EXISTS (SELECT FROM pg_database WHERE datname = 'airflow_db')\gexec
SELECT 'CREATE DATABASE authdb' WHERE NOT EXISTS (SELECT FROM pg_database WHERE datname = 'authdb')\gexec
SELECT 'CREATE DATABASE productdb' WHERE NOT EXISTS (SELECT FROM pg_database WHERE datname = 'productdb')\gexec
SELECT 'CREATE DATABASE cartdb' WHERE NOT EXISTS (SELECT FROM pg_database WHERE datname = 'cartdb')\gexec
SELECT 'CREATE DATABASE paymentdb' WHERE NOT EXISTS (SELECT FROM pg_database WHERE datname = 'paymentdb')\gexec
SELECT 'CREATE DATABASE orderdb' WHERE NOT EXISTS (SELECT FROM pg_database WHERE datname = 'orderdb')\gexec

-- Create basic tables (these will be managed by Flask-Migrate in production)
\c appdb;

-- Users table
CREATE TABLE IF NOT EXISTS users (
    id SERIAL PRIMARY KEY,
    email VARCHAR(255) UNIQUE NOT NULL,
    password_hash VARCHAR(255) NOT NULL,
    first_name VARCHAR(100),
    last_name VARCHAR(100),
    is_active BOOLEAN DEFAULT TRUE,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Tasks table
CREATE TABLE IF NOT EXISTS tasks (
    id SERIAL PRIMARY KEY,
    title VARCHAR(255) NOT NULL,
    description TEXT,
    status VARCHAR(20) DEFAULT 'pending',
    priority VARCHAR(10) DEFAULT 'medium',
    user_id INTEGER REFERENCES users(id) ON DELETE CASCADE,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Analytics events table
CREATE TABLE IF NOT EXISTS analytics_events (
    id SERIAL PRIMARY KEY,
    event_type VARCHAR(100) NOT NULL,
    user_id INTEGER REFERENCES users(id) ON DELETE SET NULL,
    properties JSONB,
    timestamp TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Insert sample data
INSERT INTO users (email, password_hash, first_name, last_name) VALUES
('admin@example.com', '$2b$12$LQv3c1yqBWVHxkd0LHAkCOYz6TtxMQJqhN8/LewdBPj6JjyqKLmsG', 'Admin', 'User'),
('user@example.com', '$2b$12$LQv3c1yqBWVHxkd0LHAkCOYz6TtxMQJqhN8/LewdBPj6JjyqKLmsG', 'Test', 'User')
ON CONFLICT (email) DO NOTHING;

INSERT INTO tasks (title, description, status, user_id) VALUES
('Setup Development Environment', 'Configure Docker and local services', 'completed', 1),
('Implement User Authentication', 'Add JWT-based authentication', 'in_progress', 1),
('Create API Documentation', 'Generate Swagger/OpenAPI docs', 'pending', 2)
ON CONFLICT DO NOTHING;
