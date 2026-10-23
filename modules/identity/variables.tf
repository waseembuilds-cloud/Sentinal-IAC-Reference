variable "user_pool_name" {
  description = "Cognito user pool name."
  type        = string
}

variable "app_client_name" {
  description = "Public Cognito application client name."
  type        = string
}

variable "deletion_protection" {
  description = "Enable Cognito user pool deletion protection."
  type        = bool
}

variable "mfa_configuration" {
  description = "Cognito MFA mode: OFF, OPTIONAL, or ON."
  type        = string
  validation {
    condition     = contains(["OFF", "OPTIONAL", "ON"], var.mfa_configuration)
    error_message = "mfa_configuration must be OFF, OPTIONAL, or ON."
  }
}

variable "password_minimum_length" {
  description = "Minimum Cognito password length."
  type        = number
}

variable "temporary_password_validity_days" {
  description = "Validity period for temporary user passwords."
  type        = number
}

variable "access_token_validity_minutes" {
  description = "Cognito access token lifetime in minutes."
  type        = number
}

variable "id_token_validity_minutes" {
  description = "Cognito ID token lifetime in minutes."
  type        = number
}

variable "refresh_token_validity_days" {
  description = "Cognito refresh token lifetime in days."
  type        = number
}

variable "tags" {
  description = "Tags applied to identity resources."
  type        = map(string)
}
