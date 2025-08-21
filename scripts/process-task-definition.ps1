# Task Definition Template Processor (PowerShell)
# Usage: .\process-task-definition.ps1 -ServiceName <service> -Environment <env> -ImageTag <tag>

param(
    [Parameter(Mandatory=$true)]
    [string]$ServiceName,
    
    [string]$Environment = "production",
    [string]$ImageTag = "latest"
)

$ValidServices = @("frontend", "gateway", "auth-service", "product-service", "payment-service")

if ($ServiceName -notin $ValidServices) {
    Write-Error "Invalid service name. Available services: $($ValidServices -join ', ')"
    exit 1
}

# Get AWS account ID and region
try {
    $AwsAccountId = (aws sts get-caller-identity --query Account --output text)
    $AwsRegion = if ($env:AWS_DEFAULT_REGION) { $env:AWS_DEFAULT_REGION } else { "us-west-2" }
} catch {
    Write-Error "Failed to get AWS account information. Ensure AWS CLI is configured."
    exit 1
}

# Set environment-specific variables
switch ($Environment) {
    "production" {
        $NodeEnv = "production"
        $GinMode = "release"
        $ApiGatewayUrl = "https://api.techvault.com"
        $FrontendUrl = "https://techvault.com"
    }
    "staging" {
        $NodeEnv = "production"
        $GinMode = "release"
        $ApiGatewayUrl = "https://api-staging.techvault.com"
        $FrontendUrl = "https://staging.techvault.com"
    }
    "development" {
        $NodeEnv = "development"
        $GinMode = "debug"
        $ApiGatewayUrl = "https://api-dev.techvault.com"
        $FrontendUrl = "https://dev.techvault.com"
    }
}

# Service URLs (internal ALB endpoints)
$AuthServiceUrl = "http://techvault-auth-service.internal:5001"
$ProductServiceUrl = "http://techvault-product-service.internal:5002"
$PaymentServiceUrl = "http://techvault-payment-service.internal:5003"

# File paths
$TemplateFile = "aws\task-definitions\$ServiceName.json"
$OutputFile = "aws\task-definitions\processed\$ServiceName-$Environment.json"

if (-not (Test-Path $TemplateFile)) {
    Write-Error "Template file $TemplateFile not found"
    exit 1
}

# Create output directory
$OutputDir = Split-Path $OutputFile -Parent
if (-not (Test-Path $OutputDir)) {
    New-Item -ItemType Directory -Path $OutputDir -Force | Out-Null
}

# Read template and replace variables
$Template = Get-Content $TemplateFile -Raw
$ProcessedContent = $Template `
    -replace '\$\{AWS_ACCOUNT_ID\}', $AwsAccountId `
    -replace '\$\{AWS_REGION\}', $AwsRegion `
    -replace '\$\{IMAGE_TAG\}', $ImageTag `
    -replace '\$\{ENVIRONMENT\}', $Environment `
    -replace '\$\{NODE_ENV\}', $NodeEnv `
    -replace '\$\{GIN_MODE\}', $GinMode `
    -replace '\$\{API_GATEWAY_URL\}', $ApiGatewayUrl `
    -replace '\$\{FRONTEND_URL\}', $FrontendUrl `
    -replace '\$\{AUTH_SERVICE_URL\}', $AuthServiceUrl `
    -replace '\$\{PRODUCT_SERVICE_URL\}', $ProductServiceUrl `
    -replace '\$\{PAYMENT_SERVICE_URL\}', $PaymentServiceUrl

# Write processed content
Set-Content -Path $OutputFile -Value $ProcessedContent

Write-Host "Task definition processed: $OutputFile" -ForegroundColor Green
Write-Host "Variables used:" -ForegroundColor Yellow
Write-Host "  AWS_ACCOUNT_ID: $AwsAccountId"
Write-Host "  AWS_REGION: $AwsRegion"
Write-Host "  IMAGE_TAG: $ImageTag"
Write-Host "  ENVIRONMENT: $Environment"
Write-Host "  NODE_ENV: $NodeEnv"
Write-Host "  GIN_MODE: $GinMode"
