# ECS Deployment script for React-Python Application (PowerShell)
# Usage: .\deploy.ps1 [environment] [region]

param(
    [string]$Environment = "production",
    [string]$Region = "us-west-2",
    [string]$Action = "deploy"
)

# Configuration
$PROJECT_NAME = "react-python-app"
$ECS_CLUSTER_NAME = "$PROJECT_NAME-$Environment-cluster"
$ECR_REPOSITORY_FRONTEND = "$PROJECT_NAME-frontend"
$ECR_REPOSITORY_BACKEND = "$PROJECT_NAME-backend"

# Function definitions
function Write-Info {
    param([string]$Message)
    Write-Host "[INFO] $Message" -ForegroundColor Green
}

function Write-Warn {
    param([string]$Message)
    Write-Host "[WARN] $Message" -ForegroundColor Yellow
}

function Write-Error {
    param([string]$Message)
    Write-Host "[ERROR] $Message" -ForegroundColor Red
}

function Write-Header {
    param([string]$Message)
    Write-Host ""
    Write-Host "==================================================" -ForegroundColor Cyan
    Write-Host $Message -ForegroundColor Cyan
    Write-Host "==================================================" -ForegroundColor Cyan
}

function Write-Success {
    param([string]$Message)
    Write-Host "[SUCCESS] $Message" -ForegroundColor Green
}

# Validate prerequisites
function Test-Prerequisites {
    Write-Info "Checking prerequisites..."
    
    $tools = @("aws", "docker", "terraform", "jq")
    foreach ($tool in $tools) {
        try {
            $null = Get-Command $tool -ErrorAction Stop
        }
        catch {
            Write-Error "$tool is not installed or not in PATH"
            exit 1
        }
    }
    
    # Check AWS credentials
    try {
        $null = aws sts get-caller-identity 2>$null
    }
    catch {
        Write-Error "AWS credentials not configured"
        exit 1
    }
    
    Write-Info "Prerequisites check passed"
}

# Initialize Terraform
function Initialize-Terraform {
    Write-Info "Initializing Terraform..."
    
    Push-Location terraform
    try {
        terraform init -upgrade
        if ($LASTEXITCODE -ne 0) {
            throw "Terraform init failed"
        }
    }
    finally {
        Pop-Location
    }
    
    Write-Info "Terraform initialized successfully"
}

# Apply Terraform configuration
function Deploy-Infrastructure {
    Write-Info "Applying Terraform configuration..."
    
    Push-Location terraform
    try {
        terraform plan -var="environment=$Environment" -var="aws_region=$Region" -out=tfplan
        if ($LASTEXITCODE -ne 0) {
            throw "Terraform plan failed"
        }
        
        terraform apply tfplan
        if ($LASTEXITCODE -ne 0) {
            throw "Terraform apply failed"
        }
    }
    finally {
        Pop-Location
    }
    
    Write-Info "Infrastructure deployed successfully"
}

# Build and push Docker images
function Build-AndPushImages {
    Write-Info "Building and pushing Docker images..."
    
    # Get AWS account ID
    $AWS_ACCOUNT_ID = (aws sts get-caller-identity --query Account --output text)
    
    # Get ECR login token
    $loginPassword = aws ecr get-login-password --region $Region
    $loginPassword | docker login --username AWS --password-stdin "$AWS_ACCOUNT_ID.dkr.ecr.$Region.amazonaws.com"
    
    # Build and push frontend image
    $FRONTEND_REPO = "$AWS_ACCOUNT_ID.dkr.ecr.$Region.amazonaws.com/$ECR_REPOSITORY_FRONTEND"
    Write-Info "Building frontend image..."
    docker build -t "${FRONTEND_REPO}:latest" .\frontend
    $gitCommit = git rev-parse --short HEAD
    docker tag "${FRONTEND_REPO}:latest" "${FRONTEND_REPO}:$gitCommit"
    docker push "${FRONTEND_REPO}:latest"
    docker push "${FRONTEND_REPO}:$gitCommit"
    
    # Build and push backend image
    $BACKEND_REPO = "$AWS_ACCOUNT_ID.dkr.ecr.$Region.amazonaws.com/$ECR_REPOSITORY_BACKEND"
    Write-Info "Building backend image..."
    docker build -t "${BACKEND_REPO}:latest" .\backend
    docker tag "${BACKEND_REPO}:latest" "${BACKEND_REPO}:$gitCommit"
    docker push "${BACKEND_REPO}:latest"
    docker push "${BACKEND_REPO}:$gitCommit"
    
    Write-Info "Docker images built and pushed successfully"
}

