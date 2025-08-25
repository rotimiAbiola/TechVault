# Terraform Infrastructure Modules

This Terraform configuration has been refactored to use a modular architecture for better maintainability, reusability, and organization.

## Module Structure

```
terraform/
├── modules/
│   ├── vpc/
│   │   ├── main.tf        # VPC, subnets, gateways, routing
│   │   ├── variables.tf   # Input variables
│   │   └── outputs.tf     # Output values
│   ├── security/
│   │   ├── main.tf        # Security groups
│   │   ├── variables.tf   # Input variables
│   │   └── outputs.tf     # Output values
│   ├── database/
│   │   ├── main.tf        # RDS, Redis, Elasticsearch
│   │   ├── variables.tf   # Input variables
│   │   └── outputs.tf     # Output values
│   ├── ecs/
│   │   ├── main.tf        # ECS cluster, ALB, target groups
│   │   ├── variables.tf   # Input variables
│   │   └── outputs.tf     # Output values
│   └── storage/
│       ├── main.tf        # S3 buckets, SSM parameters
│       ├── variables.tf   # Input variables
│       └── outputs.tf     # Output values
├── main.tf                # Root module calling child modules
├── variables.tf           # Root-level variables
├── outputs.tf             # Root-level outputs
└── terraform.tfvars.example
```

## Modules Description

### VPC Module (`modules/vpc/`)
- **Purpose**: Network infrastructure setup
- **Resources**: VPC, public/private/database subnets, Internet Gateway, NAT Gateways, route tables
- **Dependencies**: None (foundational module)

### Security Module (`modules/security/`)
- **Purpose**: Security group management
- **Resources**: Security groups for ALB, ECS services, RDS, Redis, Elasticsearch
- **Dependencies**: VPC module (requires VPC ID)

### Database Module (`modules/database/`)
- **Purpose**: Database and data services
- **Resources**: RDS PostgreSQL, Redis cluster, Elasticsearch domain
- **Dependencies**: VPC module (subnets), Security module (security groups)

### ECS Module (`modules/ecs/`)
- **Purpose**: Container orchestration infrastructure
- **Resources**: ECS cluster, Application Load Balancer, target groups, listeners
- **Dependencies**: VPC module (subnets), Security module (security groups), Storage module (S3 bucket for ALB logs)

### Storage Module (`modules/storage/`)
- **Purpose**: Storage and configuration management
- **Resources**: S3 buckets, SSM parameters for secrets
- **Dependencies**: Database module (for connection strings)

## Usage

### 1. Initialize Terraform
```bash
cd terraform
terraform init
```

### 2. Create terraform.tfvars
Copy `terraform.tfvars.example` to `terraform.tfvars` and customize values:
```hcl
aws_region                   = "us-west-2"
environment                  = "production"
project_name                = "techvault"
vpc_cidr                    = "10.0.0.0/16"
rds_instance_class          = "db.r5.large"
elasticsearch_instance_type = "r5.large.elasticsearch"
redis_node_type             = "cache.t3.micro"
```

### 3. Plan and Apply
```bash
terraform plan
terraform apply
```

## Module Benefits

### 1. **Reusability**
- Modules can be used across different environments (dev, staging, prod)
- Easy to create similar infrastructure stacks

### 2. **Maintainability**
- Logical separation of concerns
- Easier to understand and modify specific components
- Isolated testing of individual modules

### 3. **Scalability**
- Easy to add new modules for additional services
- Version control for module changes
- Consistent patterns across infrastructure

### 4. **Collaboration**
- Teams can work on different modules independently
- Clear interfaces between modules via variables and outputs
- Better code review process

## Module Dependencies Graph

```
VPC (foundational)
├── Security (depends on VPC)
├── Database (depends on VPC, Security)
├── Storage (depends on Database for connection strings)
└── ECS (depends on VPC, Security, Storage)
```

## Migration Notes

This configuration was migrated from a monolithic Terraform structure to modules. The migration:

1. **Preserved all functionality** - No resources were removed or changed
2. **Maintained state compatibility** - Resource names and configurations preserved
3. **Added module boundaries** - Clear separation of concerns
4. **Improved variable management** - Centralized configuration through root variables

## Best Practices

1. **Module Versioning**: Consider versioning modules for production use
2. **Remote State**: Use remote state backend (S3) for team collaboration
3. **Variable Validation**: Add validation rules to module variables
4. **Documentation**: Keep module README files updated
5. **Testing**: Test modules independently before integration

## Future Enhancements

Potential areas for further modularization:
- **Monitoring Module**: CloudWatch dashboards, alarms, SNS topics
- **ECR Module**: Container registries with lifecycle policies
- **IAM Module**: Roles, policies, and service accounts
- **DNS Module**: Route 53 zones and records
- **Certificate Module**: ACM certificates and validation

#