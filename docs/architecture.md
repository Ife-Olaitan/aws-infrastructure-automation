# Architecture Documentation

## Overview

This project implements a production-grade, highly available web application infrastructure on AWS using Infrastructure as Code (Terraform) and Configuration Management (Ansible).

## System Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│                         Internet Gateway                         │
└──────────────────────────────┬──────────────────────────────────┘
                               │
                               ▼
┌─────────────────────────────────────────────────────────────────┐
│                     Application Load Balancer                    │
│                      (Public Subnets)                            │
│                  eu-west-2a     │    eu-west-2b                  │
└──────────────────────┬──────────┴─────────┬─────────────────────┘
                       │                    │
                       ▼                    ▼
┌────────────────────────────────────────────────────────────────┐
│                  Auto Scaling Group (2-4 instances)             │
│                  EC2 with Docker Containers                     │
│  ┌─────────────────────────┐  ┌─────────────────────────┐      │
│  │  Frontend (Nginx:80)    │  │  Backend (Node.js:3000) │      │
│  │  - Static site          │  │  - REST API             │      │
│  │  - Health checks        │  │  - Database connection  │      │
│  └─────────────────────────┘  └─────────────────────────┘      │
│                  Public Subnets                                 │
│              eu-west-2a     │    eu-west-2b                     │
└──────────────────────┬────────────────┬────────────────────────┘
                       │                │
                       └────────┬───────┘
                                ▼
┌────────────────────────────────────────────────────────────────┐
│                    NAT Gateway (optional)                       │
└──────────────────────────────┬─────────────────────────────────┘
                               │
                               ▼
