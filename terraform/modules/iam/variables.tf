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

variable "db_secret_arn" {
  type        = string
  description = "ARN of the Secrets Manager secret for the database"
}

variable "app_storage_bucket_arn" {
  type        = string
  description = "ARN of the S3 bucket for application storage"
}

variable "create_github_oidc_role" {
  type        = bool
  description = "Whether to create the IAM role and OIDC provider for GitHub Actions CI/CD"
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
  description = "GitHub repository in format 'owner/repo' permitted to assume OIDC role"
  default     = "*"
}

variable "tags" {
  type        = map(string)
  description = "Common tags to apply to all resources"
  default     = {}
}
