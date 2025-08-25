variable "project_name" {
  description = "Name of the project"
  type        = string
}

variable "environment" {
  description = "Environment name"
  type        = string
}

variable "vpc_id" {
  description = "ID of the VPC"
  type        = string
}

variable "public_subnet_ids" {
  description = "List of public subnet IDs"
  type        = list(string)
}

variable "private_subnet_ids" {
  description = "List of private subnet IDs"
  type        = list(string)
}

variable "alb_security_group_id" {
  description = "Security group ID for ALB"
  type        = string
}

variable "ecs_service_security_group_id" {
  description = "Security group ID for ECS services"
  type        = string
}

variable "alb_logs_bucket_id" {
  description = "S3 bucket ID for ALB logs"
  type        = string
}

variable "common_tags" {
  description = "Common tags to apply to all resources"
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

# SSM Parameter ARNs
variable "database_url_parameter_arn" {
  description = "ARN of the database URL SSM parameter"
  type        = string
}

variable "redis_url_parameter_arn" {
  description = "ARN of the Redis URL SSM parameter"
  type        = string
}

variable "jwt_secret_parameter_arn" {
  description = "ARN of the JWT secret SSM parameter"
  type        = string
}

variable "elasticsearch_url_parameter_arn" {
  description = "ARN of the Elasticsearch URL SSM parameter"
  type        = string
}
