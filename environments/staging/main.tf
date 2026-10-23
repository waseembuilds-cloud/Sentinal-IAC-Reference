terraform {
  required_version = ">= 1.10.0"
  backend "s3" {}

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.6"
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
  waf_description         = "${local.name} regional web ACL"
  waf_rate_limit           = var.security.waf_rate_limit
  evidence_bucket_name     = var.evidence_bucket_name
  database_secret_name     = var.compute.database_secret_name
  tags                     = local.tags
}

module "storage" {
  source        = "../../modules/storage"
  bucket_name   = var.evidence_bucket_name
  kms_key_arn   = module.security.kms_key_arn
  force_destroy = var.compute.force_destroy_evidence_bucket
  tags          = local.tags
}

module "compute" {
  source                              = "../../modules/compute"
  name                                = local.name
  vpc_id                              = module.networking.vpc_id
  public_subnet_ids                   = module.networking.public_subnet_ids
  private_subnet_ids                  = module.networking.private_subnet_ids
  kms_key_arn                         = module.security.kms_key_arn
  waf_web_acl_arn                     = module.security.waf_web_acl_arn
  ecs_task_role_arn                   = module.security.ecs_task_role_arn
  ecs_execution_role_arn              = module.security.ecs_execution_role_arn
  alb_listener_port                   = var.compute.alb_listener_port
  alb_ingress_cidrs                   = var.compute.alb_ingress_cidrs
  container_name                      = var.compute.container_name
  container_image                     = var.compute.container_image
  container_port                      = var.compute.container_port
  health_check_path                   = var.compute.health_check_path
  health_check_matcher                = var.compute.health_check_matcher
  health_check_interval               = var.compute.health_check_interval
  health_check_healthy_threshold      = var.compute.health_check_healthy_threshold
  health_check_unhealthy_threshold    = var.compute.health_check_unhealthy_threshold
  health_check_timeout                = var.compute.health_check_timeout
  database_identifier                 = var.compute.database_identifier
  database_name                       = var.compute.database_name
  database_username                   = var.compute.database_username
  database_port                       = var.compute.database_port
  database_engine_version             = var.compute.database_engine_version
  database_instance_class             = var.compute.database_instance_class
  database_allocated_storage          = var.compute.database_allocated_storage
  database_max_allocated_storage      = var.compute.database_max_allocated_storage
  database_multi_az                   = var.compute.database_multi_az
  database_backup_retention_days      = var.compute.database_backup_retention_days
  database_deletion_protection        = var.compute.database_deletion_protection
  database_skip_final_snapshot        = var.compute.database_skip_final_snapshot
  database_apply_immediately          = var.compute.database_apply_immediately
  database_password_length            = var.compute.database_password_length
  database_password_special_characters = var.compute.database_password_special_chars
  database_secret_name                = var.compute.database_secret_name
  database_secret_description         = "${local.name} database credentials"
  database_secret_environment_name    = "DATABASE_CREDENTIALS"
  secret_recovery_window_days         = var.compute.database_secret_recovery_days
  task_cpu                            = var.compute.task_cpu
  task_memory                         = var.compute.task_memory
  desired_count                       = var.compute.desired_count
  application_environment             = var.compute.application_environment
  log_retention_days                  = var.compute.log_retention_days
  tags                                = local.tags
}

output "application_url" {
  description = "HTTP endpoint for the application."
  value       = "http://${module.compute.alb_dns_name}"
}

output "database_endpoint" {
  description = "Private PostgreSQL endpoint."
  value       = module.compute.database_endpoint
}
