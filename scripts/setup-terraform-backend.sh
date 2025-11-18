#!/bin/bash
set -e

# Get script directory and source common functions
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/common.sh"

print_header "Setup Terraform Backend (S3 + DynamoDB)"

# Configuration
BUCKET_NAME="aws-infra-automation-tfstate"
DYNAMODB_TABLE="terraform-state-lock"
AWS_REGION="eu-west-2"

echo -e "${BLUE}This will create:${NC}"
echo "  • S3 Bucket: $BUCKET_NAME"
echo "  • DynamoDB Table: $DYNAMODB_TABLE"
echo "  • Region: $AWS_REGION"
echo ""

read -p "Continue? (yes/no): " confirm

# Exit if user doesn't confirm
if [ "$confirm" != "yes" ]; then
    print_warning "Setup cancelled"
    exit 0
fi

# Check if AWS CLI is configured
if ! aws sts get-caller-identity >/dev/null 2>&1; then
    print_error "AWS credentials not configured"
    exit 1
fi

# Create S3 bucket
print_info "Creating S3 bucket: $BUCKET_NAME..."

if aws s3 ls "s3://$BUCKET_NAME" 2>/dev/null; then
    print_warning "S3 bucket already exists"
else
    aws s3 mb "s3://$BUCKET_NAME" --region "$AWS_REGION"
    print_success "S3 bucket created"
fi

# Enable versioning on S3 bucket
print_info "Enabling versioning on S3 bucket..."
aws s3api put-bucket-versioning \
    --bucket "$BUCKET_NAME" \
    --versioning-configuration Status=Enabled
print_success "Versioning enabled"

# Enable encryption on S3 bucket
print_info "Enabling encryption on S3 bucket..."
aws s3api put-bucket-encryption \
    --bucket "$BUCKET_NAME" \
    --server-side-encryption-configuration '{
        "Rules": [{
            "ApplyServerSideEncryptionByDefault": {
                "SSEAlgorithm": "AES256"
            }
        }]
    }'
print_success "Encryption enabled"

# Block public access
print_info "Blocking public access to S3 bucket..."
aws s3api put-public-access-block \
    --bucket "$BUCKET_NAME" \
    --public-access-block-configuration \
        "BlockPublicAcls=true,IgnorePublicAcls=true,BlockPublicPolicy=true,RestrictPublicBuckets=true"
print_success "Public access blocked"

# Create DynamoDB table
print_info "Creating DynamoDB table: $DYNAMODB_TABLE..."

if aws dynamodb describe-table --table-name "$DYNAMODB_TABLE" --region "$AWS_REGION" >/dev/null 2>&1; then
    print_warning "DynamoDB table already exists"
else
    aws dynamodb create-table \
        --table-name "$DYNAMODB_TABLE" \
        --attribute-definitions AttributeName=LockID,AttributeType=S \
        --key-schema AttributeName=LockID,KeyType=HASH \
        --billing-mode PAY_PER_REQUEST \
        --region "$AWS_REGION" \
        >/dev/null

    print_info "Waiting for table to be active..."
    aws dynamodb wait table-exists --table-name "$DYNAMODB_TABLE" --region "$AWS_REGION"
    print_success "DynamoDB table created"
fi

# Summary
print_header "Setup Complete"

echo -e "${GREEN}Terraform backend resources created!${NC}\n"
echo -e "${BLUE}S3 Bucket:${NC}"
echo "  Name: $BUCKET_NAME"
echo "  Region: $AWS_REGION"
echo "  Versioning: Enabled"
echo "  Encryption: Enabled"
echo ""
echo -e "${BLUE}DynamoDB Table:${NC}"
echo "  Name: $DYNAMODB_TABLE"
echo "  Region: $AWS_REGION"
echo "  Billing: Pay-per-request"
echo ""
echo -e "${BLUE}Next Steps:${NC}"
echo "  1. Terraform backend configuration will be added to your project"
echo "  2. Run: ./scripts/deploy.sh"
echo ""
