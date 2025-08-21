# VPC Outputs
output "vpc_id" {
  description = "ID of the VPC"
  value       = module.vpc.vpc_id
}

output "public_subnet_ids" {
  description = "IDs of the public subnets"
  value       = module.vpc.public_subnet_ids
}

output "private_subnet_ids" {
  description = "IDs of the private subnets"
  value       = module.vpc.private_subnet_ids
}

output "database_subnet_ids" {
  description = "IDs of the database subnets"
  value       = module.vpc.database_subnet_ids
}

# ECS Outputs
output "ecs_cluster_name" {
  description = "Name of the ECS cluster"
  value       = module.ecs.ecs_cluster_name
}

output "alb_dns_name" {
  description = "DNS name of the Application Load Balancer"
  value       = module.ecs.alb_dns_name
}

output "alb_zone_id" {
  description = "Zone ID of the load balancer"
  value       = module.ecs.alb_zone_id
}

# Database Outputs
output "rds_endpoint" {
  description = "RDS instance endpoint"
  value       = module.database.rds_endpoint
  sensitive   = true
}

output "redis_endpoint" {
  description = "Redis cluster endpoint"
  value       = module.database.redis_endpoint
  sensitive   = true
}

output "elasticsearch_endpoint" {
  description = "Elasticsearch domain endpoint"
  value       = module.database.elasticsearch_endpoint
  sensitive   = true
}

# Storage Outputs
output "database_url_parameter_name" {
  description = "SSM parameter name for database URL"
  value       = module.storage.database_url_parameter_name
}

output "redis_url_parameter_name" {
  description = "SSM parameter name for Redis URL"
  value       = module.storage.redis_url_parameter_name
}

output "elasticsearch_url_parameter_name" {
  description = "SSM parameter name for Elasticsearch URL"
  value       = module.storage.elasticsearch_url_parameter_name
}

output "jwt_secret_parameter_name" {
  description = "SSM parameter name for JWT secret"
  value       = module.storage.jwt_secret_parameter_name
}

output "application_url" {
  description = "URL of the application"
  value       = "http://${module.ecs.alb_dns_name}"
}

output "api_url" {
  description = "URL of the API"
  value       = "http://${aws_lb.main.dns_name}:8080"
}

output "database_secret_arn" {
  description = "ARN of the database credentials in SSM"
  value       = aws_ssm_parameter.database_url.arn
}

output "elasticsearch_secret_arn" {
  description = "ARN of the elasticsearch credentials in SSM"
  value       = aws_ssm_parameter.elasticsearch_url.arn
}

output "redis_secret_arn" {
  description = "ARN of the redis credentials in SSM"
  value       = aws_ssm_parameter.redis_url.arn
}
