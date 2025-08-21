output "ecs_cluster_id" {
  description = "ID of the ECS cluster"
  value       = aws_ecs_cluster.main.id
}

output "ecs_cluster_name" {
  description = "Name of the ECS cluster"
  value       = aws_ecs_cluster.main.name
}

output "alb_arn" {
  description = "ARN of the Application Load Balancer"
  value       = aws_lb.main.arn
}

output "alb_arn_suffix" {
  description = "ARN suffix of the Application Load Balancer"
  value       = aws_lb.main.arn_suffix
}

output "alb_dns_name" {
  description = "DNS name of the Application Load Balancer"
  value       = aws_lb.main.dns_name
}

output "alb_zone_id" {
  description = "Zone ID of the Application Load Balancer"
  value       = aws_lb.main.zone_id
}

output "frontend_target_group_arn" {
  description = "ARN of the frontend target group"
  value       = aws_lb_target_group.frontend.arn
}

output "backend_target_group_arn" {
  description = "ARN of the backend target group"
  value       = aws_lb_target_group.backend.arn
}

output "gateway_target_group_arn" {
  description = "ARN of the gateway target group"
  value       = aws_lb_target_group.gateway.arn
}

output "payment_target_group_arn" {
  description = "ARN of the payment target group"
  value       = aws_lb_target_group.payment.arn
}

output "product_target_group_arn" {
  description = "ARN of the product target group"
  value       = aws_lb_target_group.product.arn
}

output "log_group_names" {
  description = "Names of the CloudWatch log groups"
  value = {
    frontend = aws_cloudwatch_log_group.frontend.name
    gateway  = aws_cloudwatch_log_group.gateway.name
    product  = aws_cloudwatch_log_group.product_service.name
    payment  = aws_cloudwatch_log_group.payment_service.name
    auth     = aws_cloudwatch_log_group.auth_service.name
  }
}
