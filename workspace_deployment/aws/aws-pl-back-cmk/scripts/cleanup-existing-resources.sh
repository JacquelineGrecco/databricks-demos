#!/bin/bash
# Script to manually clean up existing resources
# Use this when the destroy workflow can't run or you need to start fresh

set -e

PROJECT="jg-dbx-cmk"
REGION="us-east-1"
ROOT_BUCKET="jg-dbx-pl-root-bucket-cmk"
UNITY_BUCKET="${PROJECT}-unity-catalog-${REGION}"

echo "=========================================="
echo "⚠️  RESOURCE CLEANUP TOOL"
echo "=========================================="
echo ""
echo "This will delete:"
echo "  - KMS keys and aliases"
echo "  - S3 buckets (${ROOT_BUCKET}, ${UNITY_BUCKET})"
echo "  - IAM roles and policies"
echo ""
read -p "Are you sure you want to proceed? (yes/no): " CONFIRM

if [ "$CONFIRM" != "yes" ]; then
    echo "❌ Cleanup cancelled"
    exit 1
fi

echo ""
echo "Starting cleanup..."
echo ""

# ==================== KMS KEYS ====================
echo "🔑 Cleaning up KMS keys..."

# Find and delete KMS alias
ALIAS_NAME="alias/databricks/${PROJECT}-cmk"
if aws kms describe-alias --alias-name ${ALIAS_NAME} --region ${REGION} &>/dev/null; then
    echo "   Deleting KMS alias: ${ALIAS_NAME}"
    aws kms delete-alias --alias-name ${ALIAS_NAME} --region ${REGION}
    echo "   ✅ Alias deleted"
else
    echo "   ℹ️  Alias not found (may already be deleted)"
fi

# Find and schedule key deletion
KEY_ID=$(aws kms list-aliases --region ${REGION} \
  --query "Aliases[?AliasName=='${ALIAS_NAME}'].TargetKeyId" \
  --output text 2>/dev/null || echo "")

if [ -n "$KEY_ID" ] && [ "$KEY_ID" != "None" ]; then
    echo "   Scheduling KMS key deletion: ${KEY_ID}"
    aws kms schedule-key-deletion \
      --key-id ${KEY_ID} \
      --pending-window-in-days 7 \
      --region ${REGION} 2>/dev/null || echo "   ⚠️  Key may already be scheduled for deletion"
    echo "   ✅ Key scheduled for deletion (7 days)"
else
    echo "   ℹ️  KMS key not found (may already be deleted)"
fi

# ==================== S3 BUCKETS ====================
echo ""
echo "🗑️  Cleaning up S3 buckets..."

# Delete root bucket
if aws s3 ls s3://${ROOT_BUCKET} &>/dev/null; then
    echo "   Emptying bucket: ${ROOT_BUCKET}"
    aws s3 rm s3://${ROOT_BUCKET} --recursive 2>/dev/null || echo "   ⚠️  Some objects may have failed to delete"
    
    echo "   Deleting bucket: ${ROOT_BUCKET}"
    aws s3api delete-bucket --bucket ${ROOT_BUCKET} --region ${REGION} 2>/dev/null || echo "   ⚠️  Bucket may not be empty or doesn't exist"
    echo "   ✅ Root bucket deleted"
else
    echo "   ℹ️  Root bucket not found (may already be deleted)"
fi

# Delete Unity Catalog bucket
if aws s3 ls s3://${UNITY_BUCKET} &>/dev/null; then
    echo "   Emptying bucket: ${UNITY_BUCKET}"
    aws s3 rm s3://${UNITY_BUCKET} --recursive 2>/dev/null || echo "   ⚠️  Some objects may have failed to delete"
    
    echo "   Deleting bucket: ${UNITY_BUCKET}"
    aws s3api delete-bucket --bucket ${UNITY_BUCKET} --region ${REGION} 2>/dev/null || echo "   ⚠️  Bucket may not be empty or doesn't exist"
    echo "   ✅ Unity Catalog bucket deleted"
else
    echo "   ℹ️  Unity Catalog bucket not found (may already be deleted)"
fi

# ==================== IAM ROLES ====================
echo ""
echo "👤 Cleaning up IAM roles..."

