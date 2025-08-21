# CI/CD Pipeline Architecture

This repository uses a **service-specific CI/CD approach** where each service has its own pipeline that triggers only when changes are made to that specific service. This approach provides better performance, clearer separation of concerns, and more reliable deployments.

## Pipeline Structure

### Infrastructure Pipeline
**File**: `.github/workflows/terraform.yml`
**Triggers**: Changes to `terraform/**`
**Purpose**: Provisions and manages AWS infrastructure

**Stages**:
- **Validate**: Format check, validation, security scan
- **Plan**: Generate execution plan for development
- **Deploy Dev**: Apply changes to development environment (`develop` branch)
- **Deploy Prod**: Apply changes to production environment (`main` branch)

### Service-Specific Pipelines

Each microservice has its own dedicated CI/CD pipeline:

#### Frontend Pipeline
**File**: `.github/workflows/frontend.yml`
**Triggers**: Changes to `frontend/**`
**Tech**: React + TypeScript + Vite
**Stages**: Test → Security Scan → Build → Deploy to ECS

#### API Gateway Pipeline
**File**: `.github/workflows/gateway.yml`
**Triggers**: Changes to `gateway/**`
**Tech**: Node.js + Express
**Stages**: Test → Lint → Build → Deploy to ECS

#### Product Service Pipeline
**File**: `.github/workflows/product-service.yml`
**Triggers**: Changes to `product-service/**`
**Tech**: Go + Gin
**Stages**: Test → Lint → Security Scan → Build → Deploy to ECS

#### Payment Service Pipeline
**File**: `.github/workflows/payment-service.yml`
**Triggers**: Changes to `payment-service/**`
**Tech**: Java + Spring Boot
**Stages**: Test → Integration Tests → Security Scan → Build → Deploy to ECS

#### Auth Service Pipeline
**File**: `.github/workflows/auth-service.yml`
**Triggers**: Changes to `auth-service/**`
**Tech**: Python + Flask + Poetry
**Stages**: Test → Type Check → Security Scan → Build → Deploy to ECS

#### Cart & Order Services
Similar pipelines can be created for cart-service and order-service following the Python service pattern.

### Main Repository Pipeline
**File**: `.github/workflows/ci-cd.yml`
**Triggers**: General repository changes (not service-specific)
**Purpose**: Repository-wide health checks and security scanning

## Deployment Flow

### Development Environment
1. **Push to `develop` branch** triggers service-specific pipeline
2. **Terraform changes** deploy infrastructure to dev environment
3. **Service changes** deploy to development ECS cluster
4. **Automatic testing** and validation

### Production Environment
1. **Push to `main` branch** triggers production deployment
2. **Infrastructure changes** require manual approval (production environment)
3. **Service deployments** use blue-green strategy for zero downtime
4. **Comprehensive monitoring** and alerting

## Local Development

Docker Compose is **only for local development**:

```bash
# Start local development environment
docker-compose up -d postgres redis

# Build and run specific services locally
cd frontend && npm run dev
cd gateway && npm run dev
cd product-service && go run main.go
```

**Note**: Docker Compose is NOT used in CI/CD pipelines. Each service builds its own container image for AWS deployment.

## Environment Configuration

### Terraform Environments
- **Development**: `terraform/environments/dev.tfvars`
- **Production**: `terraform/environments/prod.tfvars`

### Required Secrets

Configure these in GitHub repository secrets:

```
AWS_ACCESS_KEY_ID          # AWS credentials for deployment
AWS_SECRET_ACCESS_KEY      # AWS credentials for deployment
SNYK_TOKEN                 # For security scanning (optional)
CODECOV_TOKEN              # For test coverage reporting (optional)
```

### Environment Variables per Pipeline

Each service pipeline defines its own environment-specific variables:
- ECR repository names
- ECS cluster and service names
- AWS region configuration

## Benefits of This Architecture

### 1. **Independent Deployments**
- Services deploy independently
- No unnecessary builds when unrelated code changes
- Faster feedback loops

### 2. **Technology-Specific Pipelines**
- Python services use Poetry, pytest, mypy
- Node.js services use npm, Jest, ESLint
- Go services use Go modules, golangci-lint
- Java services use Maven, JUnit, SpotBugs

### 3. **Efficient Resource Usage**
- Only run tests for changed services
- Parallel execution of independent pipelines
- Reduced CI/CD costs and time

### 4. **Clear Separation of Concerns**
- Infrastructure changes separated from application changes
- Service teams can modify their own pipelines
- Easier troubleshooting and maintenance

### 5. **Security & Quality**
- Service-specific security scanning
- Language-appropriate linting and testing
- Dependency vulnerability checking per service

## Pipeline Triggers

```yaml
# Infrastructure changes
terraform/** → terraform.yml

# Service changes
frontend/** → frontend.yml
gateway/** → gateway.yml
product-service/** → product-service.yml
payment-service/** → payment-service.yml
auth-service/** → auth-service.yml

# General repository changes
README.md, scripts/, etc. → ci-cd.yml
```

## Adding New Services

To add a new service pipeline:

1. **Copy existing service workflow** that matches your technology stack
2. **Update paths** in the `on.push.paths` and `on.pull_request.paths`
3. **Modify environment variables** (ECR repo, ECS service names)
4. **Customize build/test commands** for your service's requirements
5. **Add any service-specific dependencies** or tools

## Monitoring & Observability

Each pipeline provides:
- **Build status badges** for each service
- **Test coverage reports** (when configured)
- **Security scan results** uploaded to GitHub Security tab
- **Deployment summaries** with infrastructure outputs
- **Performance metrics** from AWS CloudWatch (via Terraform)

This architecture ensures that each team can work independently while maintaining high standards for security, testing, and deployment practices across all services.
