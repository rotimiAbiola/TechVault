# CloudWatch Log Group for ECS Cluster
resource "aws_cloudwatch_log_group" "ecs_cluster" {
  name              = "/aws/ecs/${var.project_name}-${var.environment}-cluster"
  retention_in_days = 30

  tags = merge(var.common_tags, {
    Name = "${var.project_name}-${var.environment}-ecs-cluster-logs"
  })
}

# CloudWatch Log Groups for each service
resource "aws_cloudwatch_log_group" "frontend" {
  name              = "/aws/ecs/${var.project_name}-${var.environment}-frontend"
  retention_in_days = 30

  tags = merge(var.common_tags, {
    Name    = "${var.project_name}-${var.environment}-frontend-logs"
    Service = "frontend"
  })
}

resource "aws_cloudwatch_log_group" "gateway" {
  name              = "/aws/ecs/${var.project_name}-${var.environment}-gateway"
  retention_in_days = 30

  tags = merge(var.common_tags, {
    Name    = "${var.project_name}-${var.environment}-gateway-logs"
    Service = "gateway"
  })
}

resource "aws_cloudwatch_log_group" "product_service" {
  name              = "/aws/ecs/${var.project_name}-${var.environment}-product"
  retention_in_days = 30

  tags = merge(var.common_tags, {
    Name    = "${var.project_name}-${var.environment}-product-logs"
    Service = "product"
  })
}

resource "aws_cloudwatch_log_group" "payment_service" {
  name              = "/aws/ecs/${var.project_name}-${var.environment}-payment"
  retention_in_days = 30

  tags = merge(var.common_tags, {
    Name    = "${var.project_name}-${var.environment}-payment-logs"
    Service = "payment"
  })
}

resource "aws_cloudwatch_log_group" "auth_service" {
  name              = "/aws/ecs/${var.project_name}-${var.environment}-auth"
  retention_in_days = 30

  tags = merge(var.common_tags, {
    Name    = "${var.project_name}-${var.environment}-auth-logs"
    Service = "auth"
  })
}

# ECS Cluster
resource "aws_ecs_cluster" "main" {
  name = "${var.project_name}-${var.environment}-cluster"

  configuration {
    execute_command_configuration {
      logging = "OVERRIDE"
      log_configuration {
        cloud_watch_log_group_name = aws_cloudwatch_log_group.ecs_cluster.name
      }
    }
  }

  setting {
    name  = "containerInsights"
    value = "enabled"
  }

  tags = merge(var.common_tags, {
    Name = "${var.project_name}-${var.environment}-cluster"
  })
}

# ECS Cluster Capacity Providers
resource "aws_ecs_cluster_capacity_providers" "main" {
  cluster_name = aws_ecs_cluster.main.name

  capacity_providers = ["FARGATE", "FARGATE_SPOT"]

  default_capacity_provider_strategy {
    base              = 1
    weight            = 100
    capacity_provider = "FARGATE"
  }
}

# Application Load Balancer
resource "aws_lb" "main" {
  name               = "${var.project_name}-${var.environment}-alb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [var.alb_security_group_id]
  subnets            = var.public_subnet_ids

  enable_deletion_protection = false

  access_logs {
    bucket  = var.alb_logs_bucket_id
    prefix  = "alb"
    enabled = true
  }

  tags = merge(var.common_tags, {
    Name = "${var.project_name}-${var.environment}-alb"
  })
}

# ALB Target Groups
resource "aws_lb_target_group" "frontend" {
  name        = "${var.project_name}-${var.environment}-frontend"
  port        = 3000
  protocol    = "HTTP"
  vpc_id      = var.vpc_id
  target_type = "ip"

  health_check {
    enabled             = true
    healthy_threshold   = 2
    interval            = 30
    matcher             = "200"
    path                = "/"
    port                = "traffic-port"
    protocol            = "HTTP"
    timeout             = 5
    unhealthy_threshold = 2
  }

  tags = merge(var.common_tags, {
    Name = "${var.project_name}-${var.environment}-frontend-tg"
  })
}

