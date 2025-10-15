#!/bin/bash
# Complete cleanup script for Databricks infrastructure
# This removes all existing resources to prepare for fresh deployment

set -e

# Configuration
PROJECT="jg-dbx-cmk"
REGION="us-east-1"
ROOT_BUCKET="jg-dbx-pl-root-bucket-cmk"
UNITY_BUCKET="${PROJECT}-unity-catalog-${REGION}"
STATE_BUCKET="jg-dbx-terraform-state"
STATE_TABLE="jg-dbx-terraform-locks"
STATE_KEY="jg-dbx-terraform-state/databricks/pl-cmk/terraform.tfstate"

echo "============================================"
echo "🧹 COMPLETE INFRASTRUCTURE CLEANUP"
echo "============================================"
echo ""
echo "This will clean up:"
echo "  - State locks"
echo "  - IAM roles and policies"
echo "  - S3 buckets (data will be lost!)"
echo "  - KMS keys (7-day deletion)"
echo ""
read -p "⚠️  Are you sure? Type 'yes' to continue: " CONFIRM

if [ "$CONFIRM" != "yes" ]; then
    echo "❌ Cleanup cancelled"
    exit 0
fi

echo ""
echo "Starting cleanup..."
echo ""

# ==================== STEP 1: RELEASE STATE LOCK ====================
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "1️⃣  Releasing Terraform state lock..."
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

LOCK_EXISTS=$(aws dynamodb get-item \
    --table-name ${STATE_TABLE} \
    --key "{\"LockID\": {\"S\": \"${STATE_KEY}\"}}" \
    --region ${REGION} 2>/dev/null || echo "{}")

if [ "$LOCK_EXISTS" != "{}" ] && [ -n "$LOCK_EXISTS" ]; then
    echo "   🔓 Releasing lock..."
    aws dynamodb delete-item \
        --table-name ${STATE_TABLE} \
        --key "{\"LockID\": {\"S\": \"${STATE_KEY}\"}}" \
        --region ${REGION} 2>/dev/null || true
    echo "   ✅ Lock released"
else
    echo "   ℹ️  No lock found"
fi
echo ""

# ==================== STEP 2: IAM ROLES CLEANUP ====================
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "2️⃣  Cleaning up IAM roles..."
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

# Unity Catalog Role
UNITY_ROLE="${PROJECT}-unity-catalog-role"
echo "   📋 Checking Unity Catalog role..."
if aws iam get-role --role-name ${UNITY_ROLE} &>/dev/null; then
    echo "      Found role: ${UNITY_ROLE}"
    
    # Detach managed policies
    ATTACHED_POLICIES=$(aws iam list-attached-role-policies \
        --role-name ${UNITY_ROLE} \
        --query 'AttachedPolicies[*].PolicyArn' \
        --output text 2>/dev/null || echo "")
    
    if [ -n "$ATTACHED_POLICIES" ]; then
        for policy_arn in $ATTACHED_POLICIES; do
            echo "      🔗 Detaching: $(basename $policy_arn)"
            aws iam detach-role-policy \
                --role-name ${UNITY_ROLE} \
                --policy-arn $policy_arn 2>/dev/null || true
        done
    fi
    
    # Delete inline policies
    INLINE_POLICIES=$(aws iam list-role-policies \
        --role-name ${UNITY_ROLE} \
        --query 'PolicyNames[*]' \
        --output text 2>/dev/null || echo "")
    
    if [ -n "$INLINE_POLICIES" ]; then
        for policy_name in $INLINE_POLICIES; do
            echo "      🗑️  Deleting inline: $policy_name"
            aws iam delete-role-policy \
                --role-name ${UNITY_ROLE} \
                --policy-name $policy_name 2>/dev/null || true
        done
    fi
    
    # Delete role
    echo "      🗑️  Deleting role..."
    aws iam delete-role --role-name ${UNITY_ROLE} 2>/dev/null || true
    echo "      ✅ Unity Catalog role deleted"
else
    echo "      ℹ️  Unity Catalog role not found"
fi

# Delete self-assume managed policy
SELF_ASSUME_POLICY="${PROJECT}-unity-catalog-self-assume"
POLICY_ARN=$(aws iam list-policies \
    --query "Policies[?PolicyName=='${SELF_ASSUME_POLICY}'].Arn" \
    --output text 2>/dev/null || echo "")

