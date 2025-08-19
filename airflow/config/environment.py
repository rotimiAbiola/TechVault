import os

# Environment configuration
ENVIRONMENT = os.getenv('ENVIRONMENT', 'local')  # 'local' or 'production'

# Database configurations
DB_CONFIGS = {
    'local': {
        'analytics_conn_id': 'postgres_default',
        'analytics_db_type': 'postgresql',
        'analytics_schema': 'analytics',
        'use_snowflake': False
    },
    'production': {
        'analytics_conn_id': 'snowflake_default',
        'analytics_db_type': 'snowflake',
        'analytics_database': 'TECHVAULT_ANALYTICS',
        'analytics_schema': 'ANALYTICS',
        'use_snowflake': True
    }
}

# Get current environment config
CURRENT_CONFIG = DB_CONFIGS[ENVIRONMENT]

# Snowflake specific settings (for production)
SNOWFLAKE_CONFIG = {
    'account': os.getenv('SNOWFLAKE_ACCOUNT'),
    'warehouse': os.getenv('SNOWFLAKE_WAREHOUSE', 'COMPUTE_WH'),
    'database': os.getenv('SNOWFLAKE_DATABASE', 'TECHVAULT_ANALYTICS'),
    'schema': os.getenv('SNOWFLAKE_SCHEMA', 'ANALYTICS'),
    'role': os.getenv('SNOWFLAKE_ROLE', 'ANALYST_ROLE')
}
