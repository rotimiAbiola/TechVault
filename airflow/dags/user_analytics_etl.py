from datetime import datetime, timedelta
from airflow import DAG
from airflow.operators.python import PythonOperator
from airflow.providers.postgres.operators.postgres import PostgresOperator
from airflow.providers.postgres.hooks.postgres import PostgresHook
from airflow.providers.snowflake.operators.snowflake import SnowflakeOperator
from airflow.providers.snowflake.hooks.snowflake import SnowflakeHook
import pandas as pd
import logging
import sys
import os

# Add config directory to path
sys.path.append('/opt/airflow/config')
from environment import CURRENT_CONFIG, SNOWFLAKE_CONFIG

# Default arguments
default_args = {
    'owner': 'data-engineering',
    'depends_on_past': False,
    'start_date': datetime(2024, 1, 1),
    'email_on_failure': True,
    'email_on_retry': False,
    'retries': 2,
    'retry_delay': timedelta(minutes=5),
    'catchup': False
}

# Create DAG
dag = DAG(
    'user_analytics_etl',
    default_args=default_args,
    description='ETL pipeline for TechVault e-commerce user analytics',
    schedule_interval='@daily',
    max_active_runs=1,
    tags=['analytics', 'etl', 'techvault']
)

def extract_user_data(**context):
    """Extract user data from auth service and activity data from other microservices"""
    try:
        # Get PostgreSQL connection
        pg_hook = PostgresHook(postgres_conn_id='postgres_default')
        
        # Query users from auth service database
        auth_sql = """
        SELECT 
            id as user_id,
            username,
            email,
            created_at as user_created_at
        FROM authdb.users
        WHERE DATE(created_at) >= CURRENT_DATE - INTERVAL '30 days';
        """
        
        # Query cart activities
        cart_sql = """
        SELECT 
            user_id,
            'cart_action' as action,
            'cart' as resource_type,
            id as resource_id,
            created_at,
            DATE(created_at) as activity_date
        FROM cartdb.cart_items
        WHERE DATE(created_at) = CURRENT_DATE - INTERVAL '1 day';
        """
        
        # Query order activities  
        order_sql = """
        SELECT 
            user_id,
            'order_placed' as action,
            'order' as resource_type,
            id as resource_id,
            created_at,
            DATE(created_at) as activity_date
        FROM orderdb.orders
        WHERE DATE(created_at) = CURRENT_DATE - INTERVAL '1 day';
        """
        
        # Execute queries and get DataFrames
        users_df = pg_hook.get_pandas_df(auth_sql)
        cart_df = pg_hook.get_pandas_df(cart_sql)
        order_df = pg_hook.get_pandas_df(order_sql)
        
        # Combine activity data
        activity_df = pd.concat([cart_df, order_df], ignore_index=True)
        
        # Merge with user data
        if not activity_df.empty:
            df = activity_df.merge(users_df, on='user_id', how='left')
            # Add mock IP addresses for demo (in production, collect from gateway logs)
            df['ip_address'] = '192.168.1.' + (df.index % 254 + 1).astype(str)
        else:
            # Create empty DataFrame with expected columns
            df = pd.DataFrame(columns=['user_id', 'username', 'email', 'action', 'resource_type', 
                                     'resource_id', 'ip_address', 'created_at', 'activity_date'])
        
        # Save to temporary location for next task
        df.to_parquet('/tmp/user_activities.parquet', index=False)
        
        logging.info(f"Extracted {len(df)} user activity records")
        
        return len(df)
        
    except Exception as e:
        logging.error(f"Error extracting user data: {str(e)}")
        raise

