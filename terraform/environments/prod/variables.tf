variable "aws_region" {
  type        = string
  description = "AWS region"
  default     = "us-east-1"
}

variable "project_name" {
  type        = string
  description = "Project name"
  default     = "savitara"
}

variable "vpc_cidr" {
  type    = string
  default = "10.0.0.0/16"
}

variable "public_subnet_cidrs" {
  type    = list(string)
  default = ["10.0.1.0/24", "10.0.2.0/24"]
}

variable "private_app_subnet_cidrs" {
  type    = list(string)
  default = ["10.0.11.0/24", "10.0.12.0/24"]
}

variable "private_db_subnet_cidrs" {
  type    = list(string)
  default = ["10.0.21.0/24", "10.0.22.0/24"]
}

variable "app_port" {
  type    = number
  default = 8080
}

variable "db_username" {
  type    = string
  default = "appadmin"
}

variable "db_name" {
  type    = string
  default = "appdb"
}

variable "acm_certificate_arn" {
  type    = string
  default = ""
}

variable "create_github_oidc_role" {
  type    = bool
  default = true
}

variable "create_oidc_provider" {
  type    = bool
  default = true
}

variable "existing_oidc_provider_arn" {
  type    = string
  default = ""
}

variable "github_repo" {
  type    = string
  default = "*"
}
