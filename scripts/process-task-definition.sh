#!/bin/bash

# Task Definition Template Processor
# Usage: ./process-task-definition.sh <service-name> <environment> <image-tag>

set -e

SERVICE_NAME=$1
ENVIRONMENT=${2:-production}
IMAGE_TAG=${3:-latest}

if [ -z "$SERVICE_NAME" ]; then
    echo "Usage: $0 <service-name> [environment] [image-tag]"
    echo "Available services: frontend, gateway, auth-service, product-service, payment-service"
    exit 1
fi

# Get AWS account ID and region
AWS_ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
AWS_REGION=${AWS_DEFAULT_REGION:-us-west-2}

# Set environment-specific variables
case $ENVIRONMENT in
    "production")
        NODE_ENV="production"
        GIN_MODE="release"
        API_GATEWAY_URL="https://api.techvault.com"
        FRONTEND_URL="https://techvault.com"
        ;;
    "staging")
        NODE_ENV="production"
        GIN_MODE="release"
        API_GATEWAY_URL="https://api-staging.techvault.com"
        FRONTEND_URL="https://staging.techvault.com"
        ;;
    "development")
        NODE_ENV="development"
        GIN_MODE="debug"
        API_GATEWAY_URL="https://api-dev.techvault.com"
        FRONTEND_URL="https://dev.techvault.com"
        ;;
esac

# Service URLs (internal ALB endpoints)
AUTH_SERVICE_URL="http://techvault-auth-service.internal:5001"
PRODUCT_SERVICE_URL="http://techvault-product-service.internal:5002"
PAYMENT_SERVICE_URL="http://techvault-payment-service.internal:5003"

# Template file path
TEMPLATE_FILE="aws/task-definitions/${SERVICE_NAME}.json"
OUTPUT_FILE="aws/task-definitions/processed/${SERVICE_NAME}-${ENVIRONMENT}.json"

if [ ! -f "$TEMPLATE_FILE" ]; then
    echo "Error: Template file $TEMPLATE_FILE not found"
    exit 1
fi

# Create output directory
mkdir -p "aws/task-definitions/processed"

# Process template with environment substitution
envsubst << EOF > "$OUTPUT_FILE"
$(cat "$TEMPLATE_FILE")
EOF

echo "Task definition processed: $OUTPUT_FILE"
echo "Variables used:"
echo "  AWS_ACCOUNT_ID: $AWS_ACCOUNT_ID"
echo "  AWS_REGION: $AWS_REGION"
echo "  IMAGE_TAG: $IMAGE_TAG"
echo "  ENVIRONMENT: $ENVIRONMENT"
echo "  NODE_ENV: $NODE_ENV"
echo "  GIN_MODE: $GIN_MODE"
