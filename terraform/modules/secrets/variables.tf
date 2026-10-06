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

variable "db_username" {
  type        = string
  description = "Master username for the RDS database"
  default     = "appadmin"
}

variable "db_name" {
  type        = string
  description = "Database schema name"
  default     = "appdb"
}

variable "db_port" {
  type        = number
  description = "Database port"
  default     = 3306
}

variable "db_host" {
  type        = string
  description = "Database endpoint host address"
  default     = ""
}

variable "tags" {
  type        = map(string)
  description = "Common tags to apply to all resources"
  default     = {}
}