def transform_user_data(**context):
    """Transform user activity data"""
    try:
        # Load data from previous task
        df = pd.read_parquet('/tmp/user_activities.parquet')
        
        # Data transformations
        # 1. Create aggregated metrics
        daily_stats = df.groupby(['user_id', 'username', 'activity_date']).agg({
            'action': 'count',
            'resource_type': lambda x: x.nunique(),
            'ip_address': lambda x: x.nunique()
        }).rename(columns={
            'action': 'total_actions',
            'resource_type': 'unique_resource_types',
            'ip_address': 'unique_ip_addresses'
        }).reset_index()
        
        # 2. Add derived metrics
        daily_stats['engagement_score'] = (
            daily_stats['total_actions'] * 0.6 +
            daily_stats['unique_resource_types'] * 0.3 +
            daily_stats['unique_ip_addresses'] * 0.1
        )
        
        # 3. Categorize users by activity level
        daily_stats['activity_level'] = pd.cut(
            daily_stats['total_actions'],
            bins=[0, 5, 20, 50, float('inf')],
            labels=['low', 'medium', 'high', 'very_high']
        )
        
        # 4. Create hourly activity pattern
        df['hour'] = pd.to_datetime(df['created_at']).dt.hour
        hourly_pattern = df.groupby(['user_id', 'hour']).size().reset_index(name='hourly_count')
        
        # Save transformed data
        daily_stats.to_parquet('/tmp/daily_user_stats.parquet', index=False)
        hourly_pattern.to_parquet('/tmp/hourly_user_pattern.parquet', index=False)
        
        logging.info(f"Transformed data for {len(daily_stats)} users")
        
        return len(daily_stats)
        
    except Exception as e:
        logging.error(f"Error transforming user data: {str(e)}")
        raise

def load_to_analytics_db(**context):
    """Load transformed data to analytics database (PostgreSQL local, Snowflake production)"""
    try:
        # Load daily stats
        daily_stats = pd.read_parquet('/tmp/daily_user_stats.parquet')
        hourly_pattern = pd.read_parquet('/tmp/hourly_user_pattern.parquet')
        
        # Convert datetime columns to string
        daily_stats['activity_date'] = daily_stats['activity_date'].astype(str)
        
        if CURRENT_CONFIG['use_snowflake']:
            # Production: Load to Snowflake
            return load_to_snowflake_prod(daily_stats, hourly_pattern)
        else:
            # Local: Load to PostgreSQL
            return load_to_postgres_local(daily_stats, hourly_pattern)
        
    except Exception as e:
        logging.error(f"Error loading to analytics database: {str(e)}")
        raise

def load_to_postgres_local(daily_stats, hourly_pattern):
    """Load data to local PostgreSQL analytics tables"""
    pg_hook = PostgresHook(postgres_conn_id='postgres_default')
    
    # Create analytics tables if they don't exist
    create_tables_sql = """
    CREATE TABLE IF NOT EXISTS analytics.daily_user_stats (
        user_id INTEGER,
        username VARCHAR(100),
        activity_date DATE,
        total_actions INTEGER,
        unique_resource_types INTEGER,
        unique_ip_addresses INTEGER,
        engagement_score DECIMAL(10,2),
        activity_level VARCHAR(20),
        created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
        updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
        PRIMARY KEY (user_id, activity_date)
    );
    
    CREATE TABLE IF NOT EXISTS analytics.hourly_user_pattern (
        user_id INTEGER,
        hour INTEGER,
        hourly_count INTEGER,
        created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
    );
    """
    
    pg_hook.run(create_tables_sql)
    
    # Insert daily stats (using UPSERT)
    for _, row in daily_stats.iterrows():
        upsert_sql = """
        INSERT INTO analytics.daily_user_stats 
            (user_id, username, activity_date, total_actions, unique_resource_types, 
             unique_ip_addresses, engagement_score, activity_level, updated_at)
        VALUES (%s, %s, %s, %s, %s, %s, %s, %s, CURRENT_TIMESTAMP)
        ON CONFLICT (user_id, activity_date) 
        DO UPDATE SET 
            total_actions = EXCLUDED.total_actions,
            unique_resource_types = EXCLUDED.unique_resource_types,
            unique_ip_addresses = EXCLUDED.unique_ip_addresses,
            engagement_score = EXCLUDED.engagement_score,
            activity_level = EXCLUDED.activity_level,
            updated_at = CURRENT_TIMESTAMP;
        """
        
        pg_hook.run(upsert_sql, parameters=(
            int(row['user_id']),
            row['username'],
            row['activity_date'],
            int(row['total_actions']),
            int(row['unique_resource_types']),
            int(row['unique_ip_addresses']),
            float(row['engagement_score']),
            row['activity_level']
        ))
    
    # Clean up old hourly patterns and insert new ones
    pg_hook.run("DELETE FROM analytics.hourly_user_pattern WHERE DATE(created_at) = CURRENT_DATE - INTERVAL '1 day'")
    
    for _, row in hourly_pattern.iterrows():
        insert_sql = """
        INSERT INTO analytics.hourly_user_pattern (user_id, hour, hourly_count)
        VALUES (%s, %s, %s);
        """
        
        pg_hook.run(insert_sql, parameters=(
            int(row['user_id']),
            int(row['hour']),
            int(row['hourly_count'])
        ))
    
    logging.info("Successfully loaded data to PostgreSQL analytics tables")
    return True

