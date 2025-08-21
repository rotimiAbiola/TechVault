# Production Environment Variables

aws_region    = "us-west-2"
environment   = "production"
project_name  = "techvault"

# VPC Configuration
vpc_cidr                 = "10.0.0.0/16"
public_subnet_cidrs      = ["10.0.1.0/24", "10.0.2.0/24", "10.0.3.0/24"]
private_subnet_cidrs     = ["10.0.10.0/24", "10.0.20.0/24", "10.0.30.0/24"]
database_subnet_cidrs    = ["10.0.40.0/24", "10.0.50.0/24", "10.0.60.0/24"]

# Database Configuration (production-sized instances)
rds_instance_class              = "db.r5.large"
rds_allocated_storage           = 100
redis_node_type                 = "cache.r5.large"
redis_num_cache_nodes           = 2
elasticsearch_instance_type     = "r5.large.elasticsearch"
elasticsearch_instance_count    = 3
enable_elasticsearch            = true

# Additional tags
tags = {
  Environment = "production"
  CostCenter  = "engineering"
  Owner       = "platform-team"
  Backup      = "daily"
}

# Monitoring configuration
alert_email = "" # Add your email address for CloudWatch alerts