if [ -n "$POLICY_ARN" ] && [ "$POLICY_ARN" != "None" ]; then
    echo "   🗑️  Deleting self-assume policy..."
    aws iam delete-policy --policy-arn $POLICY_ARN 2>/dev/null || true
    echo "   ✅ Self-assume policy deleted"
fi

# Cross-account Role
CROSS_ACCOUNT_ROLE="${PROJECT}-databricks-cross-account"
echo "   📋 Checking cross-account role..."
if aws iam get-role --role-name ${CROSS_ACCOUNT_ROLE} &>/dev/null; then
    echo "      Found role: ${CROSS_ACCOUNT_ROLE}"
    
    # Detach managed policies
    ATTACHED_POLICIES=$(aws iam list-attached-role-policies \
        --role-name ${CROSS_ACCOUNT_ROLE} \
        --query 'AttachedPolicies[*].PolicyArn' \
        --output text 2>/dev/null || echo "")
    
    if [ -n "$ATTACHED_POLICIES" ]; then
        for policy_arn in $ATTACHED_POLICIES; do
            echo "      🔗 Detaching: $(basename $policy_arn)"
            aws iam detach-role-policy \
                --role-name ${CROSS_ACCOUNT_ROLE} \
                --policy-arn $policy_arn 2>/dev/null || true
        done
    fi
    
    # Delete inline policies
    INLINE_POLICIES=$(aws iam list-role-policies \
        --role-name ${CROSS_ACCOUNT_ROLE} \
        --query 'PolicyNames[*]' \
        --output text 2>/dev/null || echo "")
    
    if [ -n "$INLINE_POLICIES" ]; then
        for policy_name in $INLINE_POLICIES; do
            echo "      🗑️  Deleting inline: $policy_name"
            aws iam delete-role-policy \
                --role-name ${CROSS_ACCOUNT_ROLE} \
                --policy-name $policy_name 2>/dev/null || true
        done
    fi
    
    # Delete role
    echo "      🗑️  Deleting role..."
    aws iam delete-role --role-name ${CROSS_ACCOUNT_ROLE} 2>/dev/null || true
    echo "      ✅ Cross-account role deleted"
else
    echo "      ℹ️  Cross-account role not found"
fi
echo ""

# ==================== STEP 3: S3 BUCKETS CLEANUP ====================
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "3️⃣  Cleaning up S3 buckets..."
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

# Root bucket
echo "   📦 Checking root bucket: ${ROOT_BUCKET}"
if aws s3 ls s3://${ROOT_BUCKET} &>/dev/null; then
    echo "      🗑️  Emptying bucket..."
    aws s3 rm s3://${ROOT_BUCKET} --recursive --quiet 2>/dev/null || true
    
    echo "      🗑️  Deleting bucket..."
    aws s3api delete-bucket --bucket ${ROOT_BUCKET} --region ${REGION} 2>/dev/null || true
    echo "      ✅ Root bucket deleted"
else
    echo "      ℹ️  Root bucket not found"
fi

# Unity Catalog bucket
echo "   📦 Checking Unity Catalog bucket: ${UNITY_BUCKET}"
if aws s3 ls s3://${UNITY_BUCKET} &>/dev/null; then
    echo "      🗑️  Emptying bucket..."
    aws s3 rm s3://${UNITY_BUCKET} --recursive --quiet 2>/dev/null || true
    
    echo "      🗑️  Deleting bucket..."
    aws s3api delete-bucket --bucket ${UNITY_BUCKET} --region ${REGION} 2>/dev/null || true
    echo "      ✅ Unity Catalog bucket deleted"
else
    echo "      ℹ️  Unity Catalog bucket not found"
fi
echo ""

# ==================== STEP 4: KMS KEYS CLEANUP ====================
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "4️⃣  Cleaning up KMS keys..."
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

ALIAS_NAME="alias/databricks/${PROJECT}-cmk"
echo "   🔑 Checking KMS alias: ${ALIAS_NAME}"

# Find key ID by alias
KEY_ID=$(aws kms list-aliases \
    --region ${REGION} \
    --query "Aliases[?AliasName=='${ALIAS_NAME}'].TargetKeyId" \
    --output text 2>/dev/null || echo "")

