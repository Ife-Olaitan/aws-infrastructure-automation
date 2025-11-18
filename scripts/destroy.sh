#!/bin/bash
set -e

# Get script directory and source common functions
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
source "$SCRIPT_DIR/common.sh"

print_header "Destroy AWS Infrastructure"

# Show what will be destroyed
cd "$PROJECT_ROOT/terraform/environments/dev"

# Check if there's anything to destroy (try to get state from S3)
if ! terraform state list >/dev/null 2>&1; then
    print_warning "No infrastructure found to destroy"
    exit 0
fi

print_info "Running terraform plan..."
echo ""
terraform plan -destroy

# Warning and confirmation
echo ""
print_warning "This will destroy ALL infrastructure including:"
echo "  • EC2 instances and Auto Scaling Group"
echo "  • RDS database (all data will be LOST)"
echo "  • Load Balancer"
echo "  • VPC and networking resources"
echo "  • Security Groups"
echo "  • IAM roles and policies"
echo "  • ECR repositories and Docker images"
echo "  • Secrets Manager secrets"
echo ""

read -p "Type 'destroy' to confirm: " confirm

# Exit if user doesn't type 'destroy' exactly
if [ "$confirm" != "destroy" ]; then
    print_warning "Destroy cancelled"
    exit 0
fi

# Destroy infrastructure
echo ""
print_info "Destroying infrastructure..."
terraform destroy -auto-approve

print_success "Infrastructure destroyed"

# Clean up local files
echo ""
read -p "Clean up local generated files? (yes/no): " cleanup

# Remove generated files if user confirms
if [ "$cleanup" == "yes" ]; then
    echo ""
    print_info "Cleaning up local files..."
    rm -f "$PROJECT_ROOT/terraform/terraform.tfstate.backup"
    rm -f "$PROJECT_ROOT/terraform/.terraform.lock.hcl"
    rm -f "$PROJECT_ROOT/ansible/inventory/hosts.yml"
    print_success "Local files cleaned"
fi

# Summary
print_header "Destroy Complete"

echo -e "${GREEN}Infrastructure destroyed successfully!${NC}\n"
echo -e "${BLUE}What was removed:${NC}"
echo "  ✓ All AWS infrastructure"
echo "  ✓ ECR repositories and images"
echo "  ✓ Database and all data"
echo ""
echo -e "${BLUE}To deploy again:${NC} ./scripts/deploy.sh"
echo ""