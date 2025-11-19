# Documentation

## Quick Links

- [Architecture](architecture.md) - System design and components
- [Deployment](deployment.md) - Step-by-step deployment guide

## Project Structure

```
├── ansible/               # Configuration management
│   ├── playbooks/        # Ansible playbooks
│   ├── roles/            # Reusable roles
│   └── inventory/        # Server inventory (auto-generated)
├── docker/               # Application containers
│   ├── backend/         # Node.js API
│   ├── frontend/        # Nginx static site
│   └── database/        # PostgreSQL init scripts
├── scripts/              # Automation scripts
│   ├── deploy.sh        # Main deployment script
│   ├── destroy.sh       # Infrastructure teardown
│   └── build-and-push-to-ecr.sh  # Docker image builds
├── terraform/            # Infrastructure as Code
│   ├── environments/    # Environment configs
│   └── modules/         # Reusable modules
└── docs/                # Documentation
```

## Getting Started

1. **Prerequisites**: AWS account, Terraform, Ansible, Docker
2. **Setup**: Run `./scripts/setup-terraform-backend.sh`
3. **Deploy**: Run `./scripts/deploy.sh`

## Technologies

- **Cloud**: AWS (VPC, EC2, RDS, ALB, IAM, ECR, Secrets Manager)
- **IaC**: Terraform
- **Config Management**: Ansible
- **Containers**: Docker
- **Database**: PostgreSQL
- **Web Server**: Nginx
- **Backend**: Node.js + Express

## Architecture Highlights

- ✅ Multi-AZ deployment for high availability
- ✅ Auto-scaling based on CPU metrics
- ✅ Load balanced traffic distribution
- ✅ Secure database in private subnets
- ✅ SSL/TLS encryption for database connections
- ✅ IAM roles following least privilege
- ✅ Automated deployment scripts