resource "aws_lb_target_group" "backend" {
  name        = "${var.project_name}-${var.environment}-backend"
  port        = 5000
  protocol    = "HTTP"
  vpc_id      = var.vpc_id
  target_type = "ip"

  health_check {
    enabled             = true
    healthy_threshold   = 2
    interval            = 30
    matcher             = "200"
    path                = "/api/health"
    port                = "traffic-port"
    protocol            = "HTTP"
    timeout             = 5
    unhealthy_threshold = 2
  }

  tags = merge(var.common_tags, {
    Name = "${var.project_name}-${var.environment}-backend-tg"
  })
}

resource "aws_lb_target_group" "gateway" {
  name        = "${var.project_name}-${var.environment}-gateway"
  port        = 3001
  protocol    = "HTTP"
  vpc_id      = var.vpc_id
  target_type = "ip"

  health_check {
    enabled             = true
    healthy_threshold   = 2
    interval            = 30
    matcher             = "200"
    path                = "/health"
    port                = "traffic-port"
    protocol            = "HTTP"
    timeout             = 5
    unhealthy_threshold = 2
  }

  tags = merge(var.common_tags, {
    Name = "${var.project_name}-${var.environment}-gateway-tg"
  })
}

resource "aws_lb_target_group" "payment" {
  name        = "${var.project_name}-${var.environment}-payment"
  port        = 8080
  protocol    = "HTTP"
  vpc_id      = var.vpc_id
  target_type = "ip"

  health_check {
    enabled             = true
    healthy_threshold   = 2
    interval            = 30
    matcher             = "200"
    path                = "/health"
    port                = "traffic-port"
    protocol            = "HTTP"
    timeout             = 5
    unhealthy_threshold = 2
  }

  tags = merge(var.common_tags, {
    Name = "${var.project_name}-${var.environment}-payment-tg"
  })
}

resource "aws_lb_target_group" "product" {
  name        = "${var.project_name}-${var.environment}-product"
  port        = 8082
  protocol    = "HTTP"
  vpc_id      = var.vpc_id
  target_type = "ip"

  health_check {
    enabled             = true
    healthy_threshold   = 2
    interval            = 30
    matcher             = "200"
    path                = "/health"
    port                = "traffic-port"
    protocol            = "HTTP"
    timeout             = 5
    unhealthy_threshold = 2
  }

  tags = merge(var.common_tags, {
    Name = "${var.project_name}-${var.environment}-product-tg"
  })
}

# ALB Listeners
resource "aws_lb_listener" "main" {
  load_balancer_arn = aws_lb.main.arn
  port              = "80"
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.frontend.arn
  }
}

# ALB Listener Rules
resource "aws_lb_listener_rule" "frontend" {
  listener_arn = aws_lb_listener.main.arn
  priority     = 100

  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.frontend.arn
  }

  condition {
    path_pattern {
      values = ["/", "/static/*", "/assets/*"]
    }
  }
}

resource "aws_lb_listener_rule" "gateway" {
  listener_arn = aws_lb_listener.main.arn
  priority     = 200

  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.gateway.arn
  }

  condition {
    path_pattern {
      values = ["/api/*"]
    }
  }
}

resource "aws_lb_listener_rule" "payment" {
  listener_arn = aws_lb_listener.main.arn
  priority     = 300

  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.payment.arn
  }

  condition {
    path_pattern {
      values = ["/payment/*"]
    }
  }
}

resource "aws_lb_listener_rule" "product" {
  listener_arn = aws_lb_listener.main.arn
  priority     = 400

  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.product.arn
  }

  condition {
    path_pattern {
      values = ["/products/*"]
    }
  }
}

# ECS Task Execution Role
resource "aws_iam_role" "ecs_task_execution_role" {
  name = "${var.project_name}-${var.environment}-ecs-task-execution-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "ecs-tasks.amazonaws.com"
        }
      }
    ]
  })

  tags = var.common_tags
}

resource "aws_iam_role_policy_attachment" "ecs_task_execution_role_policy" {
  role       = aws_iam_role.ecs_task_execution_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

# Additional policy for CloudWatch Logs
resource "aws_iam_role_policy" "ecs_task_execution_cloudwatch" {
  name = "${var.project_name}-${var.environment}-ecs-cloudwatch-policy"
  role = aws_iam_role.ecs_task_execution_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ]
        Resource = "*"
      }
    ]
  })
}

