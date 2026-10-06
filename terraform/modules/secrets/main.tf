resource "random_password" "db_password" {
  length           = 20
  special          = true
  override_special = "!#$%&*()-_=+[]{}<>:?"
}

resource "aws_secretsmanager_secret" "db_credentials" {
  name_prefix             = "${var.project_name}-${var.environment}-db-credentials-"
  description             = "Database master credentials and connection endpoint for ${var.project_name}"
  recovery_window_in_days = 0 # Ensures clean deletion during evaluation/teardown

  tags = merge(
    var.tags,
    {
      Name = "${var.project_name}-${var.environment}-db-secret"
    }
  )
}

resource "aws_secretsmanager_secret_version" "db_credentials" {
  secret_id = aws_secretsmanager_secret.db_credentials.id

  secret_string = jsonencode({
    engine   = "mysql"
    host     = var.db_host
    port     = var.db_port
    username = var.db_username
    password = random_password.db_password.result
    database = var.db_name
  })
}
