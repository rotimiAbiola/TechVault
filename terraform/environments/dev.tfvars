# Development Environment Variables

aws_region    = "us-west-2"
environment   = "development"
project_name  = "techvault"

# VPC Configuration
vpc_cidr                 = "10.0.0.0/16"
public_subnet_cidrs      = ["10.0.1.0/24", "10.0.2.0/24"]
private_subnet_cidrs     = ["10.0.10.0/24", "10.0.20.0/24"]
database_subnet_cidrs    = ["10.0.30.0/24", "10.0.40.0/24"]

# Database Configuration (smaller instances for dev)
rds_instance_class              = "db.t3.micro"
rds_allocated_storage           = 20
redis_node_type                 = "cache.t3.micro"
redis_num_cache_nodes           = 1
elasticsearch_instance_type     = "t3.small.elasticsearch"  # Cost-optimized
elasticsearch_instance_count    = 1
enable_elasticsearch            = true

# Additional tags
tags = {
  Environment = "development"
  CostCenter  = "engineering"
  Owner       = "dev-team"
}

# Monitoring configuration
alert_email = "" # Add your email address for CloudWatch alerts

# Container Images
image_tag = "latest"
frontend_image = "nginx"
gateway_image = "techvault/gateway"
auth_image = "techvault/auth-service"
product_image = "techvault/product-service"
payment_image = "techvault/payment-service"
cart_image = "techvault/cart-service"
order_image = "techvault/order-service"