if [ -n "$KEY_ID" ] && [ "$KEY_ID" != "None" ]; then
    echo "      Found key: ${KEY_ID}"
    
    # Delete alias
    echo "      🗑️  Deleting alias..."
    aws kms delete-alias --alias-name ${ALIAS_NAME} --region ${REGION} 2>/dev/null || true
    echo "      ✅ Alias deleted"
    
    # Schedule key deletion
    echo "      ⏰ Scheduling key deletion (7 days)..."
    aws kms schedule-key-deletion \
        --key-id ${KEY_ID} \
        --pending-window-in-days 7 \
        --region ${REGION} 2>/dev/null || true
    echo "      ✅ Key scheduled for deletion"
else
    echo "      ℹ️  KMS key not found"
fi
echo ""

# ==================== STEP 5: NETWORK CLEANUP ====================
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "5️⃣  Cleaning up VPC and networking resources..."
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

# Find VPC by project tag
VPC_ID=$(aws ec2 describe-vpcs \
    --filters "Name=tag:Name,Values=${PROJECT}-vpc" \
    --query 'Vpcs[0].VpcId' \
    --output text \
    --region ${REGION} 2>/dev/null || echo "")

if [ -n "$VPC_ID" ] && [ "$VPC_ID" != "None" ]; then
    echo "   🌐 Found VPC: ${VPC_ID}"
    
    # Delete VPC endpoints
    echo "   🔌 Deleting VPC endpoints..."
    VPCE_IDS=$(aws ec2 describe-vpc-endpoints \
        --filters "Name=vpc-id,Values=${VPC_ID}" \
        --query 'VpcEndpoints[*].VpcEndpointId' \
        --output text \
        --region ${REGION} 2>/dev/null || echo "")
    
    if [ -n "$VPCE_IDS" ]; then
        for vpce_id in $VPCE_IDS; do
            echo "      Deleting VPC endpoint: $vpce_id"
            aws ec2 delete-vpc-endpoints \
                --vpc-endpoint-ids $vpce_id \
                --region ${REGION} 2>/dev/null || true
        done
        echo "      ⏳ Waiting for VPC endpoints to delete..."
        sleep 10
    fi
    
    # Delete NAT Gateways (if any)
    echo "   🚪 Checking for NAT gateways..."
    NAT_GW_IDS=$(aws ec2 describe-nat-gateways \
        --filter "Name=vpc-id,Values=${VPC_ID}" "Name=state,Values=available" \
        --query 'NatGateways[*].NatGatewayId' \
        --output text \
        --region ${REGION} 2>/dev/null || echo "")
    
    if [ -n "$NAT_GW_IDS" ]; then
        for nat_id in $NAT_GW_IDS; do
            echo "      Deleting NAT gateway: $nat_id"
            aws ec2 delete-nat-gateway --nat-gateway-id $nat_id --region ${REGION} 2>/dev/null || true
        done
        echo "      ⏳ Waiting for NAT gateways to delete (this may take 2-3 minutes)..."
        sleep 180
    fi
    
    # Delete network interfaces (ENIs)
    echo "   🔌 Deleting network interfaces..."
    ENI_IDS=$(aws ec2 describe-network-interfaces \
        --filters "Name=vpc-id,Values=${VPC_ID}" \
        --query 'NetworkInterfaces[*].NetworkInterfaceId' \
        --output text \
        --region ${REGION} 2>/dev/null || echo "")
    
    if [ -n "$ENI_IDS" ]; then
        for eni_id in $ENI_IDS; do
            echo "      Detaching and deleting ENI: $eni_id"
            # First detach if attached
            aws ec2 detach-network-interface \
                --attachment-id $(aws ec2 describe-network-interfaces \
                    --network-interface-ids $eni_id \
                    --query 'NetworkInterfaces[0].Attachment.AttachmentId' \
                    --output text 2>/dev/null) \
                --force \
                --region ${REGION} 2>/dev/null || true
            sleep 2
            # Then delete
            aws ec2 delete-network-interface \
                --network-interface-id $eni_id \
                --region ${REGION} 2>/dev/null || true
        done
    fi
    
    # Delete subnets
    echo "   📍 Deleting subnets..."
    SUBNET_IDS=$(aws ec2 describe-subnets \
        --filters "Name=vpc-id,Values=${VPC_ID}" \
        --query 'Subnets[*].SubnetId' \
        --output text \
        --region ${REGION} 2>/dev/null || echo "")
    
    if [ -n "$SUBNET_IDS" ]; then
        for subnet_id in $SUBNET_IDS; do
            echo "      Deleting subnet: $subnet_id"
            aws ec2 delete-subnet --subnet-id $subnet_id --region ${REGION} 2>/dev/null || true
        done
    fi
    
    # Delete route table associations and route tables
    echo "   🗺️  Deleting route tables..."
    RT_IDS=$(aws ec2 describe-route-tables \
        --filters "Name=vpc-id,Values=${VPC_ID}" \
        --query 'RouteTables[?Associations[0].Main!=`true`].RouteTableId' \
        --output text \
        --region ${REGION} 2>/dev/null || echo "")
    
    if [ -n "$RT_IDS" ]; then
        for rt_id in $RT_IDS; do
            echo "      Deleting route table: $rt_id"
            # Delete all associations first
            ASSOC_IDS=$(aws ec2 describe-route-tables \
                --route-table-ids $rt_id \
                --query 'RouteTables[0].Associations[?!Main].RouteTableAssociationId' \
                --output text \
                --region ${REGION} 2>/dev/null || echo "")
            
            for assoc_id in $ASSOC_IDS; do
                aws ec2 disassociate-route-table \
                    --association-id $assoc_id \
                    --region ${REGION} 2>/dev/null || true
            done
            
            # Delete the route table
            aws ec2 delete-route-table --route-table-id $rt_id --region ${REGION} 2>/dev/null || true
        done
    fi
    
    # Delete internet gateways
    echo "   🌍 Deleting internet gateways..."
    IGW_IDS=$(aws ec2 describe-internet-gateways \
        --filters "Name=attachment.vpc-id,Values=${VPC_ID}" \
        --query 'InternetGateways[*].InternetGatewayId' \
        --output text \
        --region ${REGION} 2>/dev/null || echo "")
    
    if [ -n "$IGW_IDS" ]; then
        for igw_id in $IGW_IDS; do
            echo "      Detaching and deleting IGW: $igw_id"
            aws ec2 detach-internet-gateway \
                --internet-gateway-id $igw_id \
                --vpc-id ${VPC_ID} \
                --region ${REGION} 2>/dev/null || true
            aws ec2 delete-internet-gateway \
                --internet-gateway-id $igw_id \
                --region ${REGION} 2>/dev/null || true
        done
    fi
    
    # Delete security groups (except default)
    echo "   🔒 Deleting security groups..."
    SG_IDS=$(aws ec2 describe-security-groups \
        --filters "Name=vpc-id,Values=${VPC_ID}" \
        --query 'SecurityGroups[?GroupName!=`default`].GroupId' \
        --output text \
        --region ${REGION} 2>/dev/null || echo "")
    
    if [ -n "$SG_IDS" ]; then
        # First pass: Remove all rules to avoid dependency issues
        for sg_id in $SG_IDS; do
            echo "      Removing rules from SG: $sg_id"
            # Remove ingress rules
            aws ec2 revoke-security-group-ingress \
                --group-id $sg_id \
                --security-group-rules $(aws ec2 describe-security-groups \
                    --group-ids $sg_id \
                    --query 'SecurityGroups[0].IpPermissions' \
                    --region ${REGION} 2>/dev/null) \
                --region ${REGION} 2>/dev/null || true
            
            # Remove egress rules
            aws ec2 revoke-security-group-egress \
                --group-id $sg_id \
                --security-group-rules $(aws ec2 describe-security-groups \
                    --group-ids $sg_id \
                    --query 'SecurityGroups[0].IpPermissionsEgress' \
                    --region ${REGION} 2>/dev/null) \
                --region ${REGION} 2>/dev/null || true
        done
        
        # Second pass: Delete security groups
        for sg_id in $SG_IDS; do
            echo "      Deleting security group: $sg_id"
            aws ec2 delete-security-group \
                --group-id $sg_id \
                --region ${REGION} 2>/dev/null || true
        done
    fi
    
    # Finally, delete the VPC
    echo "   🗑️  Deleting VPC..."
    aws ec2 delete-vpc --vpc-id ${VPC_ID} --region ${REGION} 2>/dev/null || true
    echo "   ✅ VPC and networking resources deleted"