# ECS Task Definitions
resource "aws_ecs_task_definition" "frontend" {
  family                   = "${var.project_name}-${var.environment}-frontend"
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  cpu                      = 256
  memory                   = 512
  execution_role_arn       = aws_iam_role.ecs_task_execution_role.arn

  container_definitions = jsonencode([
    {
      name  = "frontend"
      image = "nginx:alpine"
      portMappings = [
        {
          containerPort = 3000
          protocol      = "tcp"
        }
      ]
      logConfiguration = {
        logDriver = "awslogs"
        options = {
          "awslogs-group"         = aws_cloudwatch_log_group.frontend.name
          "awslogs-region"        = data.aws_region.current.name
          "awslogs-stream-prefix" = "ecs"
        }
      }
      essential = true
    }
  ])

  tags = merge(var.common_tags, {
    Name = "${var.project_name}-${var.environment}-frontend-task"
  })
}

resource "aws_ecs_task_definition" "gateway" {
  family                   = "${var.project_name}-${var.environment}-gateway"
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  cpu                      = 256
  memory                   = 512
  execution_role_arn       = aws_iam_role.ecs_task_execution_role.arn

  container_definitions = jsonencode([
    {
      name  = "gateway"
      image = "node:alpine"
      portMappings = [
        {
          containerPort = 3001
          protocol      = "tcp"
        }
      ]
      logConfiguration = {
        logDriver = "awslogs"
        options = {
          "awslogs-group"         = aws_cloudwatch_log_group.gateway.name
          "awslogs-region"        = data.aws_region.current.name
          "awslogs-stream-prefix" = "ecs"
        }
      }
      essential = true
    }
  ])

  tags = merge(var.common_tags, {
    Name = "${var.project_name}-${var.environment}-gateway-task"
  })
}

resource "aws_ecs_task_definition" "product" {
  family                   = "${var.project_name}-${var.environment}-product"
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  cpu                      = 256
  memory                   = 512
  execution_role_arn       = aws_iam_role.ecs_task_execution_role.arn

  container_definitions = jsonencode([
    {
      name  = "product"
      image = "golang:alpine"
      portMappings = [
        {
          containerPort = 8082
          protocol      = "tcp"
        }
      ]
      logConfiguration = {
        logDriver = "awslogs"
        options = {
          "awslogs-group"         = aws_cloudwatch_log_group.product_service.name
          "awslogs-region"        = data.aws_region.current.name
          "awslogs-stream-prefix" = "ecs"
        }
      }
      essential = true
    }
  ])

  tags = merge(var.common_tags, {
    Name = "${var.project_name}-${var.environment}-product-task"
  })
}

resource "aws_ecs_task_definition" "payment" {
  family                   = "${var.project_name}-${var.environment}-payment"
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  cpu                      = 256
  memory                   = 512
  execution_role_arn       = aws_iam_role.ecs_task_execution_role.arn

  container_definitions = jsonencode([
    {
      name  = "payment"
      image = "openjdk:11-jre-slim"
      portMappings = [
        {
          containerPort = 8080
          protocol      = "tcp"
        }
      ]
      logConfiguration = {
        logDriver = "awslogs"
        options = {
          "awslogs-group"         = aws_cloudwatch_log_group.payment_service.name
          "awslogs-region"        = data.aws_region.current.name
          "awslogs-stream-prefix" = "ecs"
        }
      }
      essential = true
    }
  ])

  tags = merge(var.common_tags, {
    Name = "${var.project_name}-${var.environment}-payment-task"
  })
}

resource "aws_ecs_task_definition" "auth" {
  family                   = "${var.project_name}-${var.environment}-auth"
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  cpu                      = 256
  memory                   = 512
  execution_role_arn       = aws_iam_role.ecs_task_execution_role.arn

  container_definitions = jsonencode([
    {
      name  = "auth"
      image = "python:3.9-slim"
      portMappings = [
        {
          containerPort = 5001
          protocol      = "tcp"
        }
      ]
      logConfiguration = {
        logDriver = "awslogs"
        options = {
          "awslogs-group"         = aws_cloudwatch_log_group.auth_service.name
          "awslogs-region"        = data.aws_region.current.name
          "awslogs-stream-prefix" = "ecs"
        }
      }
      essential = true
    }
  ])

  tags = merge(var.common_tags, {
    Name = "${var.project_name}-${var.environment}-auth-task"
  })
}

# Data source for current AWS region
data "aws_region" "current" {}
