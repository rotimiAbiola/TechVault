# TechVault Architecture Documentation

This directory contains architecture diagrams and documentation for the TechVault platform.

## Files

- `techvault-architecture.png` - Professional Lucidchart diagram showing complete system architecture

## Architecture Overview

The TechVault platform follows a cloud-native microservices architecture deployed on AWS ECS Fargate with comprehensive DevOps automation, monitoring, and security features.

### Key Components

1. **Microservices Layer**: 5 independent services (Frontend, Gateway, Auth, Product, Payment)
2. **Data Layer**: RDS PostgreSQL, ElastiCache Redis, Elasticsearch
3. **Infrastructure Layer**: ECS Fargate, Application Load Balancer, Multi-AZ VPC
4. **DevOps Layer**: GitHub Actions CI/CD, Terraform IaC, CloudWatch monitoring
5. **Security Layer**: IAM roles, Parameter Store, Security Groups

### Deployment Environments

- **Free Tier**: ~$47/month - Cost-optimized with NAT instance
- **Development**: ~$57/month - Enhanced monitoring and debugging
- **Production**: ~$340/month - Full redundancy and auto-scaling

For detailed technical documentation, see:
- [Task Definitions](../aws/task-definitions/README.md)
- [Main Project README](../README.md) - Complete technical architecture overview