# Clean up cross-account role
CROSS_ACCOUNT_ROLE="${PROJECT}-databricks-cross-account"
if aws iam get-role --role-name ${CROSS_ACCOUNT_ROLE} &>/dev/null; then
    echo "   Processing role: ${CROSS_ACCOUNT_ROLE}"
    
    # Detach managed policies
    ATTACHED_POLICIES=$(aws iam list-attached-role-policies --role-name ${CROSS_ACCOUNT_ROLE} --query 'AttachedPolicies[*].PolicyArn' --output text)
    for policy in $ATTACHED_POLICIES; do
        echo "     Detaching policy: ${policy}"
        aws iam detach-role-policy --role-name ${CROSS_ACCOUNT_ROLE} --policy-arn ${policy}
    done
    
    # Delete inline policies
    INLINE_POLICIES=$(aws iam list-role-policies --role-name ${CROSS_ACCOUNT_ROLE} --query 'PolicyNames[*]' --output text)
    for policy in $INLINE_POLICIES; do
        echo "     Deleting inline policy: ${policy}"
        aws iam delete-role-policy --role-name ${CROSS_ACCOUNT_ROLE} --policy-name ${policy}
    done
    
    # Delete role
    aws iam delete-role --role-name ${CROSS_ACCOUNT_ROLE}
    echo "   ✅ Cross-account role deleted"
else
    echo "   ℹ️  Cross-account role not found (may already be deleted)"
fi

# Clean up Unity Catalog role
UNITY_ROLE="${PROJECT}-unity-catalog-role"
if aws iam get-role --role-name ${UNITY_ROLE} &>/dev/null; then
    echo "   Processing role: ${UNITY_ROLE}"
    
    # Detach managed policies
    ATTACHED_POLICIES=$(aws iam list-attached-role-policies --role-name ${UNITY_ROLE} --query 'AttachedPolicies[*].PolicyArn' --output text)
    for policy in $ATTACHED_POLICIES; do
        echo "     Detaching policy: ${policy}"
        aws iam detach-role-policy --role-name ${UNITY_ROLE} --policy-arn ${policy}
    done
    
    # Delete inline policies
    INLINE_POLICIES=$(aws iam list-role-policies --role-name ${UNITY_ROLE} --query 'PolicyNames[*]' --output text)
    for policy in $INLINE_POLICIES; do
        echo "     Deleting inline policy: ${policy}"
        aws iam delete-role-policy --role-name ${UNITY_ROLE} --policy-name ${policy}
    done
    
    # Delete role
    aws iam delete-role --role-name ${UNITY_ROLE}
    echo "   ✅ Unity Catalog role deleted"
else
    echo "   ℹ️  Unity Catalog role not found (may already be deleted)"
fi

# Delete Unity Catalog self-assume policy (if it exists as managed policy)
SELF_ASSUME_POLICY="${PROJECT}-unity-catalog-self-assume"
POLICY_ARN=$(aws iam list-policies --query "Policies[?PolicyName=='${SELF_ASSUME_POLICY}'].Arn" --output text 2>/dev/null || echo "")
if [ -n "$POLICY_ARN" ]; then
    echo "   Deleting self-assume policy: ${SELF_ASSUME_POLICY}"
    aws iam delete-policy --policy-arn ${POLICY_ARN} 2>/dev/null || echo "   ⚠️  Policy may be in use or already deleted"
    echo "   ✅ Self-assume policy deleted"
fi

# ==================== VPC RESOURCES ====================
echo ""
echo "🌐 Checking VPC resources..."
echo "   ℹ️  VPC cleanup should be done via destroy workflow"
echo "   ℹ️  Manual VPC cleanup is complex due to dependencies"
echo "   ℹ️  Recommend: Use GitHub Actions 'Destroy Infrastructure' workflow"

echo ""
echo "=========================================="
echo "✅ Cleanup Complete!"
echo "=========================================="
echo ""
echo "Summary:"
echo "  ✅ KMS key scheduled for deletion (7-day waiting period)"
echo "  ✅ S3 buckets deleted"
echo "  ✅ IAM roles and policies deleted"
echo "  ⚠️  VPC resources require destroy workflow"
echo ""
echo "Next steps:"
echo "1. Wait 1-2 minutes for AWS to propagate deletions"
echo "2. (Optional) Run destroy workflow to clean up VPC/networking"
echo "3. Re-run deployment workflow"
echo ""
echo "Note: KMS key will be permanently deleted after 7 days."
echo "To cancel deletion: aws kms cancel-key-deletion --key-id <key-id>"
echo ""

