# Free Tier Optimized Development Environment

aws_region    = "us-west-2"
environment   = "development"
project_name  = "techvault"

# VPC Configuration - Single AZ to reduce NAT Gateway costs
vpc_cidr                 = "10.0.0.0/16"
availability_zones       = ["us-west-2a"]  # Single AZ only
public_subnet_cidrs      = ["10.0.1.0/24"]
private_subnet_cidrs     = ["10.0.10.0/24"]
database_subnet_cidrs    = ["10.0.30.0/24", "10.0.40.0/24"]  # Still need 2 for RDS

# Database Configuration - Free Tier Eligible
rds_instance_class              = "db.t3.micro"    # Free Tier
rds_allocated_storage           = 20               # Free Tier: 20GB
redis_node_type                 = "cache.t3.micro" # Free Tier
redis_num_cache_nodes           = 1                # Single node

# Elasticsearch Configuration - Smallest instance for cost optimization
enable_elasticsearch            = true
elasticsearch_instance_type     = "t3.small.elasticsearch"  # Smallest available
elasticsearch_instance_count    = 1                         # Single node

# Use NAT Instance instead of NAT Gateway to save ~$35/month
use_nat_instance               = true
key_pair_name                  = ""  # Optional: add your key pair name for SSH access

# ECS Configuration - Optimize for Free Tier
ecs_cpu                        = 256    # Minimal CPU
ecs_memory                     = 512    # Minimal memory

# Additional tags
tags = {
  Environment = "development"
  CostCenter  = "engineering"
  Owner       = "dev-team"
  CostOptimized = "true"
}

# Monitoring configuration
alert_email = "" # Add your email address for CloudWatch alerts
log_retention_days = 7  # Reduced retention to save costs
