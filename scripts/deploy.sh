#!/bin/bash

# ECS Deployment script for React-Python Application
# Usage: ./deploy.sh [environment] [region]

set -e

# Configuration
ENVIRONMENT=${1:-production}
AWS_REGION=${2:-us-west-2}
PROJECT_NAME="react-python-app"
ECS_CLUSTER_NAME="${PROJECT_NAME}-${ENVIRONMENT}-cluster"
ECR_REPOSITORY_FRONTEND="${PROJECT_NAME}-frontend"
ECR_REPOSITORY_BACKEND="${PROJECT_NAME}-backend"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

echo_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

echo_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Check prerequisites
validate_prerequisites() {
    echo_info "Checking prerequisites..."
    
    # Check if required tools are installed
    for tool in aws docker terraform jq; do
        if ! command -v $tool &> /dev/null; then
            echo_error "$tool is not installed or not in PATH"
            exit 1
        fi
    done
    
    # Check AWS credentials
    if ! aws sts get-caller-identity &> /dev/null; then
        echo_error "AWS credentials not configured"
        exit 1
    fi
    
    echo_info "Prerequisites check passed"
}

# Utility functions
echo_header() {
    echo ""
    echo "=================================================="
    echo "$1"
    echo "=================================================="
}

echo_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}
    
    echo_info "Prerequisites check passed"
}

# Deploy infrastructure with Terraform
deploy_infrastructure() {
    echo_info "Deploying infrastructure with Terraform..."
    
    cd terraform
    
    # Initialize Terraform
    terraform init
    
    # Plan deployment
    terraform plan -var="environment=${ENVIRONMENT}" -var="aws_region=${AWS_REGION}"
    
    # Apply deployment
    terraform apply -auto-approve -var="environment=${ENVIRONMENT}" -var="aws_region=${AWS_REGION}"
    
    cd ..
    
    echo_info "Infrastructure deployment completed"
}