# Deploy to ECS
function Deploy-ToECS {
    Write-Info "Deploying to ECS..."
    
    # Update frontend service
    Write-Info "Updating frontend service..."
    aws ecs update-service `
        --cluster $ECS_CLUSTER_NAME `
        --service "$PROJECT_NAME-$Environment-frontend" `
        --force-new-deployment `
        --region $Region
    
    # Update backend service
    Write-Info "Updating backend service..."
    aws ecs update-service `
        --cluster $ECS_CLUSTER_NAME `
        --service "$PROJECT_NAME-$Environment-backend" `
        --force-new-deployment `
        --region $Region
    
    # Wait for services to reach steady state
    Write-Info "Waiting for services to stabilize..."
    aws ecs wait services-stable `
        --cluster $ECS_CLUSTER_NAME `
        --services "$PROJECT_NAME-$Environment-frontend" `
        --region $Region
    
    aws ecs wait services-stable `
        --cluster $ECS_CLUSTER_NAME `
        --services "$PROJECT_NAME-$Environment-backend" `
        --region $Region
    
    Write-Info "ECS deployment completed"
}

# Run database migrations
function Invoke-Migrations {
    Write-Info "Running database migrations..."
    
    # Get the backend task definition
    $TASK_DEF_ARN = aws ecs describe-task-definition `
        --task-definition "$PROJECT_NAME-$Environment-backend" `
        --query 'taskDefinition.taskDefinitionArn' `
        --output text `
        --region $Region
    
    # Get network configuration from the service
    $SERVICE_CONFIG = aws ecs describe-services `
        --cluster $ECS_CLUSTER_NAME `
        --services "$PROJECT_NAME-$Environment-backend" `
        --query 'services[0].networkConfiguration.awsvpcConfiguration' `
        --region $Region | ConvertFrom-Json
    
    $SUBNETS = $SERVICE_CONFIG.subnets[0]
    $SECURITY_GROUPS = $SERVICE_CONFIG.securityGroups[0]
    
    # Run migration task
    $overrides = @{
        containerOverrides = @(@{
            name = "backend"
            command = @("python", "-c", "from app import app, db; app.app_context().push(); db.create_all(); print('Database migrations completed')")
        })
    } | ConvertTo-Json -Depth 3 -Compress
    
    $networkConfig = @{
        awsvpcConfiguration = @{
            subnets = @($SUBNETS)
            securityGroups = @($SECURITY_GROUPS)
            assignPublicIp = "DISABLED"
        }
    } | ConvertTo-Json -Depth 3 -Compress
    
    $TASK_ARN = aws ecs run-task `
        --cluster $ECS_CLUSTER_NAME `
        --task-definition $TASK_DEF_ARN `
        --overrides $overrides `
        --launch-type FARGATE `
        --network-configuration $networkConfig `
        --query 'tasks[0].taskArn' `
        --output text `
        --region $Region
    
    # Wait for migration task to complete
    Write-Info "Waiting for migration task to complete..."
    aws ecs wait tasks-stopped `
        --cluster $ECS_CLUSTER_NAME `
        --tasks $TASK_ARN `
        --region $Region
    
    # Check if migration was successful
    $EXIT_CODE = aws ecs describe-tasks `
        --cluster $ECS_CLUSTER_NAME `
        --tasks $TASK_ARN `
        --query 'tasks[0].containers[0].exitCode' `
        --output text `
        --region $Region
    
    if ($EXIT_CODE -ne "0") {
        Write-Error "Database migration failed with exit code: $EXIT_CODE"
        exit 1
    }
    
    Write-Info "Database migrations completed successfully"
}

# Show deployment status
function Show-DeploymentStatus {
    Write-Header "Deployment Status"
    
    # Check ECS cluster status
    Write-Info "ECS Cluster Status:"
    aws ecs describe-clusters `
        --clusters $ECS_CLUSTER_NAME `
        --include INSIGHTS `
        --query 'clusters[0].{Status:status,TasksRunning:runningTasksCount,TasksPending:pendingTasksCount,ActiveServices:activeServicesCount}' `
        --output table `
        --region $Region
    
    Write-Info "Service Status:"
    aws ecs describe-services `
        --cluster $ECS_CLUSTER_NAME `
        --services "$PROJECT_NAME-$Environment-frontend" "$PROJECT_NAME-$Environment-backend" `
        --query 'services[*].{Service:serviceName,Status:status,Running:runningCount,Desired:desiredCount,TaskDefinition:taskDefinition}' `
        --output table `
        --region $Region
    
    # Get ALB DNS name
    Push-Location terraform
    try {
        $ALB_DNS = terraform output -raw alb_dns_name 2>$null
        if (-not $ALB_DNS) { $ALB_DNS = "Not available" }
    }
    catch {
        $ALB_DNS = "Not available"
    }
    finally {
        Pop-Location
    }
    
    Write-Info "Application Load Balancer: $ALB_DNS"
    
    # Check health endpoints
    if ($ALB_DNS -ne "Not available") {
        Write-Info "Health Check Status:"
        try {
            $frontendStatus = Invoke-WebRequest -Uri "https://$ALB_DNS/health" -Method Head -TimeoutSec 10
            Write-Host "Frontend: $($frontendStatus.StatusCode)"
        }
        catch {
            Write-Host "Frontend: Failed"
        }
        
        try {
            $backendStatus = Invoke-WebRequest -Uri "https://$ALB_DNS/api/health" -Method Head -TimeoutSec 10
            Write-Host "Backend API: $($backendStatus.StatusCode)"
        }
        catch {
            Write-Host "Backend API: Failed"
        }
    }
}

