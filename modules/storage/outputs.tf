output "bucket_id" {
  description = "Evidence bucket name."
  value       = aws_s3_bucket.evidence.id
}

output "bucket_arn" {
  description = "Evidence bucket ARN."
  value       = aws_s3_bucket.evidence.arn
}
