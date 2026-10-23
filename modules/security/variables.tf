variable "name" {
  description = "Prefix used for security resource names."
  type        = string
}

variable "kms_description" {
  description = "Description for the customer-managed data encryption key."
  type        = string
}

variable "kms_deletion_window_days" {
  description = "Waiting period before a scheduled KMS key deletion."
  type        = number
}

variable "waf_description" {
  description = "Description for the regional WAF web ACL."
  type        = string
}

variable "waf_rate_limit" {
  description = "Maximum requests per five-minute period per source IP before blocking."
  type        = number
}

variable "waf_log_retention_days" {
  description = "CloudWatch retention period for WAF request logs."
  type        = number
}

variable "evidence_bucket_name" {
  description = "Name of the evidence bucket granted to the application task role."
  type        = string
}

variable "tags" {
  description = "Tags applied to security resources."
  type        = map(string)
}
