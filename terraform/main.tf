terraform {
  required_version = ">= 1.0"
  
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      ver# Monitoring Module
module "monitoring" {
  source = "./modules/monitoring"

  project_name      = var.project_name
  environment       = var.environment
  aws_region        = var.aws_region
  log_retention_days = var.log_retention_days
  alert_email       = var.alert_email
  common_tags       = local.common_tags

  # Resource identifiers from other modules
  ecs_cluster_name  = module.ecs.ecs_cluster_name
  alb_arn_suffix    = module.ecs.alb_arn_suffix
  rds_instance_id   = module.database.rds_instance_id
  redis_cluster_id  = module.database.redis_cluster_id
  log_group_names   = module.ecs.log_group_names
}    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.1"
    }
  }

  backend "s3" {
    bucket = "your-terraform-state-bucket"
    key    = "techvault/terraform.tfstate"
    region = "us-west-2"
  }
}

# Configure AWS Provider
provider "aws" {
  region = var.aws_region
  
  default_tags {
    tags = {
      Project     = "techvault"
      Environment = var.environment
      ManagedBy   = "terraform"
    }
  }
}

# Data sources
data "aws_availability_zones" "available" {
  state = "available"
}

data "aws_caller_identity" "current" {}

# Local values
locals {
  common_tags = {
    Project     = var.project_name
    Environment = var.environment
    ManagedBy   = "terraform"
  }
}

# VPC Module
module "vpc" {
  source = "./modules/vpc"

  project_name             = var.project_name
  environment              = var.environment
  vpc_cidr                 = var.vpc_cidr
  public_subnet_cidrs      = var.public_subnet_cidrs
  private_subnet_cidrs     = var.private_subnet_cidrs
  database_subnet_cidrs    = var.database_subnet_cidrs
  availability_zones       = data.aws_availability_zones.available.names
  use_nat_instance         = var.use_nat_instance
  key_pair_name            = var.key_pair_name
  common_tags              = local.common_tags
}

# Security Module
module "security" {
  source = "./modules/security"

  project_name     = var.project_name
  environment      = var.environment
  vpc_id           = module.vpc.vpc_id
  vpc_cidr_block   = module.vpc.vpc_cidr_block
  common_tags      = local.common_tags
}

# Database Module
module "database" {
  source = "./modules/database"

  project_name                    = var.project_name
  environment                     = var.environment
  vpc_id                          = module.vpc.vpc_id
  database_subnet_ids             = module.vpc.database_subnet_ids
  private_subnet_ids              = module.vpc.private_subnet_ids
  rds_security_group_id           = module.security.rds_security_group_id
  redis_security_group_id         = module.security.redis_security_group_id
  elasticsearch_security_group_id = module.security.elasticsearch_security_group_id
  rds_instance_class              = var.rds_instance_class
  rds_allocated_storage           = var.rds_allocated_storage
  redis_node_type                 = var.redis_node_type
  redis_num_cache_nodes           = var.redis_num_cache_nodes
  elasticsearch_instance_type     = var.elasticsearch_instance_type
  elasticsearch_instance_count    = var.elasticsearch_instance_count
  enable_elasticsearch            = var.enable_elasticsearch
  common_tags                     = local.common_tags
}

# Storage Module
module "storage" {
  source = "./modules/storage"

  project_name           = var.project_name
  environment            = var.environment
  rds_endpoint           = module.database.rds_endpoint
  rds_database_name      = module.database.rds_database_name
  rds_username           = module.database.rds_username
  rds_password           = module.database.rds_password
  elasticsearch_endpoint = module.database.elasticsearch_endpoint
  redis_endpoint         = module.database.redis_endpoint
  common_tags            = local.common_tags
}

# ECS Module
module "ecs" {
  source = "./modules/ecs"

  project_name                   = var.project_name
  environment                    = var.environment
  vpc_id                         = module.vpc.vpc_id
  public_subnet_ids              = module.vpc.public_subnet_ids
  private_subnet_ids             = module.vpc.private_subnet_ids
  alb_security_group_id          = module.security.alb_security_group_id
  ecs_service_security_group_id  = module.security.ecs_service_security_group_id
  alb_logs_bucket_id             = module.storage.alb_logs_bucket_id
  common_tags                    = local.common_tags
}

# Monitoring Module
module "monitoring" {
  source = "./modules/monitoring"

  project_name      = var.project_name
  environment       = var.environment
  aws_region        = var.aws_region
  log_retention_days = var.log_retention_days
  alert_email       = var.alert_email
  common_tags       = local.common_tags

  # Resource identifiers from other modules
  ecs_cluster_name  = module.ecs.cluster_name
  alb_arn_suffix    = module.ecs.alb_arn_suffix
  rds_instance_id   = module.database.rds_instance_id
  redis_cluster_id  = module.database.redis_cluster_id
}
