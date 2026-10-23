terraform {
  required_version = ">= 1.10.0"
  backend "s3" {}

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = var.aws_region
  default_tags {
    tags = local.tags
  }
}

locals {
  name = "${var.project_name}-${var.environment}"
  tags = {
    Project     = var.project_name
    Environment = var.environment
    ManagedBy   = "Terraform"
  }
}

module "networking" {
  source               = "../../modules/networking"
  name                 = local.name
  vpc_cidr             = var.networking.vpc_cidr
  public_subnet_cidrs  = var.networking.public_subnet_cidrs
  private_subnet_cidrs = var.networking.private_subnet_cidrs
  nat_gateway_count    = var.networking.nat_gateway_count
  tags                 = local.tags
}

module "security" {
  source                   = "../../modules/security"
  name                     = local.name
  kms_description          = "${local.name} data encryption key"
  kms_deletion_window_days = var.security.kms_deletion_window_days
  waf_description          = "${local.name} regional web ACL"
  waf_rate_limit           = var.security.waf_rate_limit
  waf_log_retention_days   = var.security.waf_log_retention_days
  evidence_bucket_name     = var.evidence_bucket_name
  tags                     = local.tags
}

module "identity" {
  source                           = "../../modules/identity"
  user_pool_name                   = "${local.name}-users"
  app_client_name                  = "${local.name}-application"
  deletion_protection              = var.identity.deletion_protection
  mfa_configuration                = var.identity.mfa_configuration
  password_minimum_length          = var.identity.password_minimum_length
  temporary_password_validity_days = var.identity.temporary_password_validity_days
  access_token_validity_minutes    = var.identity.access_token_validity_minutes
  id_token_validity_minutes        = var.identity.id_token_validity_minutes
  refresh_token_validity_days      = var.identity.refresh_token_validity_days
  tags                             = local.tags
}

module "storage" {
  source        = "../../modules/storage"
  bucket_name   = var.evidence_bucket_name
  kms_key_arn   = module.security.kms_key_arn
  force_destroy = var.compute.force_destroy_evidence_bucket
  tags          = local.tags
}

module "compute" {
  source                                      = "../../modules/compute"
  name                                        = local.name
  vpc_id                                      = module.networking.vpc_id
  public_subnet_ids                           = module.networking.public_subnet_ids
  private_subnet_ids                          = module.networking.private_subnet_ids
  kms_key_arn                                 = module.security.kms_key_arn
  waf_web_acl_arn                             = module.security.waf_web_acl_arn
  ecs_task_role_arn                           = module.security.ecs_task_role_arn
  ecs_execution_role_arn                      = module.security.ecs_execution_role_arn
  ecs_execution_role_name                     = module.security.ecs_execution_role_name
  alb_listener_port                           = var.compute.alb_listener_port
  alb_https_port                              = var.compute.alb_https_port
  acm_certificate_arn                         = var.compute.acm_certificate_arn
  alb_ssl_policy                              = var.compute.alb_ssl_policy
  alb_ingress_cidrs                           = var.compute.alb_ingress_cidrs
  container_name                              = var.compute.container_name
  container_image                             = var.compute.container_image
  container_port                              = var.compute.container_port
  health_check_path                           = var.compute.health_check_path
  health_check_matcher                        = var.compute.health_check_matcher
  health_check_interval                       = var.compute.health_check_interval
  health_check_healthy_threshold              = var.compute.health_check_healthy_threshold
  health_check_unhealthy_threshold            = var.compute.health_check_unhealthy_threshold
  health_check_timeout                        = var.compute.health_check_timeout
  health_check_grace_period_seconds           = var.compute.health_check_grace_period_seconds
  database_identifier                         = var.compute.database_identifier
  database_name                               = var.compute.database_name
  database_username                           = var.compute.database_username
  database_port                               = var.compute.database_port
  database_engine_version                     = var.compute.database_engine_version
  database_instance_class                     = var.compute.database_instance_class
  database_allocated_storage                  = var.compute.database_allocated_storage
  database_max_allocated_storage              = var.compute.database_max_allocated_storage
  database_multi_az                           = var.compute.database_multi_az
  database_backup_retention_days              = var.compute.database_backup_retention_days
  database_deletion_protection                = var.compute.database_deletion_protection
  database_skip_final_snapshot                = var.compute.database_skip_final_snapshot
  database_apply_immediately                  = var.compute.database_apply_immediately
  database_secret_environment_name            = "DATABASE_PASSWORD"
  task_cpu                                    = var.compute.task_cpu
  task_memory                                 = var.compute.task_memory
  desired_count                               = var.compute.desired_count
  minimum_task_count                          = var.compute.minimum_task_count
  maximum_task_count                          = var.compute.maximum_task_count
  target_cpu_utilization                      = var.compute.target_cpu_utilization
  target_memory_utilization                   = var.compute.target_memory_utilization
  scale_in_cooldown_seconds                   = var.compute.scale_in_cooldown_seconds
  scale_out_cooldown_seconds                  = var.compute.scale_out_cooldown_seconds
  alarm_sns_topic_arn                         = var.compute.alarm_sns_topic_arn
  alb_5xx_alarm_threshold                     = var.compute.alb_5xx_alarm_threshold
  database_cpu_alarm_threshold                = var.compute.database_cpu_alarm_threshold
  database_free_storage_alarm_threshold_bytes = var.compute.database_free_storage_alarm_threshold_bytes
  application_environment                     = var.compute.application_environment
  log_retention_days                          = var.compute.log_retention_days
  tags                                        = local.tags
}

output "application_url" {
  description = "HTTPS hostname for the application; external DNS must point it to the ALB."
  value       = "https://${var.compute.application_domain_name}"
}

output "database_endpoint" {
  description = "Private PostgreSQL endpoint."
  value       = module.compute.database_endpoint
}

output "cognito_user_pool_id" {
  description = "Cognito user pool ID for application authentication configuration."
  value       = module.identity.user_pool_id
}

output "cognito_app_client_id" {
  description = "Public Cognito app client ID for application authentication configuration."
  value       = module.identity.app_client_id
}

output "cognito_issuer_url" {
  description = "OIDC issuer URL the application must use to validate JWTs."
  value       = module.identity.issuer_url
}
