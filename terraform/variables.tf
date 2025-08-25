variable "aws_region" {
  description = "AWS region"
  type        = string
  default     = "us-west-2"
}

variable "environment" {
  description = "Environment name"
  type        = string
  default     = "dev"
}

variable "project_name" {
  description = "Project name"
  type        = string
  default     = "techvault"
}

variable "vpc_cidr" {
  description = "CIDR block for VPC"
  type        = string
  default     = "10.0.0.0/16"
}

variable "public_subnet_cidrs" {
  description = "CIDR blocks for public subnets"
  type        = list(string)
  default     = ["10.0.1.0/24", "10.0.2.0/24"]
}

variable "private_subnet_cidrs" {
  description = "CIDR blocks for private subnets"
  type        = list(string)
  default     = ["10.0.3.0/24", "10.0.4.0/24"]
}

variable "database_subnet_cidrs" {
  description = "CIDR blocks for database subnets"
  type        = list(string)
  default     = ["10.0.5.0/24", "10.0.6.0/24"]
}

variable "use_nat_instance" {
  description = "Use NAT instance instead of NAT Gateway (cost optimization)"
  type        = bool
  default     = true
}

variable "key_pair_name" {
  description = "EC2 Key Pair name for NAT instance"
  type        = string
  default     = ""
}

variable "rds_instance_class" {
  description = "RDS instance class"
  type        = string
  default     = "db.t3.micro"
}

variable "rds_allocated_storage" {
  description = "RDS allocated storage in GB"
  type        = number
  default     = 20
}

variable "redis_node_type" {
  description = "Redis node type"
  type        = string
  default     = "cache.t3.micro"
}

variable "redis_num_cache_nodes" {
  description = "Number of Redis cache nodes"
  type        = number
  default     = 1
}

variable "elasticsearch_instance_type" {
  description = "Elasticsearch instance type"
  type        = string
  default     = "t3.small.elasticsearch"
}

variable "elasticsearch_instance_count" {
  description = "Number of Elasticsearch instances"
  type        = number
  default     = 1
}

variable "enable_elasticsearch" {
  description = "Enable Elasticsearch domain"
  type        = bool
  default     = false
}

variable "log_retention_days" {
  description = "CloudWatch log retention days"
  type        = number
  default     = 7
}

variable "alert_email" {
  description = "Email for CloudWatch alerts"
  type        = string
  default     = "admin@techvault.com"
}

variable "tags" {
  description = "Additional tags to apply to resources"
  type        = map(string)
  default     = {}
}

# Container Image Variables
variable "image_tag" {
  description = "Tag for container images"
  type        = string
  default     = "latest"
}

variable "frontend_image" {
  description = "Container image for frontend service"
  type        = string
  default     = "nginx"
}

variable "gateway_image" {
  description = "Container image for gateway service"
  type        = string
  default     = "techvault/gateway"
}

variable "auth_image" {
  description = "Container image for auth service"
  type        = string
  default     = "techvault/auth-service"
}

variable "product_image" {
  description = "Container image for product service"
  type        = string
  default     = "techvault/product-service"
}

variable "payment_image" {
  description = "Container image for payment service"
  type        = string
  default     = "techvault/payment-service"
}

variable "cart_image" {
  description = "Container image for cart service"
  type        = string
  default     = "techvault/cart-service"
}

variable "order_image" {
  description = "Container image for order service"
  type        = string
  default     = "techvault/order-service"
}