else
    echo "   ℹ️  VPC not found (may not have been created or already deleted)"
fi
echo ""

# ==================== STEP 6: VERIFICATION ====================
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "6️⃣  Verifying cleanup..."
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

echo "   🔍 Checking for remaining resources..."
echo ""

# Check IAM roles
IAM_ROLES=$(aws iam list-roles \
    --query "Roles[?contains(RoleName, '${PROJECT}')].RoleName" \
    --output text 2>/dev/null || echo "")

if [ -z "$IAM_ROLES" ]; then
    echo "   ✅ No IAM roles found"
else
    echo "   ⚠️  Remaining IAM roles:"
    echo "      $IAM_ROLES"
fi

# Check S3 buckets (excluding state bucket)
S3_BUCKETS=$(aws s3 ls 2>/dev/null | grep -v "${STATE_BUCKET}" | grep "${PROJECT}" || echo "")

if [ -z "$S3_BUCKETS" ]; then
    echo "   ✅ No S3 buckets found (excluding state bucket)"
else
    echo "   ⚠️  Remaining S3 buckets:"
    echo "      $S3_BUCKETS"
fi

# Check KMS aliases
KMS_ALIASES=$(aws kms list-aliases \
    --region ${REGION} \
    --query "Aliases[?contains(AliasName, '${PROJECT}')].AliasName" \
    --output text 2>/dev/null || echo "")

