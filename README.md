# AWS Infrastructure Automation

Production-ready AWS infrastructure deployment using Terraform, Ansible, and Docker.

## 🏗️ Architecture

Multi-tier web application infrastructure with:
- VPC with public/private subnets across 2 AZs
- Application Load Balancer with path-based routing
- Auto Scaling Group (2-4 EC2 instances)
- RDS PostgreSQL database (Multi-AZ)
- Docker containerized applications (Node.js + Nginx)

## 🚀 Quick Start

```bash
# 1. Setup Terraform backend
./scripts/setup-terraform-backend.sh

# 2. Deploy everything
./scripts/deploy.sh

# 3. Access your application
# ALB DNS will be displayed after deployment
```

## 📚 Documentation

- **[Architecture](docs/architecture.md)** - Detailed system design and components
- **[Deployment Guide](docs/deployment.md)** - Step-by-step deployment instructions

## 🛠️ Technologies

- **Cloud**: AWS (VPC, EC2, RDS, ALB, IAM, ECR, Secrets Manager)
- **IaC**: Terraform
- **Config Management**: Ansible
- **Containers**: Docker
- **Database**: PostgreSQL
- **Web Server**: Nginx
- **Backend**: Node.js + Express

## ✅ Features

- ✅ Multi-AZ deployment for high availability
- ✅ Auto-scaling based on CPU metrics
- ✅ Load balanced traffic distribution
- ✅ Secure database in private subnets
- ✅ SSL/TLS encryption for database connections
- ✅ IAM roles following least privilege
- ✅ Automated deployment scripts
- ✅ Infrastructure as Code with Terraform modules
- ✅ Automated configuration with Ansible
- ✅ Container orchestration with Docker

## 📁 Project Structure

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
│   ├── environments/    # Environment configs (dev/staging/prod)
│   └── modules/         # Reusable modules
└── docs/                # Documentation
```

## 🎯 Use Cases

This project demonstrates:
- Production-grade AWS infrastructure deployment
- Infrastructure as Code best practices
- Configuration Management with Ansible
- Container orchestration
- Security best practices (least privilege, encryption, network isolation)
- High availability and fault tolerance
- Auto-scaling and load balancing

## 💰 Cost Estimate

**Dev Environment:** ~$110/month
- EC2: 2 × t3.micro (~$15)
- RDS: db.t3.micro Multi-AZ (~$25)
- ALB (~$20)
- NAT Gateway (~$35)
- Storage and Data Transfer (~$15)

**Cost Optimization:**
- Destroy when not in use: `./scripts/destroy.sh`
- Use single NAT Gateway (implemented)
- Stop instances during off-hours

## 🚧 Development Status

- [x] VPC module with multi-AZ architecture
- [x] Security module (IAM, Security Groups)
- [x] Compute module (ASG, Launch Template)
- [x] Load Balancer module (ALB, Target Groups)
- [x] Database module (RDS PostgreSQL)
- [x] Docker containers (Backend + Frontend)
- [x] Ansible playbooks and roles
- [x] Deployment automation scripts
- [x] Complete documentation

## 🤝 Contributing

This is a portfolio project. Feel free to fork and customize for your needs.

---

**Built with ❤️ for DevOps learning**
