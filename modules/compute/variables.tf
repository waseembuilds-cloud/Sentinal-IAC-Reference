variable "name" {
  description = "Short unique name prefix for load balancer and related resources."
  type        = string
}

variable "vpc_id" {
  description = "VPC ID for compute and database resources."
  type        = string
}

variable "public_subnet_ids" {
  description = "Public subnet IDs for the ALB."
  type        = list(string)
}

variable "private_subnet_ids" {
  description = "Private subnet IDs for ECS and RDS."
  type        = list(string)
}

variable "kms_key_arn" {
  description = "Customer-managed KMS key ARN."
  type        = string
}

variable "waf_web_acl_arn" {
  description = "Regional WAF web ACL ARN to associate with the ALB."
  type        = string
}

variable "ecs_task_role_arn" {
  description = "Application task role ARN."
  type        = string
}

variable "ecs_execution_role_arn" {
  description = "Task execution role ARN."
  type        = string
}

variable "ecs_execution_role_name" {
  description = "Task execution role name for attaching the database-secret permission."
  type        = string
}

variable "alb_listener_port" {
  description = "HTTP listener port that redirects to HTTPS."
  type        = number
}

variable "alb_https_port" {
  description = "HTTPS listener port on the ALB."
  type        = number
}

variable "acm_certificate_arn" {
  description = "ACM certificate ARN in the same region as the ALB."
  type        = string
  validation {
    condition     = can(regex("^arn:[^:]+:acm:[^:]+:[0-9]{12}:certificate/[0-9a-fA-F-]+$", var.acm_certificate_arn))
    error_message = "acm_certificate_arn must be an ACM certificate ARN in the ALB region."
  }
}

variable "alb_ssl_policy" {
  description = "TLS security policy used by the HTTPS listener."
  type        = string
}

variable "alb_ingress_cidrs" {
  description = "IPv4 source ranges permitted to reach the ALB listener."
  type        = list(string)
}

variable "container_name" {
  description = "ECS application container name."
  type        = string
}

variable "container_image" {
  description = "Container image URI including tag or digest."
  type        = string
}

variable "container_port" {
  description = "Application container/listener port."
  type        = number
}

variable "health_check_path" {
  description = "HTTP path used by the ALB target health check."
  type        = string
}

variable "health_check_matcher" {
  description = "Accepted HTTP status codes for ALB health checks."
  type        = string
}

variable "health_check_interval" {
  description = "Seconds between ALB health checks."
  type        = number
}

variable "health_check_healthy_threshold" {
  description = "Consecutive successes required to mark a target healthy."
  type        = number
}

variable "health_check_unhealthy_threshold" {
  description = "Consecutive failures required to mark a target unhealthy."
  type        = number
}

variable "health_check_timeout" {
  description = "Health check timeout in seconds."
  type        = number
}

variable "health_check_grace_period_seconds" {
  description = "Seconds ECS waits before evaluating failed health checks on a new task."
  type        = number
}

variable "database_identifier" {
  description = "Unique RDS DB instance identifier."
  type        = string
}

variable "database_name" {
  description = "Initial PostgreSQL database name."
  type        = string
}

variable "database_username" {
  description = "Initial PostgreSQL master username."
  type        = string
}

variable "database_port" {
  description = "PostgreSQL port."
  type        = number
}

variable "database_engine_version" {
  description = "PostgreSQL engine version supported in the target region."
  type        = string
}

variable "database_instance_class" {
  description = "RDS instance class."
  type        = string
}

variable "database_allocated_storage" {
  description = "Initial database storage in GiB."
  type        = number
  validation {
    condition     = var.database_allocated_storage >= 20
    error_message = "PostgreSQL allocated storage must be at least 20 GiB."
  }
}

variable "database_max_allocated_storage" {
  description = "Maximum autoscaled database storage in GiB."
  type        = number
  validation {
    condition     = var.database_max_allocated_storage >= var.database_allocated_storage
    error_message = "Maximum allocated storage must be greater than or equal to initial storage."
  }
}

variable "database_multi_az" {
  description = "Enable Multi-AZ RDS deployment."
  type        = bool
}

variable "database_backup_retention_days" {
  description = "Automated database backup retention in days."
  type        = number
}

variable "database_deletion_protection" {
  description = "Protect the RDS instance from deletion."
  type        = bool
}

variable "database_skip_final_snapshot" {
  description = "Skip the final RDS snapshot on destroy; keep false for production."
  type        = bool
}

variable "database_apply_immediately" {
  description = "Apply RDS modifications immediately rather than in the maintenance window."
  type        = bool
}

variable "database_secret_environment_name" {
  description = "Container environment variable name receiving the RDS-managed password."
  type        = string
}

variable "task_cpu" {
  description = "Fargate task CPU units."
  type        = number
}

variable "task_memory" {
  description = "Fargate task memory in MiB."
  type        = number
}

variable "desired_count" {
  description = "Desired number of running ECS tasks."
  type        = number
}

variable "minimum_task_count" {
  description = "Minimum ECS service task count for autoscaling."
  type        = number
}

variable "maximum_task_count" {
  description = "Maximum ECS service task count for autoscaling."
  type        = number
}

variable "target_cpu_utilization" {
  description = "Target average ECS service CPU utilization percentage."
  type        = number
  validation {
    condition     = var.target_cpu_utilization > 0 && var.target_cpu_utilization <= 100
    error_message = "target_cpu_utilization must be greater than 0 and at most 100."
  }
}

variable "target_memory_utilization" {
  description = "Target average ECS service memory utilization percentage."
  type        = number
  validation {
    condition     = var.target_memory_utilization > 0 && var.target_memory_utilization <= 100
    error_message = "target_memory_utilization must be greater than 0 and at most 100."
  }
}

variable "scale_in_cooldown_seconds" {
  description = "Scale-in cooldown for ECS target tracking."
  type        = number
}

variable "scale_out_cooldown_seconds" {
  description = "Scale-out cooldown for ECS target tracking."
  type        = number
}

variable "alarm_sns_topic_arn" {
  description = "Optional pre-created SNS topic ARN for alarm notifications."
  type        = string
}

variable "alb_5xx_alarm_threshold" {
  description = "ALB target 5xx count threshold per evaluation period."
  type        = number
}

variable "database_cpu_alarm_threshold" {
  description = "RDS CPU utilization alarm threshold percentage."
  type        = number
}

variable "database_free_storage_alarm_threshold_bytes" {
  description = "RDS free storage alarm threshold in bytes."
  type        = number
}

variable "application_environment" {
  description = "Non-secret environment variables passed to the application."
  type        = map(string)
}

variable "log_retention_days" {
  description = "CloudWatch log retention period in days."
  type        = number
}

variable "tags" {
  description = "Tags applied to compute resources."
  type        = map(string)
}
