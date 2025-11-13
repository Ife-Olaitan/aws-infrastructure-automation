# VPC Outputs
output "vpc_id" {
  description = "The ID of the VPC"
  value       = module.vpc.vpc_id
}

output "public_subnet_ids" {
  description = "List of IDs of public subnets"
  value       = module.vpc.public_subnet_ids
}

output "private_subnet_ids" {
  description = "List of IDs of private subnets"
  value       = module.vpc.private_subnet_ids
}

output "internet_gateway_id" {
  description = "The ID of the Internet Gateway"
  value       = module.vpc.internet_gateway_id
}

output "nat_gateway_id" {
  description = "The ID of the NAT Gateway"
  value       = module.vpc.nat_gateway_id
}

# Security Module Outputs
output "alb_security_group_id" {
  description = "ID of the ALB security group"
  value       = module.security.alb_security_group_id
}

output "ec2_security_group_id" {
  description = "ID of the EC2 security group"
  value       = module.security.ec2_security_group_id
}

output "rds_security_group_id" {
  description = "ID of the RDS security group"
  value       = module.security.rds_security_group_id
}

output "ec2_instance_profile_name" {
  description = "Name of the EC2 instance profile"
  value       = module.security.ec2_instance_profile_name
}

output "ec2_iam_role_arn" {
  description = "ARN of the EC2 IAM role"
  value       = module.security.ec2_iam_role_arn
}

# Load Balancer Module Outputs
output "alb_dns_name" {
  description = "DNS name of the Application Load Balancer - Use this URL to access your application"
  value       = module.loadbalancer.alb_dns_name
}

output "alb_arn" {
  description = "ARN of the Application Load Balancer"
  value       = module.loadbalancer.alb_arn
}

output "alb_zone_id" {
  description = "Zone ID of the Application Load Balancer"
  value       = module.loadbalancer.alb_zone_id
}

output "frontend_target_group_arn" {
  description = "ARN of the frontend target group"
  value       = module.loadbalancer.frontend_target_group_arn
}

output "backend_target_group_arn" {
  description = "ARN of the backend target group"
  value       = module.loadbalancer.backend_target_group_arn
}

# Database Module Outputs
output "db_instance_endpoint" {
  description = "Connection endpoint for the database (includes port)"
  value       = module.database.db_instance_endpoint
}

output "db_instance_address" {
  description = "Hostname of the database instance"
  value       = module.database.db_instance_address
}

output "db_instance_name" {
  description = "Name of the database"
  value       = module.database.db_instance_name
}

output "db_instance_username" {
  description = "Master username for the database"
  value       = module.database.db_instance_username
  sensitive   = true
}

output "db_password_secret_arn" {
  description = "ARN of the Secrets Manager secret containing the database password"
  value       = module.database.db_password_secret_arn
}

output "db_instance_port" {
  description = "Port the database is listening on"
  value       = module.database.db_instance_port
}

# Compute Module Outputs
output "autoscaling_group_name" {
  description = "Name of the Auto Scaling Group"
  value       = module.compute.autoscaling_group_name
}

output "autoscaling_group_id" {
  description = "ID of the Auto Scaling Group"
  value       = module.compute.autoscaling_group_id
}

output "launch_template_id" {
  description = "ID of the Launch Template"
  value       = module.compute.launch_template_id
}

output "launch_template_version" {
  description = "Latest version of the Launch Template"
  value       = module.compute.launch_template_latest_version
}