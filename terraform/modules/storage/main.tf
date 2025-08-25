# Random suffix for bucket name
resource "random_id" "bucket_suffix" {
  byte_length = 4
}

# Random JWT secret
resource "random_password" "jwt_secret" {
  length  = 64
  special = true
}

# S3 Bucket for ALB logs
resource "aws_s3_bucket" "alb_logs" {
  bucket = "${var.project_name}-${var.environment}-alb-logs-${random_id.bucket_suffix.hex}"

  tags = merge(var.common_tags, {
    Name = "${var.project_name}-${var.environment}-alb-logs"
  })
}

resource "aws_s3_bucket_versioning" "alb_logs" {
  bucket = aws_s3_bucket.alb_logs.id
  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "alb_logs" {
  bucket = aws_s3_bucket.alb_logs.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_s3_bucket_public_access_block" "alb_logs" {
  bucket = aws_s3_bucket.alb_logs.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_lifecycle_configuration" "alb_logs" {
  bucket = aws_s3_bucket.alb_logs.id

  rule {
    id     = "log_retention"
    status = "Enabled"

    filter {
      prefix = ""
    }

    expiration {
      days = 90
    }

    noncurrent_version_expiration {
      noncurrent_days = 30
    }
  }
}

# Get current AWS region
data "aws_region" "current" {}

# Get ELB service account for the region
data "aws_elb_service_account" "main" {}

resource "aws_s3_bucket_policy" "alb_logs" {
  bucket = aws_s3_bucket.alb_logs.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          AWS = data.aws_elb_service_account.main.arn
        }
        Action   = "s3:PutObject"
        Resource = "${aws_s3_bucket.alb_logs.arn}/*"
      },
      {
        Effect = "Allow"
        Principal = {
          Service = "delivery.logs.amazonaws.com"
        }
        Action   = "s3:PutObject"
        Resource = "${aws_s3_bucket.alb_logs.arn}/*"
      },
      {
        Effect = "Allow"
        Principal = {
          AWS = data.aws_elb_service_account.main.arn
        }
        Action   = "s3:GetBucketAcl"
        Resource = aws_s3_bucket.alb_logs.arn
      }
    ]
  })
}

# SSM Parameters for storing secrets
resource "aws_ssm_parameter" "database_url" {
  name  = "/${var.project_name}/${var.environment}/database_url"
  type  = "SecureString"
  value = "postgresql://${var.rds_username}:${var.rds_password}@${var.rds_endpoint}/${var.rds_database_name}"

  tags = merge(var.common_tags, {
    Name = "${var.project_name}-${var.environment}-database-url"
  })
}

resource "aws_ssm_parameter" "elasticsearch_url" {
  name  = "/${var.project_name}/${var.environment}/elasticsearch_url"
  type  = "SecureString"
  value = "https://${var.elasticsearch_endpoint}"

  tags = merge(var.common_tags, {
    Name = "${var.project_name}-${var.environment}-elasticsearch-url"
  })
}

resource "aws_ssm_parameter" "redis_url" {
  name  = "/${var.project_name}/${var.environment}/redis_url"
  type  = "SecureString"
  value = "redis://${var.redis_endpoint}:6379/0"

  tags = merge(var.common_tags, {
    Name = "${var.project_name}-${var.environment}-redis-url"
  })
}

resource "aws_ssm_parameter" "jwt_secret" {
  name  = "/${var.project_name}/${var.environment}/jwt_secret"
  type  = "SecureString"
  value = random_password.jwt_secret.result

  tags = merge(var.common_tags, {
    Name = "${var.project_name}-${var.environment}-jwt-secret"
  })
}
