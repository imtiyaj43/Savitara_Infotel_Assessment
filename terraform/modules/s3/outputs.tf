output "alb_logs_bucket_id" {
  description = "Name of the S3 bucket used for ALB access logs"
  value       = aws_s3_bucket.alb_logs.id
}

output "alb_logs_bucket_arn" {
  description = "ARN of the S3 bucket used for ALB access logs"
  value       = aws_s3_bucket.alb_logs.arn
}

output "app_storage_bucket_id" {
  description = "Name of the S3 bucket used for application storage"
  value       = aws_s3_bucket.app_storage.id
}

output "app_storage_bucket_arn" {
  description = "ARN of the S3 bucket used for application storage"
  value       = aws_s3_bucket.app_storage.arn
}
