#!/bin/bash
# Script to force unlock Terraform state
# Use this when a workflow was cancelled or crashed without releasing the lock

set -e

LOCK_ID="${1:-}"
STATE_TABLE="jg-dbx-terraform-locks"
STATE_KEY="jg-dbx-terraform-state/databricks/pl-cmk/terraform.tfstate"
AWS_REGION="us-east-1"

echo "=========================================="
echo "Terraform State Lock Release Tool"
echo "=========================================="
echo ""

if [ -z "$LOCK_ID" ]; then
    echo "Usage: $0 <LOCK_ID>"
    echo ""
    echo "Example:"
    echo "  $0 796048f7-c4d0-504d-53f3-263a7483d2fc"
    echo ""
    echo "Current lock information:"
    echo ""
    
    # Check current lock
    LOCK_INFO=$(aws dynamodb get-item \
        --table-name ${STATE_TABLE} \
        --key "{\"LockID\": {\"S\": \"${STATE_KEY}\"}}" \
        --region ${AWS_REGION} 2>/dev/null || echo "")
    
    if [ -z "$LOCK_INFO" ] || [ "$LOCK_INFO" == "{}" ]; then
        echo "✅ No lock found - state is not locked!"
        exit 0
    fi
    
    echo "🔒 Lock is currently held:"
    echo "$LOCK_INFO" | jq -r '.Item.Info.S' 2>/dev/null || echo "$LOCK_INFO"
    echo ""
    echo "To release the lock, run:"
    echo "  $0 <LOCK_ID_FROM_ERROR>"
    exit 1
fi

echo "Configuration:"
echo "  Lock ID: ${LOCK_ID}"
echo "  DynamoDB Table: ${STATE_TABLE}"
echo "  State Key: ${STATE_KEY}"
echo "  Region: ${AWS_REGION}"
echo ""

# Verify lock exists
echo "🔍 Checking current lock..."
LOCK_INFO=$(aws dynamodb get-item \
    --table-name ${STATE_TABLE} \
    --key "{\"LockID\": {\"S\": \"${STATE_KEY}\"}}" \
    --region ${AWS_REGION} 2>/dev/null || echo "")

if [ -z "$LOCK_INFO" ] || [ "$LOCK_INFO" == "{}" ]; then
    echo "✅ No lock found - state is already unlocked!"
    exit 0
fi

echo "Current lock holder:"
echo "$LOCK_INFO" | jq -r '.Item.Info.S' 2>/dev/null || echo "$LOCK_INFO"
echo ""

# Confirm before unlocking
read -p "⚠️  Are you sure you want to force unlock? (yes/no): " CONFIRM

if [ "$CONFIRM" != "yes" ]; then
    echo "❌ Unlock cancelled"
    exit 1
fi

# Delete the lock from DynamoDB
echo "🔓 Releasing lock..."
aws dynamodb delete-item \
    --table-name ${STATE_TABLE} \
    --key "{\"LockID\": {\"S\": \"${STATE_KEY}\"}}" \
    --region ${AWS_REGION}

echo "   ✅ Lock released"
echo ""

# Verify lock is gone
echo "🔍 Verifying lock removal..."
LOCK_INFO=$(aws dynamodb get-item \
    --table-name ${STATE_TABLE} \
    --key "{\"LockID\": {\"S\": \"${STATE_KEY}\"}}" \
    --region ${AWS_REGION} 2>/dev/null || echo "")

if [ -z "$LOCK_INFO" ] || [ "$LOCK_INFO" == "{}" ]; then
    echo "   ✅ Lock successfully removed!"
else
    echo "   ⚠️  Lock still exists (unexpected)"
fi

echo ""
echo "=========================================="
echo "✅ State Unlock Complete!"
echo "=========================================="
echo ""
echo "Next steps:"
echo "1. Verify no other workflows are running"
echo "2. Re-run your Terraform workflow"
echo "3. If issues persist, check AWS credentials"
echo ""
echo "⚠️  Note: Only force unlock when you're sure no other"
echo "   Terraform process is actively using the state!"
echo ""

