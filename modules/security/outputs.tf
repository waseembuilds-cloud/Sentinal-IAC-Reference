output "kms_key_arn" {
  description = "Customer-managed KMS key ARN."
  value       = aws_kms_key.this.arn
}

output "waf_web_acl_arn" {
  description = "Regional WAF web ACL ARN."
  value       = aws_wafv2_web_acl.this.arn
}

output "ecs_task_role_arn" {
  description = "ECS application task role ARN."
  value       = aws_iam_role.task.arn
}

output "ecs_execution_role_arn" {
  description = "ECS task execution role ARN."
  value       = aws_iam_role.execution.arn
}
