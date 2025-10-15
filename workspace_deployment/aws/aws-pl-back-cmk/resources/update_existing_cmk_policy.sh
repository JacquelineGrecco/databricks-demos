#!/bin/bash
# Script to update existing CMK policy for Databricks usage

set -e

CMK_KEY_ID="0fc1ad2a-4597-4e66-9e50-2fb6dbb37088"
REGION="us-east-1"
CROSS_ACCOUNT_ROLE_ARN="arn:aws:iam::<YOUR_AWS_ACCOUNT_ID>:role/<YOUR_CROSS_ACCOUNT_ROLE_NAME>"

echo "Updating KMS key policy for key: $CMK_KEY_ID"
echo "Region: $REGION"

# Get current AWS account ID
AWS_ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text --region $REGION)
echo "Your AWS Account ID: $AWS_ACCOUNT_ID"

# Create the policy document
cat > /tmp/kms_policy.json <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "AllowAccountAdministrators",
      "Effect": "Allow",
      "Principal": {
        "AWS": "arn:aws:iam::${AWS_ACCOUNT_ID}:root"
      },
      "Action": "kms:*",
      "Resource": "*"
    },
    {
      "Sid": "AllowDatabricksControlPlaneDirectUse",
      "Effect": "Allow",
      "Principal": {
        "AWS": "arn:aws:iam::414351767826:root"
      },
      "Action": [
        "kms:Decrypt",
        "kms:Encrypt",
        "kms:GenerateDataKey*",
        "kms:DescribeKey",
        "kms:ReEncrypt*"
      ],
      "Resource": "*"
    },
    {
      "Sid": "AllowDatabricksControlPlaneGrants",
      "Effect": "Allow",
      "Principal": {
        "AWS": "arn:aws:iam::414351767826:root"
      },
      "Action": [
        "kms:CreateGrant",
        "kms:DescribeKey"
      ],
      "Resource": "*",
      "Condition": {
        "Bool": {
          "kms:GrantIsForAWSResource": "true"
        }
      }
    },
    {
      "Sid": "AllowCrossAccountProvisioningRoleGrants",
      "Effect": "Allow",
      "Principal": {
        "AWS": "${CROSS_ACCOUNT_ROLE_ARN}"
      },
      "Action": [
        "kms:CreateGrant",
        "kms:DescribeKey"
      ],
      "Resource": "*",
      "Condition": {
        "Bool": {
          "kms:GrantIsForAWSResource": "true"
        }
      }
    }
  ]
}
EOF

echo ""
echo "Generated policy saved to /tmp/kms_policy.json"
echo ""
echo "Policy contents:"
cat /tmp/kms_policy.json
echo ""
echo "---"
echo ""
echo "Applying policy to KMS key..."

# Apply the policy
aws kms put-key-policy \
  --key-id $CMK_KEY_ID \
  --policy-name default \
  --policy file:///tmp/kms_policy.json \
  --region $REGION

echo ""
echo "✅ SUCCESS! KMS key policy updated."
echo ""
echo "The key now allows:"
echo "  - Your AWS account root (full admin)"
echo "  - Databricks control plane (414351767826) to use the key"
echo "  - Your cross-account role to create grants"
echo ""
echo "You can now run: terraform apply"

