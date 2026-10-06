variable "aws_region" {
  type        = string
  description = "AWS region for deployment"
  default     = "us-east-1"
}

variable "project_name" {
  type        = string
  description = "Project name prefix applied to all resources"
  default     = "savitara"
}

variable "environment" {
  type        = string
  description = "Deployment environment (dev, staging, prod)"
  default     = "dev"
}

# Networking Variables
variable "vpc_cidr" {
  type        = string
  description = "CIDR block for the custom VPC"
  default     = "10.0.0.0/16"
}

variable "public_subnet_cidrs" {
  type        = list(string)
  description = "CIDR blocks for public subnets (ALB & NAT Gateway)"
  default     = ["10.0.1.0/24", "10.0.2.0/24"]
}

variable "private_app_subnet_cidrs" {
  type        = list(string)
  description = "CIDR blocks for private application subnets (EC2 ASG)"
  default     = ["10.0.11.0/24", "10.0.12.0/24"]
}

variable "private_db_subnet_cidrs" {
  type        = list(string)
  description = "CIDR blocks for private database subnets (RDS MySQL)"
  default     = ["10.0.21.0/24", "10.0.22.0/24"]
}

variable "single_nat_gateway" {
  type        = bool
  description = "Deploy a single NAT Gateway across AZs to minimize AWS NAT hourly costs"
  default     = true
}

# Application & Compute Variables
variable "app_port" {
  type        = number
  description = "TCP port on which the backend application listens"
  default     = 8080
}

variable "instance_type" {
  type        = string
  description = "EC2 instance type for Auto Scaling group"
  default     = "t3.micro"
}

variable "asg_min_size" {
  type        = number
  description = "Minimum capacity of the Auto Scaling Group"
  default     = 2
}

variable "asg_max_size" {
  type        = number
  description = "Maximum capacity of the Auto Scaling Group"
  default     = 4
}

variable "asg_desired_capacity" {
  type        = number
  description = "Desired capacity of the Auto Scaling Group"
  default     = 2
}

variable "target_cpu_utilization" {
  type        = number
  description = "Target average CPU utilization percentage for ASG auto-scaling"
  default     = 70.0
}

# Database Variables
variable "db_name" {
  type        = string
  description = "Name of the default MySQL database schema"
  default     = "appdb"
}

variable "db_username" {
  type        = string
  description = "Master username for RDS MySQL"
  default     = "appadmin"
}

variable "db_instance_class" {
  type        = string
  description = "RDS MySQL instance class"
  default     = "db.t3.micro"
}

variable "db_multi_az" {
  type        = bool
  description = "Enable Multi-AZ RDS deployment for high availability"
  default     = false
}

# ALB & Security Variables
variable "acm_certificate_arn" {
  type        = string
  description = "ARN of an existing ACM certificate for ALB HTTPS listener. If empty, a valid self-signed cert is imported."
  default     = ""
}

variable "enable_alb_access_logs" {
  type        = bool
  description = "Enable S3 access logging for Application Load Balancer"
  default     = true
}

variable "alb_log_retention_days" {
  type        = number
  description = "Retention period in days for ALB access logs"
  default     = 30
}

# GitHub CI/CD OIDC Variables
variable "create_github_oidc_role" {
  type        = bool
  description = "Create AWS IAM Role and OIDC provider for GitHub Actions CI/CD"
  default     = true
}

variable "create_oidc_provider" {
  type        = bool
  description = "Whether to create the AWS IAM OIDC provider. Set to false if already existing in account."
  default     = true
}

variable "existing_oidc_provider_arn" {
  type        = string
  description = "ARN of an existing GitHub Actions OIDC provider if create_oidc_provider is false"
  default     = ""
}

variable "github_repo" {
  type        = string
  description = "GitHub repository in 'owner/repo' format permitted to assume OIDC role"
  default     = "*"
}
