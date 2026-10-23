data "aws_region" "current" {}

resource "aws_security_group" "alb" {
  name        = "${var.name}-alb"
  description = "Internet ingress to the application load balancer."
  vpc_id      = var.vpc_id

  tags = merge(var.tags, { Name = "${var.name}-alb" })
}

resource "aws_security_group" "application" {
  name        = "${var.name}-application"
  description = "Application traffic from the ALB only."
  vpc_id      = var.vpc_id

  tags = merge(var.tags, { Name = "${var.name}-application" })
}

resource "aws_security_group" "database" {
  name        = "${var.name}-database"
  description = "PostgreSQL ingress from application tasks only."
  vpc_id      = var.vpc_id

  tags = merge(var.tags, { Name = "${var.name}-database" })
}

resource "aws_vpc_security_group_ingress_rule" "alb_http" {
  security_group_id = aws_security_group.alb.id
  description       = "Configured client HTTP ingress."
  ip_protocol       = "tcp"
  from_port         = var.alb_listener_port
  to_port           = var.alb_listener_port
  for_each          = toset(var.alb_ingress_cidrs)
  cidr_ipv4         = each.value
}

resource "aws_vpc_security_group_egress_rule" "alb_to_application" {
  security_group_id            = aws_security_group.alb.id
  description                  = "Forward application requests to ECS tasks."
  ip_protocol                  = "tcp"
  from_port                    = var.container_port
  to_port                      = var.container_port
  referenced_security_group_id = aws_security_group.application.id
}

resource "aws_vpc_security_group_ingress_rule" "application_from_alb" {
  security_group_id            = aws_security_group.application.id
  description                  = "Application traffic from the ALB only."
  ip_protocol                  = "tcp"
  from_port                    = var.container_port
  to_port                      = var.container_port
  referenced_security_group_id = aws_security_group.alb.id
}

resource "aws_vpc_security_group_egress_rule" "application_https" {
  security_group_id = aws_security_group.application.id
  description       = "HTTPS egress for AWS APIs and image/log operations."
  ip_protocol       = "tcp"
  from_port         = 443
  to_port           = 443
  cidr_ipv4         = "0.0.0.0/0"
}

resource "aws_vpc_security_group_egress_rule" "application_database" {
  security_group_id            = aws_security_group.application.id
  description                  = "PostgreSQL traffic to the database."
  ip_protocol                  = "tcp"
  from_port                    = var.database_port
  to_port                      = var.database_port
  referenced_security_group_id = aws_security_group.database.id
}

resource "aws_vpc_security_group_ingress_rule" "database_from_application" {
  security_group_id            = aws_security_group.database.id
  description                  = "PostgreSQL ingress from application tasks only."
  ip_protocol                  = "tcp"
  from_port                    = var.database_port
  to_port                      = var.database_port
  referenced_security_group_id = aws_security_group.application.id
}

resource "aws_lb" "this" {
  name               = var.name
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.alb.id]
  subnets            = var.public_subnet_ids
  drop_invalid_header_fields = true

  tags = var.tags
}

resource "aws_lb_target_group" "application" {
  name        = "${var.name}-app"
  port        = var.container_port
  protocol    = "HTTP"
  target_type = "ip"
  vpc_id      = var.vpc_id

  health_check {
    enabled             = true
    path                = var.health_check_path
    protocol            = "HTTP"
    matcher             = var.health_check_matcher
    interval            = var.health_check_interval
    healthy_threshold   = var.health_check_healthy_threshold
    unhealthy_threshold = var.health_check_unhealthy_threshold
    timeout             = var.health_check_timeout
  }
  tags = var.tags
}

resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_lb.this.arn
  port              = var.alb_listener_port
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.application.arn
  }
}

resource "aws_wafv2_web_acl_association" "this" {
  resource_arn = aws_lb.this.arn
  web_acl_arn  = var.waf_web_acl_arn
}

resource "aws_db_subnet_group" "this" {
  name       = "${var.name}-database"
  subnet_ids = var.private_subnet_ids
  tags       = var.tags
}

