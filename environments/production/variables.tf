variable "aws_region" {
  description = "AWS region for the production environment."
  type        = string
}

variable "project_name" {
  description = "Short lowercase project prefix used in resource names."
  type        = string
}

variable "environment" {
  description = "Environment identifier."
  type        = string
}

variable "evidence_bucket_name" {
  description = "Globally unique evidence bucket name."
  type        = string
}

variable "networking" {
  description = "VPC and subnet configuration."
  type = object({
    vpc_cidr             = string
    public_subnet_cidrs  = list(string)
    private_subnet_cidrs = list(string)
    nat_gateway_count    = number
  })
}

variable "security" {
  description = "KMS and WAF configuration."
  type = object({
    kms_deletion_window_days = number
    waf_rate_limit           = number
  })
}

variable "compute" {
  description = "Application, load balancer, and database configuration."
  type = object({
    alb_listener_port                 = number
    alb_ingress_cidrs                 = list(string)
    container_name                    = string
    container_image                   = string
    container_port                    = number
    health_check_path                 = string
    health_check_matcher              = string
    health_check_interval             = number
    health_check_healthy_threshold    = number
    health_check_unhealthy_threshold  = number
    health_check_timeout              = number
    database_identifier               = string
    database_name                     = string
    database_username                 = string
    database_port                     = number
    database_engine_version           = string
    database_instance_class           = string
    database_allocated_storage        = number
    database_max_allocated_storage    = number
    database_multi_az                 = bool
    database_backup_retention_days    = number
    database_deletion_protection      = bool
    database_skip_final_snapshot      = bool
    database_apply_immediately        = bool
    database_password_length          = number
    database_password_special_chars   = string
    database_secret_name              = string
    database_secret_recovery_days     = number
    task_cpu                          = number
    task_memory                       = number
    desired_count                     = number
    application_environment           = map(string)
    log_retention_days                = number
    force_destroy_evidence_bucket     = bool
  })
}