# Build and push Docker images
build_and_push_images() {
    echo_info "Building and pushing Docker images..."
    
    # Get AWS account ID
    AWS_ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
    
    # Get ECR login token
    aws ecr get-login-password --region ${AWS_REGION} | docker login --username AWS --password-stdin ${AWS_ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com
    
    # Build and push frontend image
    FRONTEND_REPO=${AWS_ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com/${ECR_REPOSITORY_FRONTEND}
    echo_info "Building frontend image..."
    docker build -t ${FRONTEND_REPO}:latest ./frontend
    docker tag ${FRONTEND_REPO}:latest ${FRONTEND_REPO}:$(git rev-parse --short HEAD)
    docker push ${FRONTEND_REPO}:latest
    docker push ${FRONTEND_REPO}:$(git rev-parse --short HEAD)
    
    # Build and push backend image
    BACKEND_REPO=${AWS_ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com/${ECR_REPOSITORY_BACKEND}
    echo_info "Building backend image..."
    docker build -t ${BACKEND_REPO}:latest ./backend
    docker tag ${BACKEND_REPO}:latest ${BACKEND_REPO}:$(git rev-parse --short HEAD)
    docker push ${BACKEND_REPO}:latest
    docker push ${BACKEND_REPO}:$(git rev-parse --short HEAD)
    
    echo_info "Docker images built and pushed successfully"
}

# Deploy to ECS
deploy_to_ecs() {
    echo_info "Deploying to ECS..."
    
    # Update frontend service
    echo_info "Updating frontend service..."
    aws ecs update-service \
        --cluster ${ECS_CLUSTER_NAME} \
        --service ${PROJECT_NAME}-${ENVIRONMENT}-frontend \
        --force-new-deployment \
        --region ${AWS_REGION}
    
    # Update backend service
    echo_info "Updating backend service..."
    aws ecs update-service \
        --cluster ${ECS_CLUSTER_NAME} \
        --service ${PROJECT_NAME}-${ENVIRONMENT}-backend \
        --force-new-deployment \
        --region ${AWS_REGION}
    
    # Wait for services to reach steady state
    echo_info "Waiting for services to stabilize..."
    aws ecs wait services-stable \
        --cluster ${ECS_CLUSTER_NAME} \
        --services ${PROJECT_NAME}-${ENVIRONMENT}-frontend \
        --region ${AWS_REGION}
    
    aws ecs wait services-stable \
        --cluster ${ECS_CLUSTER_NAME} \
        --services ${PROJECT_NAME}-${ENVIRONMENT}-backend \
        --region ${AWS_REGION}
    
    echo_info "ECS deployment completed"
}

# Run database migrations
run_migrations() {
    echo_info "Running database migrations..."
    
    # Get the backend task definition
    TASK_DEF_ARN=$(aws ecs describe-task-definition \
        --task-definition ${PROJECT_NAME}-${ENVIRONMENT}-backend \
        --query 'taskDefinition.taskDefinitionArn' \
        --output text \
        --region ${AWS_REGION})
    
    # Get network configuration from the service
    SERVICE_CONFIG=$(aws ecs describe-services \
        --cluster ${ECS_CLUSTER_NAME} \
        --services ${PROJECT_NAME}-${ENVIRONMENT}-backend \
        --query 'services[0].networkConfiguration.awsvpcConfiguration' \
        --region ${AWS_REGION})
    
    SUBNETS=$(echo $SERVICE_CONFIG | jq -r '.subnets[0]')
    SECURITY_GROUPS=$(echo $SERVICE_CONFIG | jq -r '.securityGroups[0]')
    
    # Run migration task
    TASK_ARN=$(aws ecs run-task \
        --cluster ${ECS_CLUSTER_NAME} \
        --task-definition $TASK_DEF_ARN \
        --overrides '{
            "containerOverrides": [{
                "name": "backend",
                "command": ["python", "-c", "from app import app, db; app.app_context().push(); db.create_all(); print(\"Database migrations completed\")"]
            }]
        }' \
        --launch-type FARGATE \
        --network-configuration "awsvpcConfiguration={
            subnets=[$SUBNETS],
            securityGroups=[$SECURITY_GROUPS],
            assignPublicIp=DISABLED
        }" \
        --query 'tasks[0].taskArn' \
        --output text \
        --region ${AWS_REGION})
    
    # Wait for migration task to complete
    echo_info "Waiting for migration task to complete..."
    aws ecs wait tasks-stopped \
        --cluster ${ECS_CLUSTER_NAME} \
        --tasks $TASK_ARN \
        --region ${AWS_REGION}
    
    # Check if migration was successful
    EXIT_CODE=$(aws ecs describe-tasks \
        --cluster ${ECS_CLUSTER_NAME} \
        --tasks $TASK_ARN \
        --query 'tasks[0].containers[0].exitCode' \
        --output text \
        --region ${AWS_REGION})
    
    if [ "$EXIT_CODE" != "0" ]; then
        echo_error "Database migration failed with exit code: $EXIT_CODE"
        exit 1
    fi
    
    echo_info "Database migrations completed successfully"
}

# Deploy monitoring stack (CloudWatch based)
deploy_monitoring() {
    echo_info "CloudWatch monitoring is automatically deployed with Terraform..."
    echo_info "Check AWS Console for CloudWatch dashboards and alarms"
}

# Health check
health_check() {
    echo_info "Performing health check..."
    
    # Get ALB DNS name from Terraform output
    ALB_DNS=$(cd terraform && terraform output -raw alb_dns_name 2>/dev/null || echo "")
    
    if [ -z "$ALB_DNS" ]; then
        echo_warn "Load balancer DNS not yet available"
        return
    fi
    
    # Check frontend
    if curl -f -s "https://${ALB_DNS}/health" > /dev/null; then
        echo_info "Frontend health check passed"
    else
        echo_error "Frontend health check failed"
    fi
    
    # Check backend API
    if curl -f -s "https://${ALB_DNS}/api/health" > /dev/null; then
        echo_info "Backend health check passed"
    else
        echo_error "Backend health check failed"
    fi
}

# Show deployment status
show_deployment_status() {
    echo_header "Deployment Status"
    
    # Check ECS cluster status
    echo_info "ECS Cluster Status:"
    aws ecs describe-clusters \
        --clusters ${ECS_CLUSTER_NAME} \
        --include INSIGHTS \
        --query 'clusters[0].{Status:status,TasksRunning:runningTasksCount,TasksPending:pendingTasksCount,ActiveServices:activeServicesCount}' \
        --output table \
        --region ${AWS_REGION}
    
    echo_info "Service Status:"
    aws ecs describe-services \
        --cluster ${ECS_CLUSTER_NAME} \
        --services ${PROJECT_NAME}-${ENVIRONMENT}-frontend ${PROJECT_NAME}-${ENVIRONMENT}-backend \
        --query 'services[*].{Service:serviceName,Status:status,Running:runningCount,Desired:desiredCount,TaskDefinition:taskDefinition}' \
        --output table \
        --region ${AWS_REGION}
    
    # Get ALB DNS name
    ALB_DNS=$(cd terraform && terraform output -raw alb_dns_name 2>/dev/null || echo "Not available")
    echo_info "Application Load Balancer: $ALB_DNS"
    
    # Check health endpoints
    if [[ "$ALB_DNS" != "Not available" ]]; then
        echo_info "Health Check Status:"
        echo "Frontend: $(curl -s -o /dev/null -w "%{http_code}" https://$ALB_DNS/health || echo "Failed")"
        echo "Backend API: $(curl -s -o /dev/null -w "%{http_code}" https://$ALB_DNS/api/health || echo "Failed")"
    fi
}

# Rollback function
rollback() {
    echo_warn "Rolling back deployment..."
    
    # Get previous task definition revisions
    echo_info "Getting previous task definition revisions..."
    
    # Rollback frontend service
    FRONTEND_TASK_DEF=$(aws ecs describe-services \
        --cluster ${ECS_CLUSTER_NAME} \
        --services ${PROJECT_NAME}-${ENVIRONMENT}-frontend \
        --query 'services[0].taskDefinition' \
        --output text \
        --region ${AWS_REGION})
    
    # Get previous revision (subtract 1 from current revision)
    FRONTEND_PREV_REV=$(echo $FRONTEND_TASK_DEF | sed 's/:.*://' | awk -F: '{print $2-1}')
    FRONTEND_PREV_TASK_DEF=$(echo $FRONTEND_TASK_DEF | sed "s/:.*:/:$FRONTEND_PREV_REV/")
    
    # Rollback backend service
    BACKEND_TASK_DEF=$(aws ecs describe-services \
        --cluster ${ECS_CLUSTER_NAME} \
        --services ${PROJECT_NAME}-${ENVIRONMENT}-backend \
        --query 'services[0].taskDefinition' \
        --output text \
        --region ${AWS_REGION})
    
    BACKEND_PREV_REV=$(echo $BACKEND_TASK_DEF | sed 's/:.*://' | awk -F: '{print $2-1}')
    BACKEND_PREV_TASK_DEF=$(echo $BACKEND_TASK_DEF | sed "s/:.*:/:$BACKEND_PREV_REV/")
    
    # Update services with previous task definitions
    aws ecs update-service \
        --cluster ${ECS_CLUSTER_NAME} \
        --service ${PROJECT_NAME}-${ENVIRONMENT}-frontend \
        --task-definition $FRONTEND_PREV_TASK_DEF \
        --region ${AWS_REGION}
    
    aws ecs update-service \
        --cluster ${ECS_CLUSTER_NAME} \
        --service ${PROJECT_NAME}-${ENVIRONMENT}-backend \
        --task-definition $BACKEND_PREV_TASK_DEF \
        --region ${AWS_REGION}
    
    # Wait for rollback to complete
    aws ecs wait services-stable \
        --cluster ${ECS_CLUSTER_NAME} \
        --services ${PROJECT_NAME}-${ENVIRONMENT}-frontend ${PROJECT_NAME}-${ENVIRONMENT}-backend \
        --region ${AWS_REGION}
    
    echo_info "Rollback completed"
}

# Main deployment flow
main() {
    echo_header "Starting deployment for environment: $ENVIRONMENT"
    
    # Validate prerequisites
    validate_prerequisites
    
    # Initialize Terraform if needed
    if [[ "$INIT_TERRAFORM" == "true" ]]; then
        init_terraform
    fi
    
    # Apply infrastructure changes
    if [[ "$SKIP_TERRAFORM" != "true" ]]; then
        apply_terraform
    fi
    
    # Build and push images
    if [[ "$SKIP_BUILD" != "true" ]]; then
        build_and_push_images
    fi
    
    # Deploy to ECS
    deploy_to_ecs
    
    # Run migrations
    if [[ "$SKIP_MIGRATIONS" != "true" ]]; then
        run_migrations
    fi
    
    # Show deployment status
    show_deployment_status
    
    echo_success "Deployment completed successfully!"
    echo_info "Application URL: https://$(cd terraform && terraform output -raw alb_dns_name)"
}

# Handle command line arguments
case "${1:-deploy}" in
    "deploy")
        main
        ;;
    "rollback")
        rollback
        ;;
    "health")
        health_check
        ;;
    *)
        echo "Usage: $0 [deploy|rollback|health] [environment] [region]"
        exit 1
        ;;
esac