def load_to_snowflake_prod(daily_stats, hourly_pattern):
    """Load data to Snowflake production warehouse"""
    sf_hook = SnowflakeHook(snowflake_conn_id='snowflake_default')
    
    # Upload to Snowflake staging tables
    sf_hook.write_pandas(
        df=daily_stats,
        table_name='STG_DAILY_USER_STATS',
        database=SNOWFLAKE_CONFIG['database'],
        schema='STAGING'
    )
    
    sf_hook.write_pandas(
        df=hourly_pattern,
        table_name='STG_HOURLY_USER_PATTERN',
        database=SNOWFLAKE_CONFIG['database'],
        schema='STAGING'
    )
    
    logging.info("Successfully loaded data to Snowflake staging tables")
    return True

def data_quality_check(**context):
    """Perform data quality checks on analytics tables (environment-aware)"""
    try:
        if CURRENT_CONFIG['use_snowflake']:
            return snowflake_quality_check()
        else:
            return postgres_quality_check()
        
    except Exception as e:
        logging.error(f"Data quality check failed: {str(e)}")
        raise

def postgres_quality_check():
    """Data quality checks for PostgreSQL (local)"""
    pg_hook = PostgresHook(postgres_conn_id='postgres_default')
    
    # Check 1: Record count validation
    count_result = pg_hook.get_first("""
        SELECT COUNT(*) as record_count 
        FROM analytics.daily_user_stats
        WHERE activity_date = CURRENT_DATE - 1
    """)
    
    count_check = count_result[0] if count_result else 0
    
    if count_check == 0:
        logging.warning("No records found in analytics table for yesterday - this may be normal for new installations")
    
    # Check 2: Data completeness
    completeness_result = pg_hook.get_first("""
        SELECT 
            COUNT(*) as total_records,
            COUNT(user_id) as non_null_user_ids,
            COUNT(total_actions) as non_null_actions
        FROM analytics.daily_user_stats
        WHERE activity_date = CURRENT_DATE - 1
    """)
    
    if completeness_result and completeness_result[1] != completeness_result[0]:
        raise ValueError("Found NULL values in critical columns")
    
    # Check 3: Business logic validation
    business_logic_result = pg_hook.get_first("""
        SELECT COUNT(*) as invalid_records
        FROM analytics.daily_user_stats
        WHERE activity_date = CURRENT_DATE - 1
        AND (total_actions < 0 OR engagement_score < 0)
    """)
    
    business_logic_check = business_logic_result[0] if business_logic_result else 0
    
    if business_logic_check > 0:
        raise ValueError(f"Found {business_logic_check} records with invalid business logic")
    
    logging.info("All PostgreSQL data quality checks passed")
    return True

def snowflake_quality_check():
    """Data quality checks for Snowflake (production)"""
    sf_hook = SnowflakeHook(snowflake_conn_id='snowflake_default')
    
    # Check 1: Record count validation
    count_check = sf_hook.get_first(f"""
        SELECT COUNT(*) as record_count 
        FROM {SNOWFLAKE_CONFIG['database']}.STAGING.STG_DAILY_USER_STATS
        WHERE activity_date = CURRENT_DATE - 1
    """)[0]
    
    if count_check == 0:
        raise ValueError("No records found in Snowflake staging table for yesterday")
    
    # Check 2: Data completeness
    completeness_check = sf_hook.get_first(f"""
        SELECT 
            COUNT(*) as total_records,
            COUNT(user_id) as non_null_user_ids,
            COUNT(total_actions) as non_null_actions
        FROM {SNOWFLAKE_CONFIG['database']}.STAGING.STG_DAILY_USER_STATS
        WHERE activity_date = CURRENT_DATE - 1
    """)
    
    if completeness_check[1] != completeness_check[0]:
        raise ValueError("Found NULL values in critical columns")
    
    # Check 3: Business logic validation
    business_logic_check = sf_hook.get_first(f"""
        SELECT COUNT(*) as invalid_records
        FROM {SNOWFLAKE_CONFIG['database']}.STAGING.STG_DAILY_USER_STATS
        WHERE activity_date = CURRENT_DATE - 1
        AND (total_actions < 0 OR engagement_score < 0)
    """)[0]
    
    if business_logic_check > 0:
        raise ValueError(f"Found {business_logic_check} records with invalid business logic")
    
    logging.info("All Snowflake data quality checks passed")
    return True

