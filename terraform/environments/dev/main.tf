# VPC Module
module "vpc" {
  source = "../../modules/vpc"

  environment          = var.environment
  vpc_cidr             = var.vpc_cidr
  public_subnet_cidrs  = var.public_subnet_cidrs
  private_subnet_cidrs = var.private_subnet_cidrs
}

# Security Module
module "security" {
  source = "../../modules/security"

  environment             = var.environment
  vpc_id                  = module.vpc.vpc_id
  allowed_ssh_cidr_blocks = var.allowed_ssh_cidr_blocks
  app_port                = var.app_port
  db_port                 = var.db_port
}

# Load Balancer Module
module "loadbalancer" {
  source = "../../modules/loadbalancer"

  environment           = var.environment
  vpc_id                = module.vpc.vpc_id
  public_subnet_ids     = module.vpc.public_subnet_ids
  alb_security_group_id = module.security.alb_security_group_id
}

# Compute Module
module "compute" {
  source = "../../modules/compute"

  environment               = var.environment
  instance_type             = var.instance_type
  key_name                  = var.key_name
  security_group_id         = module.security.ec2_security_group_id
  iam_instance_profile_name = module.security.ec2_instance_profile_name
  private_subnet_ids        = module.vpc.private_subnet_ids
  target_group_arns         = module.loadbalancer.target_group_arns
  min_size                  = var.min_size
  max_size                  = var.max_size
  desired_capacity          = var.desired_capacity
}