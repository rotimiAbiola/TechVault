# ECS Task Definitions

This directory contains ECS task definition templates for all TechVault microservices.

## Structure

```
aws/
├── task-definitions/           # Template files
│   ├── frontend.json
│   ├── gateway.json
│   ├── auth-service.json
│   ├── product-service.json
│   └── payment-service.json
└── task-definitions/processed/ # Generated files (CI/CD output)
```

## Template Variables

Each task definition template uses environment variables that are substituted during deployment:

### AWS Configuration
- `${AWS_ACCOUNT_ID}` - AWS Account ID (auto-detected)
- `${AWS_REGION}` - AWS Region
- `${IMAGE_TAG}` - Docker image tag (usually git commit SHA)

### Environment Configuration
- `${ENVIRONMENT}` - Deployment environment (production, staging, development)
- `${NODE_ENV}` - Node.js environment
- `${GIN_MODE}` - Go Gin framework mode

### Service URLs
- `${API_GATEWAY_URL}` - External API Gateway URL
- `${FRONTEND_URL}` - Frontend application URL
- `${AUTH_SERVICE_URL}` - Internal auth service URL
- `${PRODUCT_SERVICE_URL}` - Internal product service URL
- `${PAYMENT_SERVICE_URL}` - Internal payment service URL

## Processing Templates

### Using Scripts

Process a single service template:

```bash
# Linux/macOS
./scripts/process-task-definition.sh frontend production v1.0.0

# Windows
.\scripts\process-task-definition.ps1 -ServiceName frontend -Environment production -ImageTag v1.0.0
```

### Manual Processing

You can also process templates manually using `envsubst`:

```bash
export AWS_ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
export AWS_REGION=us-west-2
export IMAGE_TAG=latest
export ENVIRONMENT=production
export NODE_ENV=production
export API_GATEWAY_URL=https://api.techvault.com
export FRONTEND_URL=https://techvault.com

envsubst < aws/task-definitions/frontend.json > aws/task-definitions/processed/frontend-production.json
```

## CI/CD Integration

The CI/CD pipelines automatically process these templates during deployment:

1. **Template Processing**: Variables are substituted with environment-specific values
2. **Task Registration**: Processed task definition is registered with ECS
3. **Service Update**: ECS service is updated with the new task definition

### Example CI/CD Usage

```yaml
- name: Deploy to ECS Production
  run: |
    # Process template
    export AWS_ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
    export IMAGE_TAG=${{ github.sha }}
    export ENVIRONMENT=production
    
    envsubst < aws/task-definitions/frontend.json > aws/task-definitions/processed/frontend-production.json
    
    # Register and deploy
    aws ecs register-task-definition --cli-input-json file://aws/task-definitions/processed/frontend-production.json
    aws ecs update-service --cluster $ECS_CLUSTER --service $ECS_SERVICE --task-definition frontend
```

## Task Definition Features

Each task definition includes:

### Resource Configuration
- **CPU**: 256 CPU units (0.25 vCPU)
- **Memory**: 512 MB
- **Network**: awsvpc mode for Fargate

### Security
- **Execution Role**: `ecsTaskExecutionRole` for ECR/CloudWatch access
- **Task Role**: `techvaultTaskRole` for application-specific AWS permissions
- **Secrets**: Sensitive configuration stored in AWS Systems Manager Parameter Store

### Monitoring
- **CloudWatch Logs**: Centralized logging with service-specific log groups
- **Health Checks**: Application health endpoints for container health monitoring

### Environment Variables
- Service-specific environment configuration
- Cross-service communication URLs
- Feature flags and runtime configuration

### Secrets Management
- Database connection strings
- API keys and tokens
- JWT secrets
- Third-party service credentials

## Environment-Specific Configurations

### Production
- `NODE_ENV=production`
- `GIN_MODE=release`
- Production URLs and endpoints
- Enhanced monitoring and alerting

### Staging
- `NODE_ENV=production`
- `GIN_MODE=release`
- Staging URLs and endpoints
- Similar to production but isolated

### Development
- `NODE_ENV=development`
- `GIN_MODE=debug`
- Development URLs and endpoints
- Debug logging enabled

## Secrets Configuration

Before deploying, ensure all required secrets are stored in AWS Systems Manager Parameter Store:

```bash
# Example secret paths
/techvault/production/frontend/sentry-dsn
/techvault/production/gateway/jwt-secret
/techvault/production/auth-service/database-url
/techvault/production/product-service/database-url
/techvault/production/payment-service/stripe-secret-key
/techvault/production/redis/connection-string
/techvault/production/elasticsearch/connection-string
```

## Troubleshooting

### Common Issues

1. **Missing Environment Variables**: Ensure all required variables are set during processing
2. **Invalid JSON**: Validate processed JSON before registration
3. **Permission Errors**: Verify IAM roles have necessary permissions
4. **Image Not Found**: Ensure Docker images are pushed to ECR before deployment

### Validation

Validate processed task definitions:

```bash
aws ecs register-task-definition --cli-input-json file://aws/task-definitions/processed/frontend-production.json --dry-run
```

### Debugging

Check task definition registration:

```bash
aws ecs describe-task-definition --task-definition techvault-frontend
```

## Benefits of This Approach

1. **Version Control**: Task definitions are versioned with code
2. **Consistency**: Same configuration across environments with variable substitution
3. **Transparency**: Clear visibility into container configuration
4. **Flexibility**: Easy to modify and test configuration changes
5. **Rollback**: Easy to revert to previous task definition versions
6. **Security**: Secrets properly managed through Parameter Store
