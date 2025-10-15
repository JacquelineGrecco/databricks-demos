#!/bin/bash
# Script to set up S3 backend for Terraform state management
# This ensures state persistence across GitHub Actions runs

set -e

# Configuration
STATE_BUCKET="jg-dbx-terraform-state"
STATE_TABLE="jg-dbx-terraform-locks"
AWS_REGION="us-east-1"

echo "=========================================="
echo "Setting up Terraform Remote State Backend"
echo "=========================================="
echo ""
echo "Configuration:"
echo "  S3 Bucket: ${STATE_BUCKET}"
echo "  DynamoDB Table: ${STATE_TABLE}"
echo "  Region: ${AWS_REGION}"
echo ""

# Check if AWS CLI is available
if ! command -v aws &> /dev/null; then
    echo "❌ ERROR: AWS CLI is not installed"
    exit 1
fi

# Check if AWS credentials are configured
if ! aws sts get-caller-identity &> /dev/null; then
    echo "❌ ERROR: AWS credentials are not configured"
    exit 1
fi

echo "✅ AWS credentials verified"
echo ""

# Create S3 bucket
echo "📦 Creating S3 bucket for state..."
if aws s3api head-bucket --bucket ${STATE_BUCKET} 2>/dev/null; then
    echo "   Bucket ${STATE_BUCKET} already exists"
else
    aws s3api create-bucket \
      --bucket ${STATE_BUCKET} \
      --region ${AWS_REGION} 2>/dev/null || true
    echo "   ✅ Bucket created"
fi

# Enable versioning
echo "🔄 Enabling versioning..."
aws s3api put-bucket-versioning \
  --bucket ${STATE_BUCKET} \
  --versioning-configuration Status=Enabled
echo "   ✅ Versioning enabled"

# Enable encryption
echo "🔐 Enabling encryption..."
aws s3api put-bucket-encryption \
  --bucket ${STATE_BUCKET} \
  --server-side-encryption-configuration '{
    "Rules": [{
      "ApplyServerSideEncryptionByDefault": {
        "SSEAlgorithm": "AES256"
      },
      "BucketKeyEnabled": true
    }]
  }'
echo "   ✅ Encryption enabled"

# Block public access
echo "🛡️  Blocking public access..."
aws s3api put-public-access-block \
  --bucket ${STATE_BUCKET} \
  --public-access-block-configuration \
    BlockPublicAcls=true,IgnorePublicAcls=true,BlockPublicPolicy=true,RestrictPublicBuckets=true
echo "   ✅ Public access blocked"

# Create DynamoDB table
echo "🗄️  Creating DynamoDB table for state locking..."
if aws dynamodb describe-table --table-name ${STATE_TABLE} --region ${AWS_REGION} &> /dev/null; then
    echo "   Table ${STATE_TABLE} already exists"
else
    aws dynamodb create-table \
      --table-name ${STATE_TABLE} \
      --attribute-definitions AttributeName=LockID,AttributeType=S \
      --key-schema AttributeName=LockID,KeyType=HASH \
      --billing-mode PAY_PER_REQUEST \
      --region ${AWS_REGION} \
      --tags Key=Project,Value=databricks-terraform Key=ManagedBy,Value=terraform > /dev/null
    
    echo "   ⏳ Waiting for table to be active..."
    aws dynamodb wait table-exists --table-name ${STATE_TABLE} --region ${AWS_REGION}
    echo "   ✅ Table created"
fi

# Enable point-in-time recovery
echo "💾 Enabling point-in-time recovery..."
aws dynamodb update-continuous-backups \
  --table-name ${STATE_TABLE} \
  --point-in-time-recovery-specification PointInTimeRecoveryEnabled=true \
  --region ${AWS_REGION} > /dev/null
echo "   ✅ Point-in-time recovery enabled"

echo ""
echo "=========================================="
echo "✅ Remote State Backend Setup Complete!"
echo "=========================================="
echo ""
echo "Next steps:"
echo "1. Create backend.tf file (or it may already exist)"
echo "2. Run: terraform init -reconfigure"
echo "3. Terraform will now use S3 for state storage"
echo ""
echo "Backend configuration:"
echo "---"
echo "terraform {"
echo "  backend \"s3\" {"
echo "    bucket         = \"${STATE_BUCKET}\""
echo "    key            = \"databricks/pl-cmk/terraform.tfstate\""
echo "    region         = \"${AWS_REGION}\""
echo "    encrypt        = true"
echo "    dynamodb_table = \"${STATE_TABLE}\""
echo "  }"
echo "}"
echo "---"
echo ""
echo "Cost estimate:"
echo "  - S3 bucket: ~$0.023/GB/month (minimal for state files)"
echo "  - DynamoDB: Pay-per-request (minimal for locking)"
echo "  - Total: < $1/month for typical usage"
echo ""


