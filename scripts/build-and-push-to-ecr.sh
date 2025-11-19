#!/bin/bash
set -e

# Get script directory and source common functions
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
source "$SCRIPT_DIR/common.sh"

print_header "Build and Push Docker Images to ECR"

# Check prerequisites
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

# Get ECR URLs from Terraform
cd "$PROJECT_ROOT/terraform/environments/dev"

# Get outputs from Terraform (state is in S3)
BACKEND_ECR=$(terraform output -raw backend_ecr_repository_url 2>/dev/null)
FRONTEND_ECR=$(terraform output -raw frontend_ecr_repository_url 2>/dev/null)
AWS_REGION=$(terraform output -raw aws_region 2>/dev/null || echo "eu-west-2")

# Check if we got the ECR URLs from Terraform
if [ -z "$BACKEND_ECR" ]; then
    print_error "Could not get ECR URLs from Terraform. Run 'terraform apply' first."
    exit 1
fi

print_success "Got ECR URLs from Terraform"

# Login to ECR
print_info "Logging in to ECR..."
aws ecr get-login-password --region "$AWS_REGION" | \
    docker login --username AWS --password-stdin "${BACKEND_ECR%%/*}" >/dev/null 2>&1
print_success "Authenticated with ECR"

# Build and push backend image
print_info "Building backend image..."
cd "$PROJECT_ROOT/docker/backend"

if [ ! -f "Dockerfile" ]; then
    print_error "Backend Dockerfile not found"
    exit 1
fi

docker build --platform linux/amd64 -t backend:latest . >/dev/null 2>&1
docker tag backend:latest "$BACKEND_ECR:latest"
docker push "$BACKEND_ECR:latest" >/dev/null 2>&1
print_success "Backend image pushed to ECR"

# Build and push frontend image
print_info "Building frontend image..."
cd "$PROJECT_ROOT/docker/frontend"

if [ ! -f "Dockerfile" ]; then
    print_error "Frontend Dockerfile not found"
    exit 1
fi

docker build --platform linux/amd64 -t frontend:latest . >/dev/null 2>&1
docker tag frontend:latest "$FRONTEND_ECR:latest"
docker push "$FRONTEND_ECR:latest" >/dev/null 2>&1
print_success "Frontend image pushed to ECR"

echo -e "\n${GREEN}Done!${NC}\n"
