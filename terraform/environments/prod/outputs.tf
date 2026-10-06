output "vpc_id" {
  description = "ID of the VPC"
  value       = module.vpc.vpc_id
}

output "alb_dns_name" {
  description = "DNS name of the Application Load Balancer"
  value       = module.alb.alb_dns_name
}

output "application_url" {
  description = "HTTPS URL of the application"
  value       = "https://${module.alb.alb_dns_name}"
}

output "health_check_url" {
  description = "ALB health check endpoint URL"
  value       = "https://${module.alb.alb_dns_name}/health"
}

output "rds_endpoint" {
  description = "Connection endpoint for RDS MySQL"
  value       = module.rds.db_endpoint
}

output "secrets_manager_secret_name" {
  description = "Secrets Manager secret name"
  value       = module.secrets.secret_name
}

output "autoscaling_group_name" {
  description = "Name of the EC2 Auto Scaling Group"
  value       = module.asg.asg_name
}

output "alb_logs_bucket" {
  description = "S3 bucket for ALB access logs"
  value       = module.s3.alb_logs_bucket_id
}

output "app_storage_bucket" {
  description = "S3 bucket for application storage"
  value       = module.s3.app_storage_bucket_id
}

output "github_actions_role_arn" {
  description = "IAM Role ARN assumed by GitHub Actions via OIDC"
  value       = module.iam.github_actions_role_arn
}
