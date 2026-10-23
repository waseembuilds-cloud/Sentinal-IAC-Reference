variable "bucket_name" {
  description = "Globally unique S3 bucket name for evidence."
  type        = string
}

variable "kms_key_arn" {
  description = "KMS key ARN used for default bucket encryption."
  type        = string
}

variable "force_destroy" {
  description = "Allow Terraform to delete a non-empty bucket; keep false for production."
  type        = bool
}

variable "tags" {
  description = "Tags applied to storage resources."
  type        = map(string)
}
