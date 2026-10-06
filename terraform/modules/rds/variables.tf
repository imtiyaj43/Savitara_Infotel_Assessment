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

variable "subnet_ids" {
  type        = list(string)
  description = "List of private database subnet IDs across multiple AZs"
}

variable "rds_security_group_id" {
  type        = string
  description = "Security Group ID for RDS MySQL"
}

variable "db_name" {
  type        = string
  description = "Database name"
  default     = "appdb"
}

variable "db_username" {
  type        = string
  description = "Master username for MySQL"
  default     = "appadmin"
}

variable "db_password" {
  type        = string
  description = "Master password for MySQL"
  sensitive   = true
}

variable "db_instance_class" {
  type        = string
  description = "Database instance class"
  default     = "db.t3.micro"
}

variable "allocated_storage" {
  type        = number
  description = "Allocated storage size in GB"
  default     = 20
}

variable "max_allocated_storage" {
  type        = number
  description = "Maximum storage limit for auto-scaling in GB"
  default     = 50
}

variable "multi_az" {
  type        = bool
  description = "Whether to deploy Multi-AZ RDS instance"
  default     = false
}

variable "backup_retention_period" {
  type        = number
  description = "Number of days to retain automated backups"
  default     = 1
}

variable "skip_final_snapshot" {
  type        = bool
  description = "Whether to skip final snapshot when destroying RDS"
  default     = true
}

variable "deletion_protection" {
  type        = bool
  description = "Enable deletion protection on RDS"
  default     = false
}

variable "tags" {
  type        = map(string)
  description = "Common tags to apply to all resources"
  default     = {}
}