# Health check function
function Test-Health {
    Write-Info "Performing health check..."
    
    # Get ALB DNS name from Terraform output
    Push-Location terraform
    try {
        $ALB_DNS = terraform output -raw alb_dns_name 2>$null
    }
    catch {
        $ALB_DNS = ""
    }
    finally {
        Pop-Location
    }
    
    if ([string]::IsNullOrEmpty($ALB_DNS)) {
        Write-Warn "Load balancer DNS not yet available"
        return
    }
    
    # Check frontend
    try {
        $response = Invoke-WebRequest -Uri "https://$ALB_DNS/health" -TimeoutSec 10
        Write-Info "Frontend health check passed"
    }
    catch {
        Write-Error "Frontend health check failed"
    }
    
    # Check backend API
    try {
        $response = Invoke-WebRequest -Uri "https://$ALB_DNS/api/health" -TimeoutSec 10
        Write-Info "Backend health check passed"
    }
    catch {
        Write-Error "Backend health check failed"
    }
}

# Rollback function
function Invoke-Rollback {
    Write-Warn "Rolling back deployment..."
    
    # Get previous task definition revisions
    Write-Info "Getting previous task definition revisions..."
    
    # Rollback frontend service
    $FRONTEND_TASK_DEF = aws ecs describe-services `
        --cluster $ECS_CLUSTER_NAME `
        --services "$PROJECT_NAME-$Environment-frontend" `
        --query 'services[0].taskDefinition' `
        --output text `
        --region $Region
    
    # Get previous revision (subtract 1 from current revision)
    $revisionMatch = [regex]::Match($FRONTEND_TASK_DEF, ':(\d+)$')
    if ($revisionMatch.Success) {
        $currentRev = [int]$revisionMatch.Groups[1].Value
        $prevRev = $currentRev - 1
        $FRONTEND_PREV_TASK_DEF = $FRONTEND_TASK_DEF -replace ':(\d+)$', ":$prevRev"
    }
    
    # Rollback backend service
    $BACKEND_TASK_DEF = aws ecs describe-services `
        --cluster $ECS_CLUSTER_NAME `
        --services "$PROJECT_NAME-$Environment-backend" `
        --query 'services[0].taskDefinition' `
        --output text `
        --region $Region
    
    $revisionMatch = [regex]::Match($BACKEND_TASK_DEF, ':(\d+)$')
    if ($revisionMatch.Success) {
        $currentRev = [int]$revisionMatch.Groups[1].Value
        $prevRev = $currentRev - 1
        $BACKEND_PREV_TASK_DEF = $BACKEND_TASK_DEF -replace ':(\d+)$', ":$prevRev"
    }
    
    # Update services with previous task definitions
    aws ecs update-service `
        --cluster $ECS_CLUSTER_NAME `
        --service "$PROJECT_NAME-$Environment-frontend" `
        --task-definition $FRONTEND_PREV_TASK_DEF `
        --region $Region
    
    aws ecs update-service `
        --cluster $ECS_CLUSTER_NAME `
        --service "$PROJECT_NAME-$Environment-backend" `
        --task-definition $BACKEND_PREV_TASK_DEF `
        --region $Region
    
    # Wait for rollback to complete
    aws ecs wait services-stable `
        --cluster $ECS_CLUSTER_NAME `
        --services "$PROJECT_NAME-$Environment-frontend" "$PROJECT_NAME-$Environment-backend" `
        --region $Region
    
    Write-Info "Rollback completed"
}

# Main deployment flow
function Start-Deployment {
    Write-Header "Starting deployment for environment: $Environment"
    
    # Validate prerequisites
    Test-Prerequisites
    
    # Initialize Terraform if needed
    if ($env:INIT_TERRAFORM -eq "true") {
        Initialize-Terraform
    }
    
    # Apply infrastructure changes
    if ($env:SKIP_TERRAFORM -ne "true") {
        Deploy-Infrastructure
    }
    
    # Build and push images
    if ($env:SKIP_BUILD -ne "true") {
        Build-AndPushImages
    }
    
    # Deploy to ECS
    Deploy-ToECS
    
    # Run migrations
    if ($env:SKIP_MIGRATIONS -ne "true") {
        Invoke-Migrations
    }
    
    # Show deployment status
    Show-DeploymentStatus
    
    Write-Success "Deployment completed successfully!"
    
    Push-Location terraform
    try {
        $albDns = terraform output -raw alb_dns_name 2>$null
        if ($albDns) {
            Write-Info "Application URL: https://$albDns"
        }
    }
    finally {
        Pop-Location
    }
}

# Handle command line arguments
switch ($Action.ToLower()) {
    "deploy" {
        Start-Deployment
    }
    "rollback" {
        Invoke-Rollback
    }
    "health" {
        Test-Health
    }
    default {
        Write-Host "Usage: .\deploy.ps1 -Environment [dev|staging|production] -Region [aws-region] -Action [deploy|rollback|health]"
        exit 1
    }
}