resource "random_password" "database" {
  length           = var.database_password_length
  special          = true
  override_special = var.database_password_special_characters
}

resource "aws_db_instance" "this" {
  identifier                   = var.database_identifier
  engine                       = "postgres"
  engine_version               = var.database_engine_version
  instance_class               = var.database_instance_class
  allocated_storage            = var.database_allocated_storage
  max_allocated_storage        = var.database_max_allocated_storage
  storage_type                 = "gp3"
  storage_encrypted            = true
  kms_key_id                   = var.kms_key_arn
  db_name                      = var.database_name
  username                     = var.database_username
  password                     = random_password.database.result
  port                         = var.database_port
  db_subnet_group_name         = aws_db_subnet_group.this.name
  vpc_security_group_ids       = [aws_security_group.database.id]
  multi_az                     = var.database_multi_az
  publicly_accessible          = false
  backup_retention_period      = var.database_backup_retention_days
  deletion_protection          = var.database_deletion_protection
  skip_final_snapshot          = var.database_skip_final_snapshot
  final_snapshot_identifier    = var.database_skip_final_snapshot ? null : "${var.database_identifier}-final"
  auto_minor_version_upgrade   = true
  copy_tags_to_snapshot        = true
  apply_immediately            = var.database_apply_immediately

  tags = var.tags
}

resource "aws_secretsmanager_secret" "database" {
  name                    = var.database_secret_name
  description             = var.database_secret_description
  kms_key_id              = var.kms_key_arn
  recovery_window_in_days = var.secret_recovery_window_days
  tags                    = var.tags
}

resource "aws_secretsmanager_secret_version" "database" {
  secret_id = aws_secretsmanager_secret.database.id
  secret_string = jsonencode({
    username = var.database_username
    password = random_password.database.result
    host     = aws_db_instance.this.address
    port     = aws_db_instance.this.port
    dbname   = var.database_name
  })
}

resource "aws_cloudwatch_log_group" "application" {
  name              = "/ecs/${var.name}"
  retention_in_days = var.log_retention_days
  tags              = var.tags
}

resource "aws_ecs_cluster" "this" {
  name = "${var.name}-cluster"
  tags = var.tags
}

resource "aws_ecs_task_definition" "application" {
  family                   = "${var.name}-application"
  requires_compatibilities = ["FARGATE"]
  network_mode             = "awsvpc"
  cpu                      = var.task_cpu
  memory                   = var.task_memory
  execution_role_arn       = var.ecs_execution_role_arn
  task_role_arn            = var.ecs_task_role_arn

  container_definitions = jsonencode([
    {
      name      = var.container_name
      image     = var.container_image
      essential = true
      portMappings = [{
        containerPort = var.container_port
        hostPort      = var.container_port
        protocol      = "tcp"
      }]
      environment = [
        for name, value in var.application_environment : {
          name  = name
          value = value
        }
      ]
      secrets = [{
        name      = var.database_secret_environment_name
        valueFrom = aws_secretsmanager_secret.database.arn
      }]
      logConfiguration = {
        logDriver = "awslogs"
        options = {
          awslogs-group         = aws_cloudwatch_log_group.application.name
          awslogs-region        = data.aws_region.current.name
          awslogs-stream-prefix = var.container_name
        }
      }
    }
  ])
  tags       = var.tags
  depends_on = [aws_secretsmanager_secret_version.database]
}

resource "aws_ecs_service" "application" {
  name            = "${var.name}-service"
  cluster         = aws_ecs_cluster.this.id
  task_definition = aws_ecs_task_definition.application.arn
  desired_count   = var.desired_count
  launch_type     = "FARGATE"

  network_configuration {
    subnets          = var.private_subnet_ids
    security_groups  = [aws_security_group.application.id]
    assign_public_ip = false
  }

  load_balancer {
    target_group_arn = aws_lb_target_group.application.arn
    container_name   = var.container_name
    container_port   = var.container_port
  }

  depends_on = [aws_lb_listener.http, aws_wafv2_web_acl_association.this]
  tags       = var.tags
}
