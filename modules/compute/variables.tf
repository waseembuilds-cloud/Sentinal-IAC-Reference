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

variable "alb_listener_port" {
  description = "HTTP listener port on the ALB."
  type        = number
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
}

variable "database_max_allocated_storage" {
  description = "Maximum autoscaled database storage in GiB."
  type        = number
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

variable "database_password_length" {
  description = "Length of the generated database password."
  type        = number
}

variable "database_password_special_characters" {
  description = "Special characters allowed in the generated database password."
  type        = string
}

variable "database_secret_name" {
  description = "Secrets Manager name for the database credentials."
  type        = string
}

variable "database_secret_description" {
  description = "Description for the database credentials secret."
  type        = string
}

variable "database_secret_environment_name" {
  description = "Container environment variable name receiving the secret JSON."
  type        = string
}

variable "secret_recovery_window_days" {
  description = "Secrets Manager recovery window in days."
  type        = number
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
