variable "environment" {
  description = "Environment name (dev, prod, etc.)"
  type        = string
}

variable "vpc_id" {
  description = "VPC ID where security groups will be created"
  type        = string
}

variable "allowed_ssh_cidr_blocks" {
  description = "CIDR blocks allowed to SSH into EC2 instances"
  type        = list(string)
  default     = []
}

variable "app_port" {
  description = "Port on which application runs"
  type        = number
  default     = 8080
}

variable "db_port" {
  description = "Database port (3306 for MySQL, 5432 for PostgreSQL)"
  type        = number
  default     = 5432
}