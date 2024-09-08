resource "aws_secretsmanager_secret" "db_secret" {
  name                    = "crdbcreds"
  description             = "CockroachDB credentials"
  recovery_window_in_days = 0
}

resource "aws_secretsmanager_secret_version" "db_secret_version" {
  secret_id = aws_secretsmanager_secret.db_secret.id
  secret_string = jsonencode({
    name     = var.db_name
    user     = var.db_username
    password = var.db_password
    host     = var.db_host
  })
}
