variable "project_name" {
  description = "Name of the project"
  type        = string
}

variable "environment" {
  description = "Environment name"
  type        = string
}

variable "aws_region" {
  description = "AWS region"
  type        = string
}

variable "log_retention_days" {
  description = "CloudWatch log retention in days"
  type        = number
  default     = 30
}

variable "alert_email" {
  description = "Email address for CloudWatch alerts"
  type        = string
  default     = ""
}

variable "common_tags" {
  description = "Common tags to be applied to resources"
  type        = map(string)
  default     = {}
}

variable "ecs_cluster_name" {
  description = "Name of the ECS cluster"
  type        = string
}

variable "alb_arn_suffix" {
  description = "ARN suffix of the Application Load Balancer"
  type        = string
}

variable "rds_instance_id" {
  description = "RDS instance identifier"
  type        = string
}

variable "redis_cluster_id" {
  description = "Redis cluster identifier"
  type        = string
}

variable "log_group_names" {
  description = "CloudWatch log group names for services"
  type = object({
    frontend = string
    gateway  = string
    product  = string
    payment  = string
    auth     = string
  })
}
