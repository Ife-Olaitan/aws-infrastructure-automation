# VPC Module
module "vpc" {
  source = "../../modules/vpc"

  environment          = var.environment
  vpc_cidr             = var.vpc_cidr
  public_subnet_cidrs  = var.public_subnet_cidrs
  private_subnet_cidrs = var.private_subnet_cidrs
}

# ECR Module
module "ecr" {
  source = "../../modules/ecr"

  environment = var.environment
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

# Database Module
module "database" {
  source = "../../modules/database"

  environment          = var.environment
  private_subnet_ids   = module.vpc.private_subnet_ids
  db_security_group_id = module.security.rds_security_group_id
}

# Compute Module
# NOTE: EC2 instances are deployed in PUBLIC subnets for this tutorial
#
# Why public subnets?
# - Ansible needs direct SSH access to configure the instances
# - Instances in private subnets can't receive inbound SSH, even with public IPs
# - Private subnets only allow outbound traffic through NAT Gateway
#
# Security considerations:
# - SSH is restricted to your IP only via Security Group (92.238.57.187/32)
# - UFW firewall is configured by Ansible for additional protection
# - Database remains in private subnets (no internet access)
#
# For production environments, consider:
# - Option 1: Use a bastion host (jump server) in public subnet to access private instances
# - Option 2: Use AWS Systems Manager Session Manager (no SSH or bastion needed)
# - Option 3: Use GitHub Actions with self-hosted runners in private subnets
module "compute" {
  source = "../../modules/compute"

  environment               = var.environment
  instance_type             = var.instance_type
  key_name                  = var.key_name
  security_group_id         = module.security.ec2_security_group_id
  iam_instance_profile_name = module.security.ec2_instance_profile_name
  subnet_ids                = module.vpc.public_subnet_ids  # Using public subnets for Ansible SSH access
  target_group_arns         = module.loadbalancer.target_group_arns
  min_size                  = var.min_size
  max_size                  = var.max_size
  desired_capacity          = var.desired_capacity
}