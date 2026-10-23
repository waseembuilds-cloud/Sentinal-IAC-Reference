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

resource "aws_vpc_security_group_ingress_rule" "alb_https" {
  security_group_id = aws_security_group.alb.id
  description       = "Configured client HTTPS ingress."
  ip_protocol       = "tcp"
  from_port         = var.alb_https_port
  to_port           = var.alb_https_port
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
  name                       = var.name
  internal                   = false
  load_balancer_type         = "application"
  security_groups            = [aws_security_group.alb.id]
  subnets                    = var.public_subnet_ids
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
    type = "redirect"
    redirect {
      port        = tostring(var.alb_https_port)
      protocol    = "HTTPS"
      status_code = "HTTP_301"
    }
  }
}

resource "aws_lb_listener" "https" {
  load_balancer_arn = aws_lb.this.arn
  port              = var.alb_https_port
  protocol          = "HTTPS"
  certificate_arn   = var.acm_certificate_arn
  ssl_policy        = var.alb_ssl_policy

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

resource "aws_cloudwatch_log_group" "database" {
  for_each          = toset(["postgresql", "upgrade"])
  name              = "/aws/rds/instance/${var.database_identifier}/${each.value}"
  retention_in_days = var.log_retention_days
  kms_key_id        = var.kms_key_arn
  tags              = var.tags
}

resource "aws_db_instance" "this" {
  identifier                      = var.database_identifier
  engine                          = "postgres"
  engine_version                  = var.database_engine_version
  instance_class                  = var.database_instance_class
  allocated_storage               = var.database_allocated_storage
  max_allocated_storage           = var.database_max_allocated_storage
  storage_type                    = "gp3"
  storage_encrypted               = true
  kms_key_id                      = var.kms_key_arn
  db_name                         = var.database_name
  username                        = var.database_username
  manage_master_user_password     = true
  master_user_secret_kms_key_id   = var.kms_key_arn
  port                            = var.database_port
  db_subnet_group_name            = aws_db_subnet_group.this.name
  vpc_security_group_ids          = [aws_security_group.database.id]
  multi_az                        = var.database_multi_az
  publicly_accessible             = false
  backup_retention_period         = var.database_backup_retention_days
  deletion_protection             = var.database_deletion_protection
  skip_final_snapshot             = var.database_skip_final_snapshot
  final_snapshot_identifier       = var.database_skip_final_snapshot ? null : "${var.database_identifier}-final"
  auto_minor_version_upgrade      = true
  copy_tags_to_snapshot           = true
  apply_immediately               = var.database_apply_immediately
  enabled_cloudwatch_logs_exports = ["postgresql", "upgrade"]

  tags       = var.tags
  depends_on = [aws_cloudwatch_log_group.database]
}

data "aws_iam_policy_document" "execution_database_secret" {
  statement {
    sid       = "ReadRdsManagedMasterSecret"
    actions   = ["secretsmanager:GetSecretValue"]
    resources = [aws_db_instance.this.master_user_secret[0].secret_arn]
  }

  statement {
    sid       = "DecryptRdsManagedMasterSecret"
    actions   = ["kms:Decrypt"]
    resources = [var.kms_key_arn]
    condition {
      test     = "StringEquals"
      variable = "kms:ViaService"
      values   = ["secretsmanager.${data.aws_region.current.name}.${data.aws_partition.current.dns_suffix}"]
    }
  }
}

data "aws_partition" "current" {}

resource "aws_iam_role_policy" "execution_database_secret" {
  name   = "${var.name}-database-secret"
  role   = var.ecs_execution_role_name
  policy = data.aws_iam_policy_document.execution_database_secret.json
}

resource "aws_cloudwatch_log_group" "application" {
  name              = "/ecs/${var.name}"
  retention_in_days = var.log_retention_days
  tags              = var.tags
}

resource "aws_ecs_cluster" "this" {
  name = "${var.name}-cluster"
  setting {
    name  = "containerInsights"
    value = "enabled"
  }
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
      environment = concat([
        for name, value in var.application_environment : {
          name  = name
          value = value
        }
        ], [
        { name = "DATABASE_HOST", value = aws_db_instance.this.address },
        { name = "DATABASE_PORT", value = tostring(aws_db_instance.this.port) },
        { name = "DATABASE_NAME", value = var.database_name },
        { name = "DATABASE_USER", value = var.database_username }
      ])
      secrets = [{
        name      = var.database_secret_environment_name
        valueFrom = "${aws_db_instance.this.master_user_secret[0].secret_arn}:password::"
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
  depends_on = [aws_iam_role_policy.execution_database_secret]
}

resource "aws_ecs_service" "application" {
  name                              = "${var.name}-service"
  cluster                           = aws_ecs_cluster.this.id
  task_definition                   = aws_ecs_task_definition.application.arn
  desired_count                     = var.desired_count
  launch_type                       = "FARGATE"
  health_check_grace_period_seconds = var.health_check_grace_period_seconds
  deployment_circuit_breaker {
    enable   = true
    rollback = true
  }
  lifecycle {
    ignore_changes = [desired_count]
  }

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

  depends_on = [aws_lb_listener.http, aws_lb_listener.https, aws_wafv2_web_acl_association.this]
  tags       = var.tags
}

resource "aws_appautoscaling_target" "application" {
  max_capacity       = var.maximum_task_count
  min_capacity       = var.minimum_task_count
  resource_id        = "service/${aws_ecs_cluster.this.name}/${aws_ecs_service.application.name}"
  scalable_dimension = "ecs:service:DesiredCount"
  service_namespace  = "ecs"
}

resource "aws_appautoscaling_policy" "cpu" {
  name               = "${var.name}-cpu-target"
  policy_type        = "TargetTrackingScaling"
  resource_id        = aws_appautoscaling_target.application.resource_id
  scalable_dimension = aws_appautoscaling_target.application.scalable_dimension
  service_namespace  = aws_appautoscaling_target.application.service_namespace

  target_tracking_scaling_policy_configuration {
    target_value       = var.target_cpu_utilization
    scale_in_cooldown  = var.scale_in_cooldown_seconds
    scale_out_cooldown = var.scale_out_cooldown_seconds
    predefined_metric_specification {
      predefined_metric_type = "ECSServiceAverageCPUUtilization"
    }
  }
}

resource "aws_appautoscaling_policy" "memory" {
  name               = "${var.name}-memory-target"
  policy_type        = "TargetTrackingScaling"
  resource_id        = aws_appautoscaling_target.application.resource_id
  scalable_dimension = aws_appautoscaling_target.application.scalable_dimension
  service_namespace  = aws_appautoscaling_target.application.service_namespace

  target_tracking_scaling_policy_configuration {
    target_value       = var.target_memory_utilization
    scale_in_cooldown  = var.scale_in_cooldown_seconds
    scale_out_cooldown = var.scale_out_cooldown_seconds
    predefined_metric_specification {
      predefined_metric_type = "ECSServiceAverageMemoryUtilization"
    }
  }
}

resource "aws_cloudwatch_metric_alarm" "service_running_tasks" {
  alarm_name          = "${var.name}-running-tasks-low"
  alarm_description   = "ECS running task count is below the configured minimum."
  namespace           = "ECS/ContainerInsights"
  metric_name         = "RunningTaskCount"
  statistic           = "Minimum"
  period              = 300
  evaluation_periods  = 2
  threshold           = var.minimum_task_count
  comparison_operator = "LessThanThreshold"
  dimensions = {
    ClusterName = aws_ecs_cluster.this.name
    ServiceName = aws_ecs_service.application.name
  }
  alarm_actions = var.alarm_sns_topic_arn == "" ? [] : [var.alarm_sns_topic_arn]
  tags          = var.tags
}

resource "aws_cloudwatch_metric_alarm" "alb_5xx" {
  alarm_name          = "${var.name}-alb-5xx"
  alarm_description   = "ALB target 5xx responses exceed the configured threshold."
  namespace           = "AWS/ApplicationELB"
  metric_name         = "HTTPCode_Target_5XX_Count"
  statistic           = "Sum"
  period              = 300
  evaluation_periods  = 2
  threshold           = var.alb_5xx_alarm_threshold
  comparison_operator = "GreaterThanOrEqualToThreshold"
  dimensions = {
    LoadBalancer = aws_lb.this.arn_suffix
    TargetGroup  = aws_lb_target_group.application.arn_suffix
  }
  alarm_actions = var.alarm_sns_topic_arn == "" ? [] : [var.alarm_sns_topic_arn]
  tags          = var.tags
}

resource "aws_cloudwatch_metric_alarm" "database_cpu" {
  alarm_name          = "${var.name}-database-cpu-high"
  alarm_description   = "Database CPU utilization exceeds the configured threshold."
  namespace           = "AWS/RDS"
  metric_name         = "CPUUtilization"
  statistic           = "Average"
  period              = 300
  evaluation_periods  = 3
  threshold           = var.database_cpu_alarm_threshold
  comparison_operator = "GreaterThanOrEqualToThreshold"
  dimensions = {
    DBInstanceIdentifier = aws_db_instance.this.identifier
  }
  alarm_actions = var.alarm_sns_topic_arn == "" ? [] : [var.alarm_sns_topic_arn]
  tags          = var.tags
}

resource "aws_cloudwatch_metric_alarm" "database_free_storage" {
  alarm_name          = "${var.name}-database-free-storage-low"
  alarm_description   = "Database free storage is below the configured threshold."
  namespace           = "AWS/RDS"
  metric_name         = "FreeStorageSpace"
  statistic           = "Minimum"
  period              = 300
  evaluation_periods  = 2
  threshold           = var.database_free_storage_alarm_threshold_bytes
  comparison_operator = "LessThanThreshold"
  dimensions = {
    DBInstanceIdentifier = aws_db_instance.this.identifier
  }
  alarm_actions = var.alarm_sns_topic_arn == "" ? [] : [var.alarm_sns_topic_arn]
  tags          = var.tags
}

resource "aws_cloudwatch_metric_alarm" "unhealthy_targets" {
  alarm_name          = "${var.name}-unhealthy-targets"
  alarm_description   = "The application target group has unhealthy targets."
  namespace           = "AWS/ApplicationELB"
  metric_name         = "UnHealthyHostCount"
  statistic           = "Maximum"
  period              = 60
  evaluation_periods  = 2
  threshold           = 1
  comparison_operator = "GreaterThanOrEqualToThreshold"
  dimensions = {
    LoadBalancer = aws_lb.this.arn_suffix
    TargetGroup  = aws_lb_target_group.application.arn_suffix
  }
  alarm_actions = var.alarm_sns_topic_arn == "" ? [] : [var.alarm_sns_topic_arn]
  tags          = var.tags
}
