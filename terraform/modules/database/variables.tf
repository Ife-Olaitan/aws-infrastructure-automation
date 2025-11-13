variable "environment" {
  description = "Environment name (e.g., dev, staging, prod)"
  type        = string
}

variable "private_subnet_ids" {
  description = "List of private subnet IDs for the database subnet group"
  type        = list(string)
}

variable "db_security_group_id" {
  description = "Security group ID for the database"
  type        = string
}

variable "instance_class" {
  description = "Database instance class"
  type        = string
  default     = "db.t3.micro"
}

variable "engine_version" {
  description = "Database engine version"
  type        = string
  default     = "15.4"
}

variable "allocated_storage" {
  description = "Initial storage allocation in GB"
  type        = number
  default     = 20
}

variable "max_allocated_storage" {
  description = "Maximum storage allocation in GB for autoscaling"
  type        = number
  default     = 100
}

variable "database_name" {
  description = "Name of the default database"
  type        = string
  default     = "appdb"
}

variable "master_username" {
  description = "Master username for the database"
  type        = string
  default     = "dbadmin"
}

variable "multi_az" {
  description = "Enable multi-AZ deployment for high availability"
  type        = bool
  default     = false
}

variable "backup_retention_period" {
  description = "Number of days to retain automated backups"
  type        = number
  default     = 7
}

variable "skip_final_snapshot" {
  description = "Skip final snapshot when destroying database (set to false in production)"
  type        = bool
  default     = true
}