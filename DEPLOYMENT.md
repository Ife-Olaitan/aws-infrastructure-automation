# Deployment Guide

This guide explains how to deploy the AWS infrastructure with proper S3 backend for Terraform state.

## Architecture

- **Terraform**: Infrastructure as Code (VPC, EC2, RDS, ALB, ECR)
- **Docker**: Application containerization
- **Ansible**: Server configuration and app deployment
- **S3 + DynamoDB**: Terraform state storage and locking

---

## Prerequisites

Install these tools:
- AWS CLI
- Terraform
- Ansible
- Docker

Configure AWS credentials:
```bash
aws configure
```

---

## One-Time Setup: Terraform Backend

Before first deployment, create the S3 bucket and DynamoDB table for Terraform state:

```bash
./scripts/setup-terraform-backend.sh
```

This creates:
- **S3 Bucket**: `aws-infra-automation-tfstate`
  - Versioning enabled
  - Encryption enabled
  - Public access blocked
- **DynamoDB Table**: `terraform-state-lock`
  - Used for state locking
  - Prevents concurrent modifications

**You only need to run this ONCE.**

---

## Deployment

### Full Deployment (One Command)

```bash
./scripts/deploy.sh
```

This will:
1. **Deploy Infrastructure** (Terraform)
   - Creates VPC, subnets, security groups
   - Creates ECR repositories
   - Creates RDS database
   - Creates EC2 Auto Scaling Group
   - Creates Application Load Balancer
   - Stores state in S3

2. **Build and Push Images** (Docker + ECR)
   - Builds backend Docker image
   - Builds frontend Docker image
   - Pushes both to ECR

3. **Generate Inventory** (Terraform → Ansible)
   - Gets EC2 IPs from Terraform
   - Gets RDS endpoint
   - Creates Ansible inventory file

4. **Deploy Application** (Ansible)
   - Installs Docker on EC2
   - Configures security (firewall, SSH)
   - Sets up CloudWatch monitoring
   - Deploys application containers

---

## Teardown

To destroy all infrastructure:

```bash
./scripts/destroy.sh
```

**Warning**: This will:
- Delete all EC2 instances
- Delete RDS database (all data lost!)
- Delete Load Balancer
- Delete VPC and networking
- Delete ECR repositories and images

The Terraform state in S3 will remain (safe to keep).

---

## Manual Steps (If Needed)

### Individual Scripts

If you need to run steps separately:

```bash
# 1. Build and push images (requires ECR to exist)
./scripts/build-and-push-to-ecr.sh

# 2. Generate Ansible inventory (requires Terraform outputs)
./scripts/generate-ansible-inventory.sh

# 3. Deploy with Ansible (requires inventory)
cd ansible
ansible-playbook -i inventory/hosts.yml playbooks/deploy.yml
```

### Terraform Only

```bash
cd terraform
terraform init
terraform plan
terraform apply
```

---

## Terraform State

### State Location
- **Remote**: S3 bucket `aws-infra-automation-tfstate`
- **Lock**: DynamoDB table `terraform-state-lock`
- **Region**: eu-west-2

### Why S3 + DynamoDB?
- **S3**: Stores the state file remotely (team collaboration)
- **DynamoDB**: Prevents concurrent modifications (state locking)
- **Versioning**: S3 versioning enabled (can recover from mistakes)
- **Encryption**: State is encrypted at rest

### Migrating Existing State

If you already have local state, Terraform will ask to migrate it to S3 on first run:

```
Do you want to copy existing state to the new backend? (yes/no)
```

Answer `yes` to migrate.

---

## Troubleshooting

### "Bucket does not exist"
Run the setup script:
```bash
./scripts/setup-terraform-backend.sh
```

### "Error locking state"
Someone else is running Terraform. Wait for them to finish, or:
```bash
# Remove the lock (use with caution!)
cd terraform
terraform force-unlock <LOCK_ID>
```

### "ECR repository not found"
Run deploy.sh instead of build-and-push-to-ecr.sh directly.
The infrastructure (ECR) must be created first.

### "No instances found"
Wait longer for instances to be created, or check AWS Console.

---

## Cost Estimate

Approximate monthly costs (eu-west-2):
- **EC2**: ~$20-40 (t3.micro instances)
- **RDS**: ~$20-30 (db.t3.micro)
- **ALB**: ~$20
- **S3**: <$1 (just state file)
- **DynamoDB**: <$1 (on-demand)

**Total**: ~$60-90/month

Remember to run `./scripts/destroy.sh` when done to avoid charges!

---

## Project Structure

```
aws-infrastructure-automation/
├── terraform/
│   ├── backend.tf           # S3 backend configuration
│   ├── main.tf              # Main infrastructure
│   └── modules/             # Reusable modules
├── ansible/
│   ├── playbooks/
│   │   └── deploy.yml       # Main deployment playbook
│   └── roles/               # Docker, security, monitoring, app-deploy
├── scripts/
│   ├── setup-terraform-backend.sh  # One-time setup
│   ├── deploy.sh                   # Main deployment
│   ├── destroy.sh                  # Teardown
│   ├── build-and-push-to-ecr.sh   # Docker image build
│   ├── generate-ansible-inventory.sh  # Inventory generation
│   └── common.sh                   # Shared functions
└── DEPLOYMENT.md            # This file
```

---

## Next Steps

After successful deployment:
1. Wait 2-3 minutes for ALB health checks
2. Visit your application at the URL shown
3. Check CloudWatch for metrics
4. Review logs in CloudWatch Logs
5. Test auto-scaling by generating load

Happy deploying! 🚀
