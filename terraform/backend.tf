# Backend Configuration
# This configures Terraform to use S3 for remote state storage
terraform {
  backend "s3" {
    bucket = "techvault-terraform-state-330b9eeb"
    key    = "techvault/terraform.tfstate"
    region = "us-west-2"
  }
}

# S3 bucket for Terraform state
# This bucket stores the remote state for all environments
resource "random_id" "state_bucket_suffix" {
  byte_length = 4
}

resource "aws_s3_bucket" "terraform_state" {
  bucket = "techvault-terraform-state-${random_id.state_bucket_suffix.hex}"

  tags = {
    Name        = "TechVault Terraform State"
    Environment = "shared"
    Project     = "techvault"
    ManagedBy   = "terraform"
  }
}

resource "aws_s3_bucket_versioning" "terraform_state" {
  bucket = aws_s3_bucket.terraform_state.id
  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "terraform_state" {
  bucket = aws_s3_bucket.terraform_state.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_s3_bucket_public_access_block" "terraform_state" {
  bucket = aws_s3_bucket.terraform_state.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# Output the bucket name for reference
output "state_bucket_name" {
  description = "Name of the S3 bucket for Terraform state"
  value       = aws_s3_bucket.terraform_state.id
}
