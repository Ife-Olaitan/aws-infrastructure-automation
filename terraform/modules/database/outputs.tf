output "db_instance_endpoint" {
  description = "Connection endpoint for the database (includes port)"
  value       = aws_db_instance.main.endpoint
}

output "db_instance_address" {
  description = "Hostname of the database instance"
  value       = aws_db_instance.main.address
}

output "db_instance_name" {
  description = "Name of the database"
  value       = aws_db_instance.main.db_name
}

output "db_instance_username" {
  description = "Master username for the database"
  value       = aws_db_instance.main.username
  sensitive   = true
}

output "db_password_secret_arn" {
  description = "ARN of the Secrets Manager secret containing the database password"
  value       = aws_secretsmanager_secret.db_password.arn
}

output "db_instance_port" {
  description = "Port the database is listening on"
  value       = aws_db_instance.main.port
}