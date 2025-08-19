---- Initialize databases for TechVault microservices

-- Create databases for each microservice
CREATE DATABASE authdb;
CREATE DATABASE productdb;
CREATE DATABASE cartdb;
CREATE DATABASE paymentdb;
CREATE DATABASE orderdb;
CREATE DATABASE airflow_db;

-- Grant permissions to postgres user
GRANT ALL PRIVILEGES ON DATABASE authdb TO postgres;
GRANT ALL PRIVILEGES ON DATABASE productdb TO postgres;
GRANT ALL PRIVILEGES ON DATABASE cartdb TO postgres;
GRANT ALL PRIVILEGES ON DATABASE paymentdb TO postgres;
GRANT ALL PRIVILEGES ON DATABASE orderdb TO postgres;
GRANT ALL PRIVILEGES ON DATABASE airflow_db TO postgres;

-- Connect to airflow_db to create analytics schema
\c airflow_db;
CREATE SCHEMA IF NOT EXISTS analytics;
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

\c productdb;
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

\c cartdb;
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

\c paymentdb;
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

\c orderdb;
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
