resource "aws_cognito_user_pool" "this" {
  name                     = var.user_pool_name
  deletion_protection      = var.deletion_protection ? "ACTIVE" : "INACTIVE"
  username_attributes      = ["email"]
  auto_verified_attributes = ["email"]

  mfa_configuration = var.mfa_configuration

  software_token_mfa_configuration {
    enabled = true
  }

  password_policy {
    minimum_length                   = var.password_minimum_length
    require_lowercase                = true
    require_numbers                  = true
    require_symbols                  = true
    require_uppercase                = true
    temporary_password_validity_days = var.temporary_password_validity_days
  }

  account_recovery_setting {
    recovery_mechanism {
      name     = "verified_email"
      priority = 1
    }
  }

  user_pool_tier = "ESSENTIALS"
  tags           = var.tags
}

resource "aws_cognito_user_pool_client" "application" {
  name                          = var.app_client_name
  user_pool_id                  = aws_cognito_user_pool.this.id
  generate_secret               = false
  prevent_user_existence_errors = "ENABLED"
  enable_token_revocation       = true
  explicit_auth_flows           = ["ALLOW_USER_SRP_AUTH", "ALLOW_REFRESH_TOKEN_AUTH"]
  access_token_validity         = var.access_token_validity_minutes
  id_token_validity             = var.id_token_validity_minutes
  refresh_token_validity        = var.refresh_token_validity_days
  supported_identity_providers  = ["COGNITO"]
  read_attributes               = ["email", "email_verified"]
  write_attributes              = ["email"]

  token_validity_units {
    access_token  = "minutes"
    id_token      = "minutes"
    refresh_token = "days"
  }
}
