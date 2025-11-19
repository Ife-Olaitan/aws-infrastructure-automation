# Deployment Guide

Complete guide for deploying the AWS infrastructure and application from scratch.

---

## Table of Contents

1. [Prerequisites](#prerequisites)
2. [Initial Setup](#initial-setup)
3. [Deployment Steps](#deployment-steps)
4. [Verification](#verification)
5. [Troubleshooting](#troubleshooting)
6. [Updating the Application](#updating-the-application)
7. [Destroying Infrastructure](#destroying-infrastructure)

---

## Prerequisites

### Required Tools

Install these tools before starting:

```bash
# Terraform (v1.0+)
brew install terraform

# AWS CLI (v2)
brew install awscli

# Ansible (v2.9+)
brew install ansible

# Docker
brew install docker

# jq (for JSON parsing)
brew install jq
```

### AWS Account Setup

1. **AWS Account**: Active AWS account with admin access
2. **AWS CLI Configuration**:
   ```bash
   aws configure
   # Enter your Access Key ID
   # Enter your Secret Access Key
   # Default region: eu-west-2
   # Default output: json
   ```

3. **Verify AWS Access**:
   ```bash
   aws sts get-caller-identity
   ```

### SSH Key Pair

Generate an SSH key for EC2 access:

```bash
# Generate key pair
ssh-keygen -t rsa -b 4096 -f ~/.ssh/aws-infrastructure-key -N ""

# Set correct permissions
chmod 400 ~/.ssh/aws-infrastructure-key
```

---

## Initial Setup

### Step 1: Clone Repository

```bash
git clone <your-repo-url>
cd aws-infrastructure-automation
```

### Step 2: Setup Terraform Backend

The Terraform backend uses S3 for state storage and DynamoDB for state locking.

```bash
# Run the setup script
./scripts/setup-terraform-backend.sh

# This creates:
# - S3 bucket: terraform-state-<account-id>
# - DynamoDB table: terraform-state-lock
# - ECR repositories: dev-backend, dev-frontend
```

**Expected Output:**
```
✅ S3 bucket created: terraform-state-897722663141
✅ DynamoDB table created: terraform-state-lock
✅ ECR repository created: dev-backend
✅ ECR repository created: dev-frontend
```

### Step 3: Configure Variables

Edit the environment-specific variables:

```bash
cd terraform/environments/dev
vi terraform.tfvars  # or use your preferred editor
```

**Key variables to set:**
```hcl
environment         = "dev"
aws_region         = "eu-west-2"
vpc_cidr           = "10.0.0.0/16"
instance_type      = "t3.micro"
db_instance_class  = "db.t3.micro"
db_username        = "dbadmin"
db_name            = "appdb"
ssh_public_key_path = "~/.ssh/aws-infrastructure-key.pub"

# Optional: Restrict SSH access to your IP
admin_ip           = "<YOUR_IP>/32"  # Get with: curl ifconfig.me
```

---

## Deployment Steps

### Option A: Automated Deployment (Recommended)

Use the deployment script for one-command deployment:

```bash
# From project root
./scripts/deploy.sh
```

**What it does:**
1. Builds Docker images for AMD64 architecture
2. Pushes images to ECR
3. Runs Terraform to provision infrastructure
4. Generates Ansible inventory from Terraform outputs
5. Waits for EC2 instances to be ready
6. Runs Ansible playbook to deploy containers
7. Verifies deployment health

**Expected Duration:** 10-15 minutes

---

### Option B: Manual Step-by-Step Deployment

For learning or troubleshooting, deploy manually:

#### 1. Build and Push Docker Images

```bash
# Build images with AMD64 platform (important for EC2 compatibility)
cd docker/backend
docker build --platform linux/amd64 -t backend:latest .

cd ../frontend
docker build --platform linux/amd64 -t frontend:latest .

# Get ECR repository URLs
BACKEND_ECR=$(aws ecr describe-repositories --repository-names dev-backend --query 'repositories[0].repositoryUri' --output text)
FRONTEND_ECR=$(aws ecr describe-repositories --repository-names dev-frontend --query 'repositories[0].repositoryUri' --output text)

# Login to ECR
aws ecr get-login-password --region eu-west-2 | docker login --username AWS --password-stdin $BACKEND_ECR

# Tag and push
docker tag backend:latest $BACKEND_ECR:latest
docker tag frontend:latest $FRONTEND_ECR:latest
docker push $BACKEND_ECR:latest
docker push $FRONTEND_ECR:latest
```

#### 2. Initialize Terraform

```bash
cd terraform/environments/dev

# Initialize Terraform (downloads providers, sets up backend)
terraform init

# Validate configuration
terraform validate

# Format configuration files
terraform fmt -recursive
```

#### 3. Plan Infrastructure Changes

```bash
# Generate execution plan
terraform plan -out=tfplan

# Review the plan - should create ~30-40 resources
```

**Resources created:**
- VPC with subnets, route tables, gateways
- Security groups for ALB, EC2, RDS
- IAM roles and policies
- Application Load Balancer with target groups
- Auto Scaling Group with launch template
- RDS PostgreSQL instance
- Secrets Manager secret
- CloudWatch alarms

#### 4. Apply Infrastructure

```bash
# Apply the plan
terraform apply tfplan

# This takes ~10 minutes (RDS is the slowest)
```

**Expected Output:**
```
Apply complete! Resources: 38 added, 0 changed, 0 destroyed.

Outputs:
alb_dns_name = "dev-alb-123456789.eu-west-2.elb.amazonaws.com"
asg_name = "dev-asg-20231120123456"
...
```

#### 5. Generate Ansible Inventory

```bash
# From project root
./scripts/generate-ansible-inventory.sh

# This creates ansible/inventory/hosts.yml with:
# - EC2 instance IPs
# - RDS endpoint
# - ECR URLs
# - AWS region
```

**Verify inventory:**
```bash
cat ansible/inventory/hosts.yml
```

#### 6. Wait for EC2 Instances

```bash
# Get ASG name from Terraform output
ASG_NAME=$(cd terraform/environments/dev && terraform output -raw asg_name)

# Wait for instances to be healthy
echo "Waiting for EC2 instances to be ready..."
while true; do
  COUNT=$(aws autoscaling describe-auto-scaling-groups \
    --auto-scaling-group-names $ASG_NAME \
    --query "AutoScalingGroups[0].Instances[?HealthStatus=='Healthy' && LifecycleState=='InService'] | length(@)" \
    --output text)

  echo "Healthy instances: $COUNT/2"
  [ "$COUNT" -ge 2 ] && break
  sleep 10
done

echo "✅ EC2 instances are ready"
```

#### 7. Deploy Application with Ansible

```bash
cd ansible

# Test connectivity
ansible webservers -i inventory/hosts.yml -m ping

# Deploy application
ansible-playbook -i inventory/hosts.yml playbooks/deploy.yml

# Use -v for verbose output if needed
ansible-playbook -i inventory/hosts.yml playbooks/deploy.yml -v
```

**What Ansible does:**
1. Installs Docker (if not already installed from user-data)
2. Configures security (UFW firewall, SSH hardening)
3. Installs and configures CloudWatch agent
4. Authenticates with ECR
5. Pulls Docker images
6. Fetches database password from Secrets Manager
7. Creates environment configuration
8. Starts frontend and backend containers
9. Verifies containers are running and healthy

---

## Verification

### 1. Check Infrastructure

```bash
cd terraform/environments/dev

# Get ALB DNS name
terraform output alb_dns_name

# Check all outputs
terraform output
```

### 2. Verify Containers

SSH into an EC2 instance:

```bash
# Get instance IP from inventory
INSTANCE_IP=$(cat ansible/inventory/hosts.yml | grep ansible_host | head -1 | awk '{print $2}')

# SSH into instance
ssh -i ~/.ssh/aws-infrastructure-key ubuntu@$INSTANCE_IP

# Check Docker containers
sudo docker ps

# Check container logs
sudo docker logs backend
sudo docker logs frontend

# Check backend health
curl http://localhost:3000/health

# Exit SSH
exit
```

**Expected containers:**
```
CONTAINER ID   IMAGE                                    PORTS                    STATUS
abc123def456   <ECR>/dev-backend:latest                0.0.0.0:3000->3000/tcp   Up
def456abc789   <ECR>/dev-frontend:latest               0.0.0.0:80->80/tcp       Up
```

### 3. Test Application Endpoints

Get the ALB DNS name:

```bash
ALB_DNS=$(cd terraform/environments/dev && terraform output -raw alb_dns_name)
echo $ALB_DNS
```

Test the application:

```bash
# Frontend (HTML page)
curl http://$ALB_DNS/

# Backend health check
curl http://$ALB_DNS/api/health

# Backend API - get users
curl http://$ALB_DNS/api/users

# Backend API - create user
curl -X POST http://$ALB_DNS/api/users \
  -H "Content-Type: application/json" \
  -d '{"username": "testuser", "email": "test@example.com"}'
```

**Expected responses:**
- Frontend: HTML content
- `/api/health`: `{"status": "healthy", "database": "connected", ...}`
- `/api/users`: JSON array of users
- POST: `{"message": "User created", "user": {...}}`

### 4. Check ALB Target Health

```bash
# Get target group ARN
TG_ARN=$(aws elbv2 describe-target-groups \
  --names dev-backend-tg \
  --query 'TargetGroups[0].TargetGroupArn' \
  --output text)

# Check target health
aws elbv2 describe-target-health --target-group-arn $TG_ARN
```

**Expected output:**
```json
{
    "TargetHealthDescriptions": [
        {
            "Target": {"Id": "i-1234567890abcdef0", "Port": 3000},
            "HealthCheckPort": "3000",
            "TargetHealth": {"State": "healthy"}
        }
    ]
}
```

### 5. Open in Browser

```bash
# Print the URL
echo "Frontend: http://$ALB_DNS"
echo "Backend API: http://$ALB_DNS/api/health"
echo "Users endpoint: http://$ALB_DNS/api/users"
```

Open these URLs in your browser to verify the application is working.

---

## Troubleshooting

### Issue 1: Docker Images Wrong Architecture

**Error:** `exec format error` in container logs

**Cause:** Images built on ARM Mac but EC2 is AMD64

**Fix:**
```bash
# Always build with --platform flag
docker build --platform linux/amd64 -t backend:latest .
```

---

### Issue 2: Database Connection Failed

**Error:** `no pg_hba.conf entry for host`

**Cause:** RDS requires SSL connections

**Fix:** Already implemented in `docker/backend/server.js`:
```javascript
ssl: {
    rejectUnauthorized: false
}
```

---

### Issue 3: Permission Denied - Secrets Manager

**Error:** `User is not authorized to perform: secretsmanager:GetSecretValue`

**Cause:** EC2 IAM role missing permissions

**Fix:** Already implemented in `terraform/modules/security/main.tf`

Verify:
```bash
# Check role policies
aws iam list-attached-role-policies --role-name dev-ec2-role
```

---

### Issue 4: Unhealthy Targets

**Error:** Targets showing "unhealthy" in target group

**Possible causes:**

1. **Wrong port in security group**
   - Check security group allows ports 80 and 3000 from ALB
   - Fix: Already implemented in terraform/modules/security/main.tf

2. **Container not running**
   ```bash
   ssh ubuntu@<instance-ip>
   sudo docker ps
   sudo docker logs backend
   ```

3. **Health check endpoint failing**
   ```bash
   curl http://localhost:3000/health
   ```

---

### Issue 5: Can't SSH to EC2

**Error:** Connection timeout

**Fix:**
```bash
# Verify security group allows SSH from your IP
aws ec2 describe-security-groups \
  --group-ids <sg-id> \
  --query 'SecurityGroups[0].IpPermissions[?FromPort==`22`]'

# Update admin_ip in terraform.tfvars to your current IP
curl ifconfig.me
```

---

### Issue 6: Database Schema Missing

**Error:** `relation "users" does not exist`

**Cause:** Fresh database has no schema

**Fix:** Already automated in `docker/backend/init-db.js` - runs on container start

---

### Issue 7: ECR Authentication Failed

**Error:** `pull access denied, repository does not exist`

**Cause:** Docker not authenticated to ECR

**Fix:** Already implemented in Ansible - adds ECR login step

Manual fix:
```bash
aws ecr get-login-password --region eu-west-2 | \
  docker login --username AWS --password-stdin <account-id>.dkr.ecr.eu-west-2.amazonaws.com
```

---

### Issue 8: Secrets Already Scheduled for Deletion

**Error:** `secret with this name is already scheduled for deletion`

**Cause:** Previous deployment scheduled secret for 30-day deletion

**Fix:**
```bash
# Force delete immediately
aws secretsmanager delete-secret \
  --secret-id dev-db-password \
  --force-delete-without-recovery \
  --region eu-west-2
```

---

## Updating the Application

### Update Code Only (Fast)

When you only change application code (not infrastructure):

```bash
# 1. Build and push new images
./scripts/build-and-push-to-ecr.sh

# 2. Redeploy containers on EC2 instances
cd ansible
ansible-playbook -i inventory/hosts.yml playbooks/deploy.yml
```

**This will:**
- Pull latest images from ECR
- Restart containers with new images
- Verify health checks

---

### Update Infrastructure

When you change Terraform configuration:

```bash
cd terraform/environments/dev

# Plan changes
terraform plan -out=tfplan

# Review and apply
terraform apply tfplan

# Regenerate inventory if outputs changed
cd ../../..
./scripts/generate-ansible-inventory.sh

# Redeploy application if needed
cd ansible
ansible-playbook -i inventory/hosts.yml playbooks/deploy.yml
```

---

### Full Redeployment

For major changes or troubleshooting:

```bash
# Destroy everything
./scripts/destroy.sh

# Redeploy from scratch
./scripts/deploy.sh
```

**Note:** This destroys the database - all data will be lost!

---

## Destroying Infrastructure

### Automated Destruction

```bash
# From project root
./scripts/destroy.sh
```

**What it does:**
1. Runs `terraform destroy`
2. Force deletes Secrets Manager secret
3. Optionally deletes ECR repositories

**Expected Duration:** 5-10 minutes

---

### Manual Destruction

```bash
cd terraform/environments/dev

# Plan destruction
terraform plan -destroy -out=tfplan-destroy

# Review what will be deleted
terraform show tfplan-destroy

# Destroy infrastructure
terraform destroy

# Clean up secrets (optional)
aws secretsmanager delete-secret \
  --secret-id dev-db-password \
  --force-delete-without-recovery \
  --region eu-west-2

# Delete ECR images (optional)
aws ecr batch-delete-image \
  --repository-name dev-backend \
  --image-ids imageTag=latest

aws ecr batch-delete-image \
  --repository-name dev-frontend \
  --image-ids imageTag=latest
```

---

## Best Practices

### Security
- ✅ Never commit credentials or `.tfvars` files
- ✅ Use Secrets Manager for database passwords
- ✅ Restrict SSH access to specific IPs
- ✅ Enable SSL/TLS for production databases
- ✅ Use IAM roles instead of access keys on EC2
- ✅ Rotate secrets regularly
- ✅ Review security group rules periodically

### Cost Management
- ✅ Use `t3.micro` for dev environments
- ✅ Destroy dev infrastructure when not in use
- ✅ Monitor AWS billing dashboard
- ✅ Set up billing alarms
- ✅ Use single NAT Gateway for dev
- ✅ Delete old ECR images

### Operations
- ✅ Tag all resources with environment
- ✅ Use descriptive commit messages
- ✅ Document infrastructure changes
- ✅ Test in dev before production
- ✅ Keep Terraform state in S3
- ✅ Regular backups of production data

---

## Next Steps

After successful deployment:

1. **Add Monitoring**: CloudWatch dashboards and alarms
2. **Add SSL/TLS**: Configure ACM certificate for ALB
3. **Implement Backups**: Automated RDS snapshot testing
4. **Add Testing**: Integration and load testing
5. **Production Setup**: Separate environment with larger instances
6. **Setup CI/CD**: Implement GitHub Actions for automated deployments (optional)

---

## Useful Commands Reference

```bash
# Check Terraform state
terraform state list
terraform state show <resource>

# Get specific output
terraform output -raw alb_dns_name

# Check AWS resources
aws ec2 describe-instances --filters "Name=tag:Environment,Values=dev"
aws elbv2 describe-load-balancers
aws rds describe-db-instances
aws autoscaling describe-auto-scaling-groups

# Ansible commands
ansible webservers -i inventory/hosts.yml -m ping
ansible webservers -i inventory/hosts.yml -a "uptime"
ansible-playbook --syntax-check playbooks/deploy.yml

# Docker commands on EC2
sudo docker ps
sudo docker logs backend
sudo docker logs frontend
sudo docker stats
sudo docker exec -it backend /bin/sh
```

---

**Key Achievements:**
- One-command deployment automation
- Infrastructure as Code with Terraform
- Configuration management with Ansible
- Multi-platform Docker builds
- Comprehensive troubleshooting documentation
- Production-ready security practices