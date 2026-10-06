variable "aws_region" {
  type        = string
  description = "AWS region for remote state storage"
  default     = "us-east-1"
}

variable "project_name" {
  type        = string
  description = "Project name prefix"
  default     = "savitara"
}
