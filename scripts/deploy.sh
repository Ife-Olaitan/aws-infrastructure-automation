#!/bin/bash
set -e

# Get script directory and source common functions
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
source "$SCRIPT_DIR/common.sh"

print_header "AWS Infrastructure Deployment"

# Check prerequisites
print_info "Checking prerequisites..."

# Check if AWS CLI is installed
if ! command -v aws; then
    print_error "AWS CLI not installed"
    exit 1
fi

# Check if Terraform is installed
if ! command -v terraform; then
    print_error "Terraform not installed"
    exit 1
fi

# Check if Ansible is installed
if ! command -v ansible-playbook; then
    print_error "Ansible not installed"
    exit 1
fi

# Check if Docker is installed
if ! command -v docker; then
    print_error "Docker not installed"
    exit 1
fi

# Check if Docker daemon is running
if ! docker info >/dev/null 2>&1; then
    print_error "Docker not running"
    exit 1
fi

# Check if AWS credentials are configured
if ! aws sts get-caller-identity >/dev/null 2>&1; then
    print_error "AWS not configured"
    exit 1
fi

print_success "All prerequisites OK"

# Step 1: Deploy infrastructure with Terraform (creates ECR first)
echo ""
print_info "[Step 1/4] Deploying infrastructure with Terraform..."
cd "$PROJECT_ROOT/terraform/environments/dev"

# Initialize Terraform if not already done
if [ ! -d ".terraform" ]; then
    print_info "Initializing Terraform..."
    terraform init
else
    # Reconfigure backend in case it changed
    print_info "Reconfiguring Terraform backend..."
    terraform init -reconfigure
fi

terraform plan -out=tfplan
echo ""
read -p "Apply this plan? (yes/no): " confirm

# Exit if user doesn't confirm
if [ "$confirm" != "yes" ]; then
    print_warning "Deployment cancelled"
    rm -f tfplan
    exit 0
fi

terraform apply tfplan
rm -f tfplan
print_success "Infrastructure deployed"

# Step 2: Build and push Docker images (now ECR exists)
echo ""
print_info "[Step 2/4] Building and pushing Docker images..."
bash "$SCRIPT_DIR/build-and-push-to-ecr.sh"

# Step 3: Generate Ansible inventory
echo ""
print_info "[Step 3/4] Generating Ansible inventory..."
bash "$SCRIPT_DIR/generate-ansible-inventory.sh"

# Step 4: Deploy application
echo ""
print_info "[Step 4/4] Deploying application..."
print_info "Waiting for instances to be ready (90 seconds)..."
sleep 90

cd "$PROJECT_ROOT/ansible"
ansible-playbook -i inventory/hosts.yml playbooks/deploy.yml

# Summary
ALB_DNS=$(cd "$PROJECT_ROOT/terraform/environments/dev" && terraform output -raw alb_dns_name 2>/dev/null)

print_header "Deployment Complete"

echo -e "${GREEN}Successfully deployed!${NC}\n"
echo -e "${BLUE}Application URLs:${NC}"
echo "  Frontend: http://$ALB_DNS"
echo "  Backend:  http://$ALB_DNS/api/health"
echo ""
echo -e "${YELLOW}Note:${NC} Wait 2-3 minutes for health checks to pass"
echo ""
echo -e "${BLUE}To destroy:${NC} ./scripts/destroy.sh"
echo ""
