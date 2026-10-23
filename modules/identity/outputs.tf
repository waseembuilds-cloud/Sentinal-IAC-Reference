output "user_pool_id" {
  description = "Cognito user pool ID."
  value       = aws_cognito_user_pool.this.id
}

output "user_pool_arn" {
  description = "Cognito user pool ARN."
  value       = aws_cognito_user_pool.this.arn
}

output "app_client_id" {
  description = "Public Cognito application client ID."
  value       = aws_cognito_user_pool_client.application.id
}

output "issuer_url" {
  description = "OIDC issuer URL for application JWT validation."
  value       = aws_cognito_user_pool.this.endpoint
}