┌────────────────────────────────────────────────────────────────┐
│                 RDS PostgreSQL (Multi-AZ)                       │
│                    Private Subnets                              │
│              eu-west-2a     │    eu-west-2b                     │
│              (Primary)           (Standby)                      │
└────────────────────────────────────────────────────────────────┘
```

## Network Architecture

### VPC Configuration
- **CIDR Block**: `10.0.0.0/16`
- **Availability Zones**: 2 (eu-west-2a, eu-west-2b)
- **DNS**: Enabled
- **DNS Hostnames**: Enabled

### Subnets

#### Public Subnets (Internet-facing)
- **public-subnet-1**: `10.0.1.0/24` (eu-west-2a)
- **public-subnet-2**: `10.0.2.0/24` (eu-west-2b)
- **Purpose**: ALB, EC2 instances
- **Route**: Internet Gateway

#### Private Subnets (Isolated)
- **private-subnet-1**: `10.0.11.0/24` (eu-west-2a)
- **private-subnet-2**: `10.0.12.0/24` (eu-west-2b)
- **Purpose**: RDS PostgreSQL database
- **Route**: NAT Gateway (for updates only)

### Routing
- Public route table routes `0.0.0.0/0` to Internet Gateway
- Private route table routes `0.0.0.0/0` to NAT Gateway
- Local routing for VPC CIDR automatically configured

## Compute Resources

### Auto Scaling Group
- **Min Size**: 2 instances
- **Max Size**: 4 instances
- **Desired**: 2 instances
- **Health Check Type**: EC2
- **Health Check Grace Period**: 300 seconds
- **Scaling Metrics**: CPU utilization

### EC2 Instances
- **AMI**: Ubuntu 22.04 LTS
- **Instance Type**: `t3.micro` (dev), `t3.small` (prod)
- **Storage**: 20GB GP3 EBS
- **User Data**: Docker installation, CloudWatch agent
- **IAM Role**: EC2 role with Secrets Manager and ECR access

### Auto Scaling Policies

#### Scale Up Policy
- **Trigger**: CPU > 70% for 2 consecutive periods (120 seconds)
- **Action**: Add 1 instance
- **Cooldown**: 300 seconds

#### Scale Down Policy
- **Trigger**: CPU < 30% for 2 consecutive periods (120 seconds)
- **Action**: Remove 1 instance
- **Cooldown**: 300 seconds

## Load Balancing

### Application Load Balancer
- **Type**: Application Load Balancer
- **Scheme**: Internet-facing
- **IP Type**: IPv4
- **Subnets**: Both public subnets
- **Security**: ALB security group

### Target Groups

#### Frontend Target Group
- **Port**: 80
- **Protocol**: HTTP
- **Health Check**: `/` on port 80
- **Healthy Threshold**: 2
- **Unhealthy Threshold**: 2
- **Timeout**: 5 seconds
- **Interval**: 30 seconds

#### Backend Target Group
- **Port**: 3000
- **Protocol**: HTTP
- **Health Check**: `/health` on port 3000
- **Healthy Threshold**: 2
- **Unhealthy Threshold**: 2
- **Timeout**: 5 seconds
- **Interval**: 30 seconds

### Listener Rules
- Default action: Forward to frontend target group
- Path `/api/*`: Forward to backend target group

## Database

### RDS PostgreSQL
- **Engine**: PostgreSQL 14.x
- **Instance Class**: `db.t3.micro` (dev), `db.t3.small` (prod)
- **Storage**: 20GB GP3
- **Multi-AZ**: Enabled for high availability
- **Backup**: 7-day retention
- **Encryption**: At rest and in transit (SSL/TLS)
- **Network**: Private subnets only
- **Port**: 5432

### Database Security
- Accessible only from EC2 security group
- SSL/TLS connections required
- Credentials stored in AWS Secrets Manager
- Automatic password rotation (optional)

## Security

### Security Groups

#### ALB Security Group
- **Inbound**:
  - Port 80 (HTTP) from `0.0.0.0/0`
  - Port 443 (HTTPS) from `0.0.0.0/0` (if SSL enabled)
- **Outbound**: All traffic

#### EC2 Security Group
- **Inbound**:
  - Port 22 (SSH) from admin IP
  - Port 80 from ALB security group
  - Port 3000 from ALB security group
- **Outbound**: All traffic

#### RDS Security Group
- **Inbound**:
  - Port 5432 from EC2 security group only
- **Outbound**: None required

### IAM Roles and Policies

#### EC2 Instance Role
Allows EC2 instances to:
- Read secrets from Secrets Manager (`secretsmanager:GetSecretValue`)
- Pull images from ECR (`ecr:GetAuthorizationToken`, `ecr:BatchGetImage`)
- Write logs to CloudWatch (optional)

### Secrets Management
- Database password stored in AWS Secrets Manager
- Secret name: `{environment}-db-password`
- Accessed by EC2 instances at runtime via IAM role
- Never stored in code or environment files

## Application Architecture

### Frontend Container
- **Base Image**: `nginx:alpine`
- **Port**: 80
- **Function**: Serves static HTML/CSS/JS
- **Health Check**: HTTP GET `/`
- **Environment**: Production build

### Backend Container
- **Base Image**: `node:18-alpine`
- **Port**: 3000
- **Function**: REST API server
- **Database**: PostgreSQL via SSL
- **Health Check**: HTTP GET `/health`
- **Initialization**: Auto-creates database schema on startup

### Container Runtime
- **Engine**: Docker
- **Network**: Bridge mode
- **Volumes**: None (stateless)
- **Restart Policy**: Always
- **Platform**: linux/amd64

## Data Flow

### User Request Flow
1. User sends HTTP request to ALB DNS name
2. ALB receives request on port 80
3. ALB routes based on path:
   - `/` or `/index.html` → Frontend target group
   - `/api/*` → Backend target group
4. Target group forwards to healthy EC2 instance
5. Docker container processes request
6. Backend queries RDS if needed (via SSL)
7. Response returned through ALB to user

### Deployment Flow
1. Run deployment script (`./scripts/deploy.sh`)
2. Script builds Docker images (AMD64) and pushes to ECR
3. Terraform creates/updates infrastructure
4. Script generates Ansible inventory from Terraform outputs
5. Ansible pulls images from ECR
6. Ansible starts containers with environment variables
7. Containers fetch DB password from Secrets Manager
8. Health checks verify deployment
9. ALB routes traffic to healthy instances

## High Availability

### Multi-AZ Deployment
- Resources distributed across 2 availability zones
- ALB distributes traffic across both AZs
- RDS automatic failover to standby in different AZ
- Auto Scaling replaces failed instances automatically

### Fault Tolerance
- **ALB**: Automatic health checks remove unhealthy targets
- **ASG**: Replaces failed instances based on health checks
- **RDS**: Multi-AZ with automatic failover (<60 seconds)
- **Data**: Daily automated backups with 7-day retention

### Disaster Recovery
- **RTO** (Recovery Time Objective): ~10 minutes
- **RPO** (Recovery Point Objective): 5 minutes (automated backups)
- **Backup**: Daily snapshots, cross-region copy optional
- **Restore**: Launch new RDS instance from snapshot

## Scalability

### Horizontal Scaling
- Auto Scaling Group scales from 2 to 4 instances
- CPU-based scaling policies
- Stateless application design allows seamless scaling
- ALB automatically includes new instances

### Vertical Scaling
- Instance types configurable per environment
- Database instance class adjustable
- Storage auto-scaling for RDS (optional)

## Monitoring and Observability

### CloudWatch Metrics (Future)
- EC2: CPU, memory, disk, network
- ALB: Request count, latency, HTTP codes
- RDS: CPU, connections, storage, IOPS
- Auto Scaling: Group size, scaling activities

### Health Checks
- **ALB → Frontend**: HTTP GET `/` (port 80)
- **ALB → Backend**: HTTP GET `/health` (port 3000)
- **ASG → EC2**: EC2 status checks
- **RDS**: Automated instance monitoring

### Logging (Future)
- Application logs: Docker container logs
- Access logs: ALB access logs to S3
- System logs: CloudWatch Logs agent
- Database logs: RDS logs in CloudWatch

## Cost Optimization

### Current Monthly Estimate (Dev Environment)
- **EC2**: 2 × t3.micro × 730 hours = ~$15
- **RDS**: db.t3.micro Multi-AZ × 730 hours = ~$25
- **ALB**: 1 × 730 hours + data transfer = ~$20
- **Data Transfer**: Minimal for dev = ~$5
- **NAT Gateway**: 1 × 730 hours + data = ~$35
- **Storage**: EBS + RDS storage = ~$10
- **Total**: ~$110/month

### Cost Saving Strategies
- Use EC2 health checks instead of ELB (implemented)
- Single NAT Gateway instead of per-AZ
- Stop dev environment during off-hours
- Reserved Instances for production
- S3 lifecycle policies for old backups

## Infrastructure as Code

### Terraform Modules

#### VPC Module (`terraform/modules/vpc`)
- VPC, subnets, route tables
- Internet Gateway, NAT Gateway
- Network ACLs, VPC endpoints

#### Security Module (`terraform/modules/security`)
- Security groups for ALB, EC2, RDS
- IAM roles and policies
- SSH key pair management

#### Compute Module (`terraform/modules/compute`)
- Launch template with user data
- Auto Scaling Group
- Scaling policies
- CloudWatch alarms

#### Load Balancer Module (`terraform/modules/loadbalancer`)
- Application Load Balancer
- Target groups
- Listener rules
- Health checks

#### Database Module (`terraform/modules/database`)
- RDS PostgreSQL instance
- Subnet group
- Parameter group
- Secrets Manager secret

### State Management
- **Backend**: S3 bucket with versioning
- **Locking**: DynamoDB table
- **Encryption**: AES-256
- **Structure**: `terraform/state/{environment}/terraform.tfstate`

## Configuration Management

### Ansible Structure

#### Inventory
- Auto-generated from Terraform outputs
- Includes EC2 IPs, RDS endpoint, ECR URLs
- Grouped by role (webservers)

#### Playbooks
- `deploy-app.yml`: Full application deployment
- `update-containers.yml`: Rolling updates
- `healthcheck.yml`: Verification

#### Roles
- `common`: Base system configuration
- `docker`: Docker and Docker Compose setup
- `app-deploy`: Pull images, start containers

## Security Best Practices

### Implemented
- ✅ Least privilege IAM roles
- ✅ Security groups with minimal access
- ✅ Database in private subnets
- ✅ SSL/TLS for database connections
- ✅ Secrets in Secrets Manager (not code)
- ✅ VPC isolation
- ✅ Multi-AZ for resilience

### Recommended Additions
- [ ] AWS WAF on ALB
- [ ] GuardDuty for threat detection
- [ ] CloudTrail for audit logs
- [ ] Secrets rotation automation
- [ ] SSL/TLS for ALB (HTTPS)
- [ ] VPC Flow Logs
- [ ] Systems Manager Session Manager (instead of SSH)

## Maintenance and Operations

### Regular Tasks
- **Weekly**: Review CloudWatch metrics and alarms
- **Monthly**: Review and update AMI versions
- **Quarterly**: Disaster recovery testing
- **Annually**: Security audit and penetration testing

### Runbooks
- Deploy new version: Run Ansible playbook
- Scale manually: Update ASG desired capacity
- Database failover: Automatic (Multi-AZ)
- Rollback: Deploy previous ECR image tag

## Future Enhancements

### Short Term
- [ ] Add SSL/TLS certificate to ALB
- [ ] Implement CloudWatch dashboards
- [ ] Add application performance monitoring
- [ ] Setup automated backups verification

### Long Term
- [ ] Multi-region deployment
- [ ] Blue/green deployments
- [ ] Canary releases
- [ ] Service mesh (Istio/App Mesh)
- [ ] Kubernetes migration (EKS)

## Interview Talking Points

When discussing this architecture:

> "I designed and implemented a highly available, multi-tier web application infrastructure on AWS using Infrastructure as Code principles. The architecture uses Terraform modules for provisioning, includes multi-AZ deployment for fault tolerance, and implements auto-scaling based on CPU metrics. Security is enforced through VPC isolation, security groups, IAM roles with least privilege, and encrypted database connections. The entire deployment is automated using shell scripts and Ansible for consistent, repeatable deployments."

**Key Technical Achievements:**
- Multi-AZ high availability architecture
- Infrastructure as Code with Terraform
- Automated deployment with Ansible
- Containerized applications with Docker
- Auto-scaling based on metrics
- Security best practices (encryption, least privilege, network isolation)
- Automated deployment scripts for repeatable infrastructure provisioning