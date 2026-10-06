variable "project_name" {
  type        = string
  description = "Project name prefix"
  default     = "savitara"
}

variable "environment" {
  type        = string
  description = "Deployment environment"
  default     = "dev"
}

variable "aws_region" {
  type        = string
  description = "AWS region"
  default     = "us-east-1"
}

variable "instance_type" {
  type        = string
  description = "EC2 instance type"
  default     = "t3.micro"
}

variable "ami_id" {
  type        = string
  description = "Custom AMI ID. If empty, the latest Amazon Linux 2023 AMI is used."
  default     = ""
}

variable "instance_profile_name" {
  type        = string
  description = "Name of the IAM instance profile to attach to EC2 instances"
}

variable "ec2_security_group_id" {
  type        = string
  description = "Security group ID for EC2 instances"
}

variable "private_app_subnet_ids" {
  type        = list(string)
  description = "List of private application subnet IDs across multiple AZs"
}

variable "target_group_arn" {
  type        = string
  description = "ARN of the ALB Target Group"
}

variable "app_port" {
  type        = number
  description = "Application listening port"
  default     = 8080
}

variable "db_secret_name" {
  type        = string
  description = "Name of the AWS Secrets Manager secret for database credentials"
}

variable "app_storage_bucket" {
  type        = string
  description = "Name of the S3 bucket for application storage"
  default     = ""
}

variable "min_size" {
  type        = number
  description = "Minimum size of the Auto Scaling Group"
  default     = 2
}

variable "max_size" {
  type        = number
  description = "Maximum size of the Auto Scaling Group"
  default     = 4
}

variable "desired_capacity" {
  type        = number
  description = "Desired capacity of the Auto Scaling Group"
  default     = 2
}

variable "target_cpu_utilization" {
  type        = number
  description = "Target CPU utilization percentage for ASG scaling policy"
  default     = 70.0
}

variable "tags" {
  type        = map(string)
  description = "Common tags to apply to all resources"
  default     = {}
}
