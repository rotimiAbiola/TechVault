# Development Scripts

This directory contains utility scripts for local development and task definition processing.

## Available Scripts

### 🔧 **Development Environment**

#### `setup-dev.sh`
**Purpose**: Automated development environment setup  
**Usage**: `./setup-dev.sh`  
**Features**:
- Checks Docker availability
- Creates `.env` from template if missing
- Starts all services with Docker Compose
- Waits for services to be ready

#### `test-local.ps1`
**Purpose**: Local development testing and health checks (Windows)  
**Usage**: `.\test-local.ps1`  
**Features**:
- Prerequisites checking (Docker, etc.)
- Service health verification
- Local endpoint testing
- PowerShell-friendly output

### 📦 **Task Definition Processing**

#### `process-task-definition.sh` / `process-task-definition.ps1`
**Purpose**: Process ECS task definition templates with environment variables  
**Usage**: 
```bash
# Linux/macOS
./process-task-definition.sh <service-name> [environment] [image-tag]

# Windows
.\process-task-definition.ps1 -ServiceName <service> -Environment <env> -ImageTag <tag>
```

**Features**:
- Substitutes environment variables in task definition templates
- Supports multiple environments (production, staging, development)
- Used by CI/CD pipelines for automated deployments
- Validates AWS credentials and generates processed files

**Example**:
```bash
./process-task-definition.sh frontend production v1.2.3
```

## Integration with CI/CD

The task definition processing scripts are integrated into GitHub Actions workflows:

```yaml
- name: Process Task Definition
  run: |
    export AWS_ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
    export IMAGE_TAG=${{ github.sha }}
    ./scripts/process-task-definition.sh frontend production
```

## Development Workflow

1. **Initial Setup**: Run `setup-dev.sh` to initialize your local environment
2. **Local Testing**: Use `test-local.ps1` to verify services are running correctly
3. **Manual Deployments**: Use task definition scripts for testing deployment configurations

## Requirements

- **Docker**: Required for all local development scripts
- **AWS CLI**: Required for task definition processing scripts
- **PowerShell**: Required for Windows-specific scripts (`.ps1`)
- **Bash**: Required for Linux/macOS scripts (`.sh`)

## Removed Scripts

The following scripts have been removed as they're obsolete:
- ❌ `deploy.sh` / `deploy.ps1` - Replaced by GitHub Actions CI/CD
- ❌ `init-databases.sql` - Replaced by `database/init.sql`

All deployment is now handled automatically through the CI/CD pipelines with proper environment-specific configurations.