if [ -z "$KMS_ALIASES" ]; then
    echo "   ✅ No KMS aliases found"
else
    echo "   ⚠️  Remaining KMS aliases:"
    echo "      $KMS_ALIASES"
fi

# Check VPC resources
VPC_REMAINING=$(aws ec2 describe-vpcs \
    --filters "Name=tag:Name,Values=${PROJECT}-vpc" \
    --query 'Vpcs[*].VpcId' \
    --output text \
    --region ${REGION} 2>/dev/null || echo "")

if [ -z "$VPC_REMAINING" ]; then
    echo "   ✅ No VPC found"
else
    echo "   ⚠️  VPC still exists: $VPC_REMAINING"
fi

# Check state lock
LOCK_STATUS=$(aws dynamodb get-item \
    --table-name ${STATE_TABLE} \
    --key "{\"LockID\": {\"S\": \"${STATE_KEY}\"}}" \
    --region ${REGION} 2>/dev/null || echo "{}")

if [ "$LOCK_STATUS" = "{}" ] || [ -z "$LOCK_STATUS" ]; then
    echo "   ✅ No state lock found"
else
    echo "   ⚠️  State lock still exists (unexpected)"
fi

echo ""
echo "============================================"
echo "✅ AWS CLEANUP COMPLETE!"
echo "============================================"
echo ""
echo "Summary:"
echo "  ✅ State lock released"
echo "  ✅ IAM roles and policies deleted"
echo "  ✅ S3 buckets deleted"
echo "  ✅ KMS key scheduled for deletion (7 days)"
echo "  ✅ VPC and networking resources deleted"
echo ""
echo "⚠️  DATABRICKS ACCOUNT RESOURCES"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "Databricks account-level resources must be deleted manually:"
echo ""
echo "1. Go to: https://accounts.cloud.databricks.com"
echo "2. Delete these resources if they exist:"
echo ""
echo "   📋 Cloud Resources → Credentials:"
echo "      - ${PROJECT}-${REGION}-creds"
echo ""
echo "   📦 Cloud Resources → Storage Configurations:"
echo "      - ${PROJECT}-${REGION}-storage"
echo ""
echo "   🌐 Cloud Resources → Networks:"
echo "      - ${PROJECT}-${REGION}-net"
echo ""
echo "   🔒 Cloud Resources → Private Access Settings:"
echo "      - ${PROJECT}-${REGION}-pas"
echo ""
echo "   🔑 Cloud Resources → Customer Managed Keys:"
echo "      - Any CMK configurations for ${PROJECT}"
echo ""
echo "   🔌 Cloud Resources → VPC Endpoints:"
echo "      - ${PROJECT}-${REGION}-workspace-vpce"
echo "      - ${PROJECT}-${REGION}-scc-vpce"
echo ""
echo "   🏢 Workspaces:"
echo "      - ${PROJECT}-${REGION}-ws (if exists)"
echo ""
echo "⚠️  Important Notes:"
echo "  - KMS key will be deleted after 7-day waiting period"
echo "  - To cancel: aws kms cancel-key-deletion --key-id <key-id>"
echo "  - NAT Gateway deletion may take 2-3 minutes if present"
echo "  - VPC deletion order: endpoints → NAT → ENIs → subnets → routes → IGW → SGs → VPC"
echo ""
echo "Next Steps:"
echo "  1. Delete Databricks account resources (above)"
echo "  2. Wait 60 seconds for propagation"
echo "  3. Re-run GitHub Actions deployment workflow"
echo "  4. Or run: cd terraform && terraform init && terraform apply"
echo ""
echo "🎉 Ready for fresh deployment after Databricks cleanup!"
echo ""

