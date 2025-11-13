terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "5.99.1"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.6"
    }
  }
}

# DB Subnet Group - Defines which subnets the RDS instance can be deployed in
resource "aws_db_subnet_group" "main" {
  name       = "${var.environment}-db-subnet-group"
  subnet_ids = var.private_subnet_ids

  tags = {
    Name        = "${var.environment}-db-subnet-group"
    Environment = var.environment
  }
}

# Random Password - Generates a secure password for the database master user
resource "random_password" "master_password" {
  length  = 16
  special = true
}

# Secrets Manager Secret - Stores the database password securely
resource "aws_secretsmanager_secret" "db_password" {
  name = "${var.environment}-db-password"

  tags = {
    Name        = "${var.environment}-db-password"
    Environment = var.environment
  }
}

# Secrets Manager Secret Version - Stores the actual password value
resource "aws_secretsmanager_secret_version" "db_password" {
  secret_id     = aws_secretsmanager_secret.db_password.id
  secret_string = random_password.master_password.result
}

# RDS PostgreSQL Instance - Main database server
resource "aws_db_instance" "main" {
  # Basic Settings
  identifier     = "${var.environment}-postgres-db"
  engine         = "postgres"
  engine_version = var.engine_version
  instance_class = var.instance_class

  # Storage Configuration
  allocated_storage     = var.allocated_storage
  max_allocated_storage = var.max_allocated_storage
  storage_type          = "gp3"
  storage_encrypted     = true

  # Database Configuration
  db_name  = var.database_name
  username = var.master_username
  password = random_password.master_password.result

  # Network Configuration
  db_subnet_group_name   = aws_db_subnet_group.main.name
  vpc_security_group_ids = [var.db_security_group_id]
  publicly_accessible    = false

  # High Availability & Backups
  multi_az               = var.multi_az
  backup_retention_period = var.backup_retention_period
  backup_window          = "03:00-04:00"
  maintenance_window     = "mon:04:00-mon:05:00"

  # Snapshot Configuration
  skip_final_snapshot       = var.skip_final_snapshot
  final_snapshot_identifier = var.skip_final_snapshot ? null : "${var.environment}-postgres-db-final-snapshot"

  # Monitoring
  enabled_cloudwatch_logs_exports = ["postgresql", "upgrade"]

  tags = {
    Name        = "${var.environment}-postgres-db"
    Environment = var.environment
  }
}