# Define tasks
extract_task = PythonOperator(
    task_id='extract_user_data',
    python_callable=extract_user_data,
    dag=dag
)

transform_task = PythonOperator(
    task_id='transform_user_data',
    python_callable=transform_user_data,
    dag=dag
)

load_task = PythonOperator(
    task_id='load_to_analytics_db',
    python_callable=load_to_analytics_db,
    dag=dag
)

quality_check_task = PythonOperator(
    task_id='data_quality_check',
    python_callable=data_quality_check,
    dag=dag
)

# Create analytics schema if it doesn't exist (PostgreSQL only)
create_schema_task = PostgresOperator(
    task_id='create_analytics_schema',
    postgres_conn_id='postgres_default',
    sql="""
    CREATE SCHEMA IF NOT EXISTS analytics;
    """,
    dag=dag
)

# Conditional cleanup task based on environment
if CURRENT_CONFIG['use_snowflake']:
    # Snowflake production tasks
    merge_task = SnowflakeOperator(
        task_id='merge_to_production',
        snowflake_conn_id='snowflake_default',
        sql=f"""
        MERGE INTO {SNOWFLAKE_CONFIG['database']}.{SNOWFLAKE_CONFIG['schema']}.USER_DAILY_STATS AS target
        USING {SNOWFLAKE_CONFIG['database']}.STAGING.STG_DAILY_USER_STATS AS source
        ON target.user_id = source.user_id 
        AND target.activity_date = source.activity_date
        WHEN MATCHED THEN 
            UPDATE SET 
                total_actions = source.total_actions,
                unique_resource_types = source.unique_resource_types,
                unique_ip_addresses = source.unique_ip_addresses,
                engagement_score = source.engagement_score,
                activity_level = source.activity_level,
                updated_at = CURRENT_TIMESTAMP()
        WHEN NOT MATCHED THEN 
            INSERT (user_id, username, activity_date, total_actions, 
                    unique_resource_types, unique_ip_addresses, 
                    engagement_score, activity_level, created_at, updated_at)
            VALUES (source.user_id, source.username, source.activity_date,
                    source.total_actions, source.unique_resource_types,
                    source.unique_ip_addresses, source.engagement_score,
                    source.activity_level, CURRENT_TIMESTAMP(), CURRENT_TIMESTAMP());
        """,
        dag=dag
    )
    
    cleanup_task = SnowflakeOperator(
        task_id='cleanup_old_data',
        snowflake_conn_id='snowflake_default',
        sql=f"""
        DELETE FROM {SNOWFLAKE_CONFIG['database']}.STAGING.STG_DAILY_USER_STATS 
        WHERE activity_date < CURRENT_DATE - 7;
        
        DELETE FROM {SNOWFLAKE_CONFIG['database']}.STAGING.STG_HOURLY_USER_PATTERN 
        WHERE created_at < CURRENT_TIMESTAMP - INTERVAL '7 days';
        """,
        dag=dag
    )
    
    # Snowflake task dependencies
    create_schema_task >> extract_task >> transform_task >> load_task >> quality_check_task >> merge_task >> cleanup_task
    
else:
    # PostgreSQL local cleanup
    cleanup_task = PostgresOperator(
        task_id='cleanup_old_data',
        postgres_conn_id='postgres_default',
        sql="""
        DELETE FROM analytics.daily_user_stats 
        WHERE activity_date < CURRENT_DATE - INTERVAL '90 days';
        
        DELETE FROM analytics.hourly_user_pattern 
        WHERE created_at < CURRENT_TIMESTAMP - INTERVAL '90 days';
        """,
        dag=dag
    )
    
    # PostgreSQL task dependencies
    create_schema_task >> extract_task >> transform_task >> load_task >> quality_check_task >> cleanup_task
