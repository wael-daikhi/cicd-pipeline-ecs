# ─── Define the two environments once; for_each builds both ──────
locals {
  environments = {
    staging    = { listener_port = 80, desired_count = 1 }
    production = { listener_port = 8080, desired_count = 1 }
  }
}

# ─── Shared: ECR repository ──────────────────────────────────────
resource "aws_ecr_repository" "app" {
  name         = var.app_name
  force_delete = true
  image_scanning_configuration {
    scan_on_push = true
  }
}

# ─── Shared: default VPC lookup (custom VPC comes in I5) ─────────
data "aws_vpc" "default" {
  default = true
}

data "aws_subnets" "default" {
  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.default.id]
  }
}

# ─── Shared: security groups (ALB open; tasks only from ALB) ─────
resource "aws_security_group" "alb" {
  name   = "${var.app_name}-alb-sg"
  vpc_id = data.aws_vpc.default.id

  dynamic "ingress" {
    for_each = local.environments
    content {
      from_port   = ingress.value.listener_port
      to_port     = ingress.value.listener_port
      protocol    = "tcp"
      cidr_blocks = ["0.0.0.0/0"]
    }
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_security_group" "tasks" {
  name   = "${var.app_name}-tasks-sg"
  vpc_id = data.aws_vpc.default.id

  ingress {
    from_port       = var.container_port
    to_port         = var.container_port
    protocol        = "tcp"
    security_groups = [aws_security_group.alb.id]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# ─── Shared: ECS cluster + ALB ───────────────────────────────────
resource "aws_ecs_cluster" "main" {
  name = "${var.app_name}-cluster"
}

resource "aws_lb" "app" {
  name               = "${var.app_name}-alb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.alb.id]
  subnets            = data.aws_subnets.default.ids
}

# ─── Per-environment: log group, target group, listener ─────────
resource "aws_cloudwatch_log_group" "env" {
  for_each          = local.environments
  name              = "/ecs/${var.app_name}-${each.key}"
  retention_in_days = 7
}

resource "aws_lb_target_group" "env" {
  for_each    = local.environments
  name        = "${var.app_name}-${each.key}-tg"
  port        = var.container_port
  protocol    = "HTTP"
  vpc_id      = data.aws_vpc.default.id
  target_type = "ip"

  health_check {
    path                = "/health"
    healthy_threshold   = 2
    unhealthy_threshold = 3
    interval            = 30
    matcher             = "200"
  }
}

resource "aws_lb_listener" "env" {
  for_each          = local.environments
  load_balancer_arn = aws_lb.app.arn
  port              = each.value.listener_port
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.env[each.key].arn
  }
}

# ─── Per-environment: bootstrap task definition ──────────────────
# The pipeline registers NEW revisions of this; Terraform only seeds it.
resource "aws_ecs_task_definition" "env" {
  for_each                 = local.environments
  family                   = "${var.app_name}-${each.key}"
  requires_compatibilities = ["FARGATE"]
  network_mode             = "awsvpc"
  cpu                      = 256
  memory                   = 512
  execution_role_arn       = aws_iam_role.execution.arn
  task_role_arn            = aws_iam_role.task.arn

  container_definitions = jsonencode([
    {
      name         = "app" # MUST match container-name in the workflow
      image        = "${aws_ecr_repository.app.repository_url}:latest"
      essential    = true
      portMappings = [{ containerPort = var.container_port, protocol = "tcp" }]
      environment = [
        { name = "APP_VERSION", value = "bootstrap" },
        { name = "PORT", value = tostring(var.container_port) }
      ]
      logConfiguration = {
        logDriver = "awslogs"
        options = {
          "awslogs-group"         = aws_cloudwatch_log_group.env[each.key].name
          "awslogs-region"        = var.aws_region
          "awslogs-stream-prefix" = "ecs"
        }
      }
    }
  ])
}

# ─── Per-environment: ECS service ────────────────────────────────
resource "aws_ecs_service" "env" {
  for_each        = local.environments
  name            = "${var.app_name}-${each.key}"
  cluster         = aws_ecs_cluster.main.id
  task_definition = aws_ecs_task_definition.env[each.key].arn
  desired_count   = each.value.desired_count
  launch_type     = "FARGATE"

  network_configuration {
    subnets          = data.aws_subnets.default.ids
    security_groups  = [aws_security_group.tasks.id]
    assign_public_ip = true
  }

  load_balancer {
    target_group_arn = aws_lb_target_group.env[each.key].arn
    container_name   = "app"
    container_port   = var.container_port
  }

  # ⚠️ THE CRITICAL LINE — see explanation below
  lifecycle {
    ignore_changes = [task_definition, desired_count]
  }

  depends_on = [aws_lb_listener.env]
}