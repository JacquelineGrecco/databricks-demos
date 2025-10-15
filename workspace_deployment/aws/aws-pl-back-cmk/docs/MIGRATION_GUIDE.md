# Migration Guide: Upgrading to Support Existing Resources

This guide helps you migrate from the previous version that only created new resources to the new version that supports both creating new and using existing VPC/CMK resources.

## What's Changed

### New Features
1. **Flexible VPC Configuration**: Choose to create a new VPC or use an existing one
2. **Flexible CMK Configuration**: Choose to create a new CMK or use an existing one
3. **Better Resource Management**: Conditional module loading based on your choices

### Breaking Changes
**None!** The default behavior (`create_new_vpc = true` and `create_new_cmk = true`) maintains backward compatibility.

## Migration Paths

### Path 1: No Changes Needed (Continue Creating New Resources)

If you want to keep the current behavior (creating new VPC and CMK), you don't need to change anything!

**Option A - Add explicit flags (recommended):**
```hcl
# Add to your terraform.tfvars
create_new_vpc = true
create_new_cmk = true
```

**Option B - Do nothing:**
The defaults are already set to `true`, so existing configurations will continue to work.

### Path 2: Switch to Using Existing VPC

If you want to use an existing VPC instead of creating a new one:

1. **Update your `terraform.tfvars`:**
   ```hcl
   # Disable new VPC creation
   create_new_vpc = false
   
   # Comment out or remove these (no longer needed)
   # vpc_cidr = "10.20.0.0/16"
   # private_subnet_cidrs = ["10.20.1.0/24", "10.20.2.0/24"]
   
   # Add existing VPC information
   existing_vpc_id = "vpc-0123456789abcdef0"
   existing_subnet_ids = ["subnet-abc123", "subnet-def456"]
   
   # Optional: provide existing security group
   # existing_security_group_id = "sg-0123456789abcdef0"
   ```

2. **Verify VPC Requirements:**
   - DNS support and DNS hostnames are enabled
   - Subnets are in different Availability Zones
   - Subnets have appropriate route tables

3. **Run Terraform:**
   ```bash
   terraform plan  # Review changes
   terraform apply
   ```

### Path 3: Switch to Using Existing CMK

If you want to use an existing KMS Customer Managed Key:

1. **Update your `terraform.tfvars`:**
   ```hcl
   # Disable new CMK creation
   create_new_cmk = false
   
   # Add existing CMK ARN
   existing_cmk_arn = "arn:aws:kms:us-east-1:123456789012:key/12345678-1234-1234-1234-123456789012"
   ```

2. **Verify CMK Requirements:**
   The existing CMK must have a key policy similar to the one in `modules/aws-cmk/main.tf`. Required permissions:
   
   ```json
   {
     "Version": "2012-10-17",
     "Statement": [
       {
         "Sid": "AllowAccountAdministrators",
         "Effect": "Allow",
         "Principal": {
           "AWS": "arn:aws:iam::YOUR_ACCOUNT_ID:root"
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
           "AWS": "YOUR_CROSS_ACCOUNT_ROLE_ARN"
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
   ```

3. **Run Terraform:**
   ```bash
   terraform plan  # Review changes
   terraform apply
   ```

### Path 4: Use Both Existing VPC and CMK

Combine the configurations from Path 2 and Path 3:

```hcl
# terraform.tfvars
create_new_vpc = false
create_new_cmk = false

existing_vpc_id = "vpc-0123456789abcdef0"
existing_subnet_ids = ["subnet-abc123", "subnet-def456"]
existing_cmk_arn = "arn:aws:kms:us-east-1:123456789012:key/12345678-1234-1234-1234-123456789012"

# Optional
existing_security_group_id = "sg-0123456789abcdef0"
```

## Troubleshooting

### Error: VPC Configuration Error

**Problem:** You set `create_new_vpc = false` but didn't provide existing VPC details.

**Solution:** Provide both `existing_vpc_id` and `existing_subnet_ids` (at least 2 subnets).

### Error: CMK Configuration Error

**Problem:** You set `create_new_cmk = false` but didn't provide an existing CMK ARN.

**Solution:** Provide `existing_cmk_arn` with a valid KMS key ARN.

### Error: Insufficient permissions on CMK

**Problem:** The existing CMK doesn't have the required permissions for Databricks.

**Solution:** Update the CMK key policy to include the required statements (see Path 3 above).

### Error: VPC endpoints failed to create

**Problem:** Incorrect VPC or subnet configuration.

**Solution:** Verify:
- VPC has DNS support and DNS hostnames enabled
- Subnets are in different Availability Zones
- PrivateLink service names are correct for your region

## Rollback Plan

If you encounter issues after migration:

1. **Restore previous `terraform.tfvars`:**
   ```bash
   git checkout terraform.tfvars  # If using version control
   ```

2. **Or explicitly set to create new resources:**
   ```hcl
   create_new_vpc = true
   create_new_cmk = true
   ```

3. **Run terraform:**
   ```bash
   terraform plan
   terraform apply
   ```

## Testing Your Migration

Before applying to production, test in a non-production environment:

1. Clone your configuration
2. Update variables for test environment
3. Run `terraform plan` and review carefully
4. Apply changes in test environment
5. Verify workspace creation and functionality
6. Apply to production with confidence

## Support

For issues or questions:
- Review the main README.md
- Check terraform.tfvars.example-existing-resources for a complete example
- Consult Databricks documentation for VPC and CMK requirements

