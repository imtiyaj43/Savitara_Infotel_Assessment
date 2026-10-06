output "alb_dns_name" {
  description = "Public DNS name of the Application Load Balancer"
  value       = module.alb.alb_dns_name
}

output "application_url" {
  description = "Secure HTTPS application entry point"
  value       = "https://${module.alb.alb_dns_name}"
}

output "health_check_url" {
  description = "ALB health check endpoint URL"
  value       = "https://${module.alb.alb_dns_name}/health"
}

output "vpc_id" {
  description = "ID of the VPC"
  value       = module.vpc.vpc_id
}

output "public_subnet_ids" {
  description = "IDs of the public subnets"
  value       = module.vpc.public_subnet_ids
}

output "private_app_subnet_ids" {
  description = "IDs of the private application subnets"
  value       = module.vpc.private_app_subnet_ids
}

output "private_db_subnet_ids" {
  description = "IDs of the private database subnets"
  value       = module.vpc.private_db_subnet_ids
}

output "rds_endpoint" {
  description = "Connection endpoint of the RDS MySQL instance"
  value       = module.rds.db_endpoint
}

output "rds_address" {
  description = "Hostname address of the RDS MySQL instance"
  value       = module.rds.db_address
}

output "secrets_manager_secret_name" {
  description = "Name of the AWS Secrets Manager secret storing database credentials"
  value       = module.secrets.secret_name
}

output "secrets_manager_secret_arn" {
  description = "ARN of the AWS Secrets Manager secret"
  value       = module.secrets.secret_arn
}

output "autoscaling_group_name" {
  description = "Name of the EC2 Auto Scaling Group"
  value       = module.asg.asg_name
}

output "alb_logs_bucket" {
  description = "S3 bucket name where ALB access logs are delivered"
  value       = module.s3.alb_logs_bucket_id
}

output "app_storage_bucket" {
  description = "S3 bucket name for application storage"
  value       = module.s3.app_storage_bucket_id
}

output "github_actions_role_arn" {
  description = "IAM Role ARN assumed by GitHub Actions via OIDC"
  value       = module.iam.github_actions_role_arn
}
