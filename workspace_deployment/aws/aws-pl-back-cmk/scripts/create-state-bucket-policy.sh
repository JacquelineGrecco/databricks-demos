#!/bin/bash
# Script to create a secure bucket policy for Terraform state bucket
# Restricts access to specific AWS account and IAM roles/users

set -e

STATE_BUCKET="jg-dbx-terraform-state"
AWS_ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
AWS_REGION="us-east-1"

echo "=========================================="
echo "Creating Secure Bucket Policy"
echo "=========================================="
echo ""
echo "Configuration:"
echo "  Bucket: ${STATE_BUCKET}"
echo "  Account: ${AWS_ACCOUNT_ID}"
echo "  Region: ${AWS_REGION}"
echo ""

# Create bucket policy that allows access only from your AWS account
POLICY=$(cat <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "AllowRootAccountFullAccess",
      "Effect": "Allow",
      "Principal": {
        "AWS": "arn:aws:iam::${AWS_ACCOUNT_ID}:root"
      },
      "Action": "s3:*",
      "Resource": [
        "arn:aws:s3:::${STATE_BUCKET}",
        "arn:aws:s3:::${STATE_BUCKET}/*"
      ]
    },
    {
      "Sid": "DenyInsecureTransport",
      "Effect": "Deny",
      "Principal": "*",
      "Action": "s3:*",
      "Resource": [
        "arn:aws:s3:::${STATE_BUCKET}",
        "arn:aws:s3:::${STATE_BUCKET}/*"
      ],
      "Condition": {
        "Bool": {
          "aws:SecureTransport": "false"
        }
      }
    },
    {
      "Sid": "DenyUnencryptedObjectUploads",
      "Effect": "Deny",
      "Principal": "*",
      "Action": "s3:PutObject",
      "Resource": "arn:aws:s3:::${STATE_BUCKET}/*",
      "Condition": {
        "StringNotEquals": {
          "s3:x-amz-server-side-encryption": "AES256"
        }
      }
    }
  ]
}
EOF
)

echo "📝 Generated bucket policy:"
echo "$POLICY" | jq '.'
echo ""

# Apply the policy
echo "🔐 Applying bucket policy..."
echo "$POLICY" | aws s3api put-bucket-policy \
  --bucket ${STATE_BUCKET} \
  --policy file:///dev/stdin

echo "   ✅ Bucket policy applied"
echo ""

# Verify the policy
echo "🔍 Verifying bucket policy..."
aws s3api get-bucket-policy --bucket ${STATE_BUCKET} --output json | jq -r '.Policy' | jq '.'

echo ""
echo "=========================================="
echo "✅ Secure Bucket Policy Applied!"
echo "=========================================="
echo ""
echo "Security features enabled:"
echo "  ✅ Only your AWS account can access"
echo "  ✅ HTTPS/TLS required (no HTTP)"
echo "  ✅ Encryption required for all uploads"
echo "  ✅ GitHub Actions can access via IAM credentials"
echo ""

