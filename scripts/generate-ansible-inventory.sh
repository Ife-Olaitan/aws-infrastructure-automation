#!/bin/bash
set -e

# Get script directory and source common functions
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
source "$SCRIPT_DIR/common.sh"

print_header "Generate Ansible Inventory from Terraform"

# Fetch Terraform outputs (state is in S3)
cd "$PROJECT_ROOT/terraform/environments/dev"

print_info "Fetching Terraform outputs..."

# Get Auto Scaling Group name
ASG_NAME=$(terraform output -raw autoscaling_group_name 2>/dev/null)

# Get EC2 instance IPs from Auto Scaling Group
print_info "Getting EC2 instance IPs from Auto Scaling Group..."
AWS_REGION=$(terraform output -raw aws_region 2>/dev/null || echo "eu-west-2")

# Get instance IDs from ASG
INSTANCE_IDS=$(aws autoscaling describe-auto-scaling-groups \
    --auto-scaling-group-names "$ASG_NAME" \
    --region "$AWS_REGION" \
    --query "AutoScalingGroups[0].Instances[?HealthStatus=='Healthy' && LifecycleState=='InService'].InstanceId" \
    --output text 2>/dev/null)

# Check if we got instance IDs
if [ -z "$INSTANCE_IDS" ]; then
    print_error "No healthy instances found in Auto Scaling Group"
    exit 1
fi

# Get public IPs from instance IDs
EC2_IPS=$(aws ec2 describe-instances \
    --instance-ids $INSTANCE_IDS \
    --region "$AWS_REGION" \
    --query "Reservations[].Instances[].PublicIpAddress" \
    --output text 2>/dev/null)

# Get database outputs
RDS_ENDPOINT=$(terraform output -raw db_instance_endpoint 2>/dev/null)
DB_NAME=$(terraform output -raw db_instance_name 2>/dev/null)
DB_USERNAME=$(terraform output -raw db_instance_username 2>/dev/null)
DB_SECRET_ARN=$(terraform output -raw db_password_secret_arn 2>/dev/null)
DB_SECRET_NAME=$(echo "$DB_SECRET_ARN" | awk -F':' '{print $NF}' | sed 's/-[A-Za-z0-9]*$//')

# Get ECR outputs
BACKEND_ECR=$(terraform output -raw backend_ecr_repository_url 2>/dev/null)
FRONTEND_ECR=$(terraform output -raw frontend_ecr_repository_url 2>/dev/null)

# Check if we got EC2 instance IPs
if [ -z "$EC2_IPS" ]; then
    print_error "Could not get EC2 IPs from Terraform"
    exit 1
fi

# Check if we got RDS endpoint
if [ -z "$RDS_ENDPOINT" ]; then
    print_error "Could not get RDS endpoint from Terraform"
    exit 1
fi

print_success "Got all Terraform outputs"

# Generate inventory
mkdir -p "$PROJECT_ROOT/ansible/inventory"
INVENTORY_FILE="$PROJECT_ROOT/ansible/inventory/hosts.yml"

print_info "Creating inventory file..."

cat > "$INVENTORY_FILE" <<EOF
---
# Ansible Inventory - Auto-generated from Terraform
# Generated on: $(date)

all:
  children:
    webservers:
      hosts:
EOF

# Add EC2 hosts
COUNTER=1
for ip in $EC2_IPS; do
    cat >> "$INVENTORY_FILE" <<EOF
        web$COUNTER:
          ansible_host: $ip
EOF
    COUNTER=$((COUNTER + 1))
done

# Add group variables
cat >> "$INVENTORY_FILE" <<EOF

      vars:
        ansible_user: ubuntu
        ansible_ssh_private_key_file: ~/.ssh/id_rsa
        ansible_ssh_common_args: '-o StrictHostKeyChecking=no'
        aws_region: $AWS_REGION
        db_host: $RDS_ENDPOINT
        db_name: $DB_NAME
        db_username: $DB_USERNAME
        db_secret_name: $DB_SECRET_NAME
        backend_image: "$BACKEND_ECR:latest"
        frontend_image: "$FRONTEND_ECR:latest"
        backend_port: 3000
        frontend_port: 80
        docker_build_enabled: false
EOF

print_success "Inventory created at ansible/inventory/hosts.yml"

echo -e "\n${GREEN}Done!${NC}\n"