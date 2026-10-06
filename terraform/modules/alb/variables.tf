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

variable "vpc_id" {
  type        = string
  description = "VPC ID where Target Group is created"
}

variable "public_subnet_ids" {
  type        = list(string)
  description = "Public Subnet IDs across multiple AZs where ALB is deployed"
}

variable "alb_security_group_id" {
  type        = string
  description = "Security Group ID for ALB"
}

variable "app_port" {
  type        = number
  description = "Port the backend application listens on"
  default     = 8080
}

variable "health_check_path" {
  type        = string
  description = "Health check path on backend instances"
  default     = "/health"
}

variable "acm_certificate_arn" {
  type        = string
  description = "ARN of an existing ACM certificate. If empty, a valid self-signed certificate is imported into ACM."
  default     = ""
}

variable "enable_access_logs" {
  type        = bool
  description = "Whether to enable access logs on ALB"
  default     = true
}

variable "access_logs_bucket" {
  type        = string
  description = "S3 bucket name for storing ALB access logs"
  default     = ""
}

variable "tags" {
  type        = map(string)
  description = "Common tags to apply to all resources"
  default     = {}
}
