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

variable "alb_log_retention_days" {
  type        = number
  description = "Number of days to retain ALB access logs before expiration"
  default     = 30
}

variable "tags" {
  type        = map(string)
  description = "Common tags to apply to all resources"
  default     = {}
}
