output "secret_id" {
  description = "ID of the database Secrets Manager secret"
  value       = aws_secretsmanager_secret.db_credentials.id
}

output "secret_name" {
  description = "Name of the database Secrets Manager secret"
  value       = aws_secretsmanager_secret.db_credentials.name
}

output "secret_arn" {
  description = "ARN of the database Secrets Manager secret"
  value       = aws_secretsmanager_secret.db_credentials.arn
}

output "generated_password" {
  description = "Generated database master password (marked sensitive)"
  value       = random_password.db_password.result
  sensitive   = true
}
