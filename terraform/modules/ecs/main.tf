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

resource "aws_cloudwatch_log_group" "cart_service" {
  name              = "/aws/ecs/${var.project_name}-${var.environment}-cart"
  retention_in_days = 30

  tags = merge(var.common_tags, {
    Name    = "${var.project_name}-${var.environment}-cart-logs"
    Service = "cart"
  })
}

resource "aws_cloudwatch_log_group" "order_service" {
  name              = "/aws/ecs/${var.project_name}-${var.environment}-order"
  retention_in_days = 30

  tags = merge(var.common_tags, {
    Name    = "${var.project_name}-${var.environment}-order-logs"
    Service = "order"
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
  port        = 80
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
  port        = 5000
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
  port        = 5004
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
  port        = 5002
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

resource "aws_lb_target_group" "auth" {
  name        = "${var.project_name}-${var.environment}-auth"
  port        = 5001
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
    Name = "${var.project_name}-${var.environment}-auth-tg"
  })
}

resource "aws_lb_target_group" "cart" {
  name        = "${var.project_name}-${var.environment}-cart"
  port        = 5003
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
    Name = "${var.project_name}-${var.environment}-cart-tg"
  })
}

resource "aws_lb_target_group" "order" {
  name        = "${var.project_name}-${var.environment}-order"
  port        = 5005
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
    Name = "${var.project_name}-${var.environment}-order-tg"
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

resource "aws_lb_listener_rule" "auth" {
  listener_arn = aws_lb_listener.main.arn
  priority     = 500

  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.auth.arn
  }

  condition {
    path_pattern {
      values = ["/auth/*"]
    }
  }
}

resource "aws_lb_listener_rule" "cart" {
  listener_arn = aws_lb_listener.main.arn
  priority     = 600

  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.cart.arn
  }

  condition {
    path_pattern {
      values = ["/cart/*"]
    }
  }
}

