output "alb_logs_bucket_id" {
  description = "ID of the ALB logs S3 bucket"
  value       = aws_s3_bucket.alb_logs.id
}

output "alb_logs_bucket_arn" {
  description = "ARN of the ALB logs S3 bucket"
  value       = aws_s3_bucket.alb_logs.arn
}

output "database_url_parameter_name" {
  description = "SSM parameter name for database URL"
  value       = aws_ssm_parameter.database_url.name
}

output "elasticsearch_url_parameter_name" {
  description = "SSM parameter name for Elasticsearch URL"
  value       = aws_ssm_parameter.elasticsearch_url.name
}

output "redis_url_parameter_name" {
  description = "SSM parameter name for Redis URL"
  value       = aws_ssm_parameter.redis_url.name
}

output "jwt_secret_parameter_name" {
  description = "SSM parameter name for JWT secret"
  value       = aws_ssm_parameter.jwt_secret.name
}

output "jwt_secret" {
  description = "Generated JWT secret"
  value       = random_password.jwt_secret.result
  sensitive   = true
}
