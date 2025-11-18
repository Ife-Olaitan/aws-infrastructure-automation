variable "environment" {
  description = "Environment name (dev, prod, etc.)"
  type        = string
}

variable "instance_type" {
  description = "EC2 instance type"
  type        = string
  default     = "t3.micro"
}

variable "key_name" {
  description = "SSH key pair name for EC2 instances"
  type        = string
}

variable "security_group_id" {
  description = "Security group ID for EC2 instances"
  type        = string
}

variable "iam_instance_profile_name" {
  description = "IAM instance profile name for EC2 instances"
  type        = string
}

variable "subnet_ids" {
  description = "List of subnet IDs for EC2 instances (public subnets for SSH access)"
  type        = list(string)
}

variable "target_group_arns" {
  description = "List of target group ARNs for load balancer attachment"
  type        = list(string)
  default     = []
}

variable "min_size" {
  description = "Minimum number of instances in Auto Scaling Group"
  type        = number
  default     = 1
}

variable "max_size" {
  description = "Maximum number of instances in Auto Scaling Group"
  type        = number
  default     = 4
}

variable "desired_capacity" {
  description = "Desired number of instances in Auto Scaling Group"
  type        = number
  default     = 2
}

