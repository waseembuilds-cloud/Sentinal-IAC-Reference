variable "aws_region" {
  description = "AWS region for the staging environment."
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
  validation {
    condition = (
      var.networking.nat_gateway_count == 1 &&
      length(var.networking.public_subnet_cidrs) == 2 &&
      length(var.networking.private_subnet_cidrs) == 2 &&
      length(distinct(concat(var.networking.public_subnet_cidrs, var.networking.private_subnet_cidrs))) == 4 &&
      can(cidrhost(var.networking.vpc_cidr, 0)) && alltrue([
        for cidr in concat(var.networking.public_subnet_cidrs, var.networking.private_subnet_cidrs) :
        can(cidrhost(cidr, 0)) ? (
          can(cidrcontains(var.networking.vpc_cidr, cidrhost(cidr, 0))) ?
          cidrcontains(var.networking.vpc_cidr, cidrhost(cidr, 0)) : false
        ) : false
        ]) && alltrue([
        for i, cidr in concat(var.networking.public_subnet_cidrs, var.networking.private_subnet_cidrs) :
        alltrue([
          for j, other in concat(var.networking.public_subnet_cidrs, var.networking.private_subnet_cidrs) :
          i == j || (
            can(cidrhost(cidr, 0)) && can(cidrhost(other, 0)) &&
            can(cidrcontains(cidr, cidrhost(other, 0))) &&
            can(cidrcontains(other, cidrhost(cidr, 0))) ?
            (!cidrcontains(cidr, cidrhost(other, 0)) && !cidrcontains(other, cidrhost(cidr, 0))) : false
          )
        ])
      ])
    )
    error_message = "Staging requires one NAT gateway, four unique valid subnet CIDRs, and subnets contained in the VPC CIDR."
  }
}

variable "security" {
  description = "KMS and WAF configuration."
  type = object({
    kms_deletion_window_days = number
    waf_rate_limit           = number
    waf_log_retention_days   = number
  })
}

variable "identity" {
  description = "Cognito user pool and token policy configuration."
  type = object({
    deletion_protection              = bool
    mfa_configuration                = string
    password_minimum_length          = number
    temporary_password_validity_days = number
    access_token_validity_minutes    = number
    id_token_validity_minutes        = number
    refresh_token_validity_days      = number
  })
}

variable "compute" {
  description = "Application, load balancer, and database configuration."
  type = object({
    alb_listener_port                           = number
    alb_https_port                              = number
    acm_certificate_arn                         = string
    application_domain_name                     = string
    alb_ssl_policy                              = string
    alb_ingress_cidrs                           = list(string)
    container_name                              = string
    container_image                             = string
    container_port                              = number
    health_check_path                           = string
    health_check_matcher                        = string
    health_check_interval                       = number
    health_check_healthy_threshold              = number
    health_check_unhealthy_threshold            = number
    health_check_timeout                        = number
    health_check_grace_period_seconds           = number
    database_identifier                         = string
    database_name                               = string
    database_username                           = string
    database_port                               = number
    database_engine_version                     = string
    database_instance_class                     = string
    database_allocated_storage                  = number
    database_max_allocated_storage              = number
    database_multi_az                           = bool
    database_backup_retention_days              = number
    database_deletion_protection                = bool
    database_skip_final_snapshot                = bool
    database_apply_immediately                  = bool
    task_cpu                                    = number
    task_memory                                 = number
    desired_count                               = number
    minimum_task_count                          = number
    maximum_task_count                          = number
    target_cpu_utilization                      = number
    target_memory_utilization                   = number
    scale_in_cooldown_seconds                   = number
    scale_out_cooldown_seconds                  = number
    alarm_sns_topic_arn                         = string
    alb_5xx_alarm_threshold                     = number
    database_cpu_alarm_threshold                = number
    database_free_storage_alarm_threshold_bytes = number
    application_environment                     = map(string)
    log_retention_days                          = number
    force_destroy_evidence_bucket               = bool
  })
  validation {
    condition = (
      var.compute.minimum_task_count >= 1 &&
      var.compute.minimum_task_count <= var.compute.desired_count &&
      var.compute.desired_count <= var.compute.maximum_task_count &&
      can(regex("^[A-Za-z0-9.-]+$", var.compute.application_domain_name)) &&
      length(var.compute.application_domain_name) > 0 &&
      var.compute.alb_listener_port != var.compute.alb_https_port &&
      length(var.compute.alb_ingress_cidrs) > 0 &&
      alltrue([for cidr in var.compute.alb_ingress_cidrs : can(cidrhost(cidr, 0))])
    )
    error_message = "Staging task capacity must satisfy min <= desired <= max, and HTTP and HTTPS ports must differ."
  }
}
