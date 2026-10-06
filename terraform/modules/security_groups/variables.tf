variable "project_name" {
  type        = string
  description = "Name of the project prefix for resources"
  default     = "savitara"
}

variable "environment" {
  type        = string
  description = "Deployment environment"
  default     = "dev"
}

variable "vpc_id" {
  type        = string
  description = "ID of the VPC where security groups will be created"
}

variable "app_port" {
  type        = number
  description = "Application port listened to by EC2 instances"
  default     = 8080
}

variable "tags" {
  type        = map(string)
  description = "Common tags to apply to all resources"
  default     = {}
}
