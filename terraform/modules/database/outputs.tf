output "rds_endpoint" {
  description = "RDS instance endpoint"
  value       = aws_db_instance.main.endpoint
}

output "rds_instance_id" {
  description = "RDS instance identifier"
  value       = aws_db_instance.main.id
}

output "rds_port" {
  description = "RDS instance port"
  value       = aws_db_instance.main.port
}

output "rds_database_name" {
  description = "RDS database name"
  value       = aws_db_instance.main.db_name
}

output "rds_username" {
  description = "RDS master username"
  value       = aws_db_instance.main.username
  sensitive   = true
}

output "rds_password" {
  description = "RDS master password"
  value       = random_password.db_password.result
  sensitive   = true
}

output "redis_endpoint" {
  description = "Redis cluster endpoint"
  value       = aws_elasticache_cluster.main.cache_nodes[0].address
}

output "redis_cluster_id" {
  description = "Redis cluster identifier"
  value       = aws_elasticache_cluster.main.cluster_id
}

output "redis_port" {
  description = "Redis cluster port"
  value       = aws_elasticache_cluster.main.cache_nodes[0].port
}

output "elasticsearch_endpoint" {
  description = "Elasticsearch domain endpoint"
  value       = var.enable_elasticsearch ? aws_elasticsearch_domain.main[0].endpoint : ""
}

output "elasticsearch_kibana_endpoint" {
  description = "Elasticsearch Kibana endpoint"
  value       = var.enable_elasticsearch ? aws_elasticsearch_domain.main[0].kibana_endpoint : ""
}