resource "aws_lb_listener_rule" "order" {
  listener_arn = aws_lb_listener.main.arn
  priority     = 700

  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.order.arn
  }

  condition {
    path_pattern {
      values = ["/order/*", "/orders/*"]
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
          containerPort = 80
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
      image = "${var.gateway_image}:${var.image_tag}"
      environment = [
        {
          name  = "PORT"
          value = "5000"
        },
        {
          name  = "AUTH_SERVICE_URL"
          value = "http://auth-service:5001"
        },
        {
          name  = "PRODUCT_SERVICE_URL"
          value = "http://product-service:5002"
        },
        {
          name  = "CART_SERVICE_URL"
          value = "http://cart-service:5003"
        },
        {
          name  = "PAYMENT_SERVICE_URL"
          value = "http://payment-service:5004"
        },
        {
          name  = "ORDER_SERVICE_URL"
          value = "http://order-service:5005"
        }
      ]
      portMappings = [
        {
          containerPort = 5000
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
      image = "${var.product_image}:${var.image_tag}"
      environment = [
        {
          name  = "PORT"
          value = "5002"
        },
        {
          name  = "DATABASE_URL"
          valueFrom = var.database_url_parameter_arn
        },
        {
          name  = "REDIS_URL"
          valueFrom = var.redis_url_parameter_arn
        }
      ]
      portMappings = [
        {
          containerPort = 5002
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
      image = "${var.payment_image}:${var.image_tag}"
      environment = [
        {
          name  = "PORT"
          value = "5004"
        },
        {
          name  = "SPRING_DATASOURCE_URL"
          valueFrom = var.database_url_parameter_arn
        },
        {
          name  = "SPRING_DATA_REDIS_HOST"
          value = "redis"
        },
        {
          name  = "SPRING_DATA_REDIS_PORT"
          value = "6379"
        }
      ]
      portMappings = [
        {
          containerPort = 5004
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
      image = "${var.auth_image}:${var.image_tag}"
      environment = [
        {
          name  = "PORT"
          value = "5001"
        },
        {
          name  = "DATABASE_URL"
          valueFrom = var.database_url_parameter_arn
        },
        {
          name  = "JWT_SECRET_KEY"
          valueFrom = var.jwt_secret_parameter_arn
        }
      ]
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

resource "aws_ecs_task_definition" "cart" {
  family                   = "${var.project_name}-${var.environment}-cart"
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  cpu                      = 256
  memory                   = 512
  execution_role_arn       = aws_iam_role.ecs_task_execution_role.arn

  container_definitions = jsonencode([
    {
      name  = "cart"
      image = "${var.cart_image}:${var.image_tag}"
      environment = [
        {
          name  = "PORT"
          value = "5003"
        },
        {
          name  = "DATABASE_URL"
          valueFrom = var.database_url_parameter_arn
        },
        {
          name  = "REDIS_URL"
          valueFrom = var.redis_url_parameter_arn
        }
      ]
      portMappings = [
        {
          containerPort = 5003
          protocol      = "tcp"
        }
      ]
      logConfiguration = {
        logDriver = "awslogs"
        options = {
          "awslogs-group"         = aws_cloudwatch_log_group.cart_service.name
          "awslogs-region"        = data.aws_region.current.name
          "awslogs-stream-prefix" = "ecs"
        }
      }
      essential = true
    }
  ])

  tags = merge(var.common_tags, {
    Name = "${var.project_name}-${var.environment}-cart-task"
  })
}

resource "aws_ecs_task_definition" "order" {
  family                   = "${var.project_name}-${var.environment}-order"
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  cpu                      = 256
  memory                   = 512
  execution_role_arn       = aws_iam_role.ecs_task_execution_role.arn

  container_definitions = jsonencode([
    {
      name  = "order"
      image = "${var.order_image}:${var.image_tag}"
      environment = [
        {
          name  = "PORT"
          value = "5005"
        },
        {
          name  = "DATABASE_URL"
          valueFrom = var.database_url_parameter_arn
        },
        {
          name  = "JWT_SECRET_KEY"
          valueFrom = var.jwt_secret_parameter_arn
        },
        {
          name  = "CART_SERVICE_URL"
          value = "http://cart-service:5003"
        },
        {
          name  = "PAYMENT_SERVICE_URL"
          value = "http://payment-service:5004"
        }
      ]
      portMappings = [
        {
          containerPort = 5005
          protocol      = "tcp"
        }
      ]
      logConfiguration = {
        logDriver = "awslogs"
        options = {
          "awslogs-group"         = aws_cloudwatch_log_group.order_service.name
          "awslogs-region"        = data.aws_region.current.name
          "awslogs-stream-prefix" = "ecs"
        }
      }
      essential = true
    }
  ])

  tags = merge(var.common_tags, {
    Name = "${var.project_name}-${var.environment}-order-task"
  })
}

# Data source for current AWS region
data "aws_region" "current" {}

# ECS Services
resource "aws_ecs_service" "frontend" {
  name            = "${var.project_name}-${var.environment}-frontend"
  cluster         = aws_ecs_cluster.main.id
  task_definition = aws_ecs_task_definition.frontend.arn
  desired_count   = 1

  launch_type = "FARGATE"

  network_configuration {
    subnets         = var.private_subnet_ids
    security_groups = [var.ecs_service_security_group_id]
  }

  load_balancer {
    target_group_arn = aws_lb_target_group.frontend.arn
    container_name   = "frontend"
    container_port   = 3000
  }

  depends_on = [aws_lb_listener.main]

  tags = merge(var.common_tags, {
    Name    = "${var.project_name}-${var.environment}-frontend-service"
    Service = "frontend"
  })
}

resource "aws_ecs_service" "gateway" {
  name            = "${var.project_name}-${var.environment}-gateway"
  cluster         = aws_ecs_cluster.main.id
  task_definition = aws_ecs_task_definition.gateway.arn
  desired_count   = 1

  launch_type = "FARGATE"

  network_configuration {
    subnets         = var.private_subnet_ids
    security_groups = [var.ecs_service_security_group_id]
  }

  load_balancer {
    target_group_arn = aws_lb_target_group.gateway.arn
    container_name   = "gateway"
    container_port   = 3001
  }

  depends_on = [aws_lb_listener.main]

  tags = merge(var.common_tags, {
    Name    = "${var.project_name}-${var.environment}-gateway-service"
    Service = "gateway"
  })
}

resource "aws_ecs_service" "product" {
  name            = "${var.project_name}-${var.environment}-product"
  cluster         = aws_ecs_cluster.main.id
  task_definition = aws_ecs_task_definition.product.arn
  desired_count   = 1

  launch_type = "FARGATE"

  network_configuration {
    subnets         = var.private_subnet_ids
    security_groups = [var.ecs_service_security_group_id]
  }

  load_balancer {
    target_group_arn = aws_lb_target_group.product.arn
    container_name   = "product"
    container_port   = 8082
  }

  depends_on = [aws_lb_listener.main]

  tags = merge(var.common_tags, {
    Name    = "${var.project_name}-${var.environment}-product-service"
    Service = "product"
  })
}

resource "aws_ecs_service" "payment" {
  name            = "${var.project_name}-${var.environment}-payment"
  cluster         = aws_ecs_cluster.main.id
  task_definition = aws_ecs_task_definition.payment.arn
  desired_count   = 1

  launch_type = "FARGATE"

  network_configuration {
    subnets         = var.private_subnet_ids
    security_groups = [var.ecs_service_security_group_id]
  }

  load_balancer {
    target_group_arn = aws_lb_target_group.payment.arn
    container_name   = "payment"
    container_port   = 8080
  }

  depends_on = [aws_lb_listener.main]

  tags = merge(var.common_tags, {
    Name    = "${var.project_name}-${var.environment}-payment-service"
    Service = "payment"
  })
}

resource "aws_ecs_service" "auth" {
  name            = "${var.project_name}-${var.environment}-auth"
  cluster         = aws_ecs_cluster.main.id
  task_definition = aws_ecs_task_definition.auth.arn
  desired_count   = 1

  launch_type = "FARGATE"

  network_configuration {
    subnets         = var.private_subnet_ids
    security_groups = [var.ecs_service_security_group_id]
  }

  load_balancer {
    target_group_arn = aws_lb_target_group.auth.arn
    container_name   = "auth"
    container_port   = 5001
  }

  depends_on = [aws_lb_listener.main]

  tags = merge(var.common_tags, {
    Name    = "${var.project_name}-${var.environment}-auth-service"
    Service = "auth"
  })
}

resource "aws_ecs_service" "cart" {
  name            = "${var.project_name}-${var.environment}-cart"
  cluster         = aws_ecs_cluster.main.id
  task_definition = aws_ecs_task_definition.cart.arn
  desired_count   = 1

  launch_type = "FARGATE"

  network_configuration {
    subnets         = var.private_subnet_ids
    security_groups = [var.ecs_service_security_group_id]
  }

  load_balancer {
    target_group_arn = aws_lb_target_group.cart.arn
    container_name   = "cart"
    container_port   = 5003
  }

  depends_on = [aws_lb_listener.main]

  tags = merge(var.common_tags, {
    Name    = "${var.project_name}-${var.environment}-cart-service"
    Service = "cart"
  })
}

resource "aws_ecs_service" "order" {
  name            = "${var.project_name}-${var.environment}-order"
  cluster         = aws_ecs_cluster.main.id
  task_definition = aws_ecs_task_definition.order.arn
  desired_count   = 1

  launch_type = "FARGATE"

  network_configuration {
    subnets         = var.private_subnet_ids
    security_groups = [var.ecs_service_security_group_id]
  }

  load_balancer {
    target_group_arn = aws_lb_target_group.order.arn
    container_name   = "order"
    container_port   = 5005
  }

  depends_on = [aws_lb_listener.main]

  tags = merge(var.common_tags, {
    Name    = "${var.project_name}-${var.environment}-order-service"
    Service = "order"
  })
}
