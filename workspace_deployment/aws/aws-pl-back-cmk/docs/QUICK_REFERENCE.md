# Quick Reference Guide

## TL;DR - What Changed?

This Terraform project can now use **existing VPC, subnets, and CMK** instead of only creating new ones.

## Decision Matrix: Which Mode Should I Use?

| Scenario | Configuration |
|----------|---------------|
| **Starting fresh, no existing resources** | `create_new_vpc = true`<br>`create_new_cmk = true` |
| **Have existing VPC, want new CMK** | `create_new_vpc = false`<br>`create_new_cmk = true` |
| **Have existing CMK, want new VPC** | `create_new_vpc = true`<br>`create_new_cmk = false` |
| **Have both existing VPC and CMK** | `create_new_vpc = false`<br>`create_new_cmk = false` |

## Quick Setup

### Scenario 1: Create Everything (Default - No Changes Needed!)

```bash
# Use your existing terraform.tfvars or copy the example
cp terraform.tfvars.example-new-resources terraform.tfvars

# Edit terraform.tfvars with your values
# - project name
# - region
# - vpc_cidr
# - private_subnet_cidrs
# - databricks credentials
# - pl_service_names

# Deploy
terraform init
terraform plan
terraform apply
```

### Scenario 2: Use Existing VPC and CMK

```bash
# Copy the existing resources example
cp terraform.tfvars.example-existing-resources terraform.tfvars

# Edit terraform.tfvars and set:
create_new_vpc = false
create_new_cmk = false

existing_vpc_id = "vpc-xxxxx"
existing_subnet_ids = ["subnet-xxxxx", "subnet-yyyyy"]
existing_cmk_arn = "arn:aws:kms:region:account:key/xxxxx"

# Optional
existing_security_group_id = "sg-xxxxx"

# Deploy
terraform init
terraform plan
terraform apply
```

## Required Variables by Mode

### Creating New VPC
```hcl
create_new_vpc = true
vpc_cidr = "10.20.0.0/16"
private_subnet_cidrs = ["10.20.1.0/24", "10.20.2.0/24"]
```

### Using Existing VPC
```hcl
create_new_vpc = false
existing_vpc_id = "vpc-xxxxx"
existing_subnet_ids = ["subnet-xxxxx", "subnet-yyyyy"]  # Min 2, different AZs
existing_security_group_id = "sg-xxxxx"  # Optional
```

### Creating New CMK
```hcl
create_new_cmk = true
```

### Using Existing CMK
```hcl
create_new_cmk = false
existing_cmk_arn = "arn:aws:kms:region:account:key/xxxxx"
```

## Pre-Flight Checklist

### Before Using Existing VPC
- [ ] VPC has DNS support enabled
- [ ] VPC has DNS hostnames enabled
- [ ] At least 2 subnets in different AZs
- [ ] Subnets have route tables configured

### Before Using Existing CMK
- [ ] CMK is in the same region as your workspace
- [ ] CMK policy allows Databricks control plane (414351767826)
- [ ] CMK policy allows your cross-account role
- [ ] CMK key rotation is enabled (recommended)

### Common for Both
- [ ] You have Databricks account credentials
- [ ] You know your PrivateLink service names for your region
- [ ] AWS credentials are configured
- [ ] Terraform >= 1.5 is installed

## Get PrivateLink Service Names

PrivateLink service names are region-specific. Find them in [Databricks documentation](https://docs.databricks.com/administration-guide/cloud-configurations/aws/privatelink.html).

Example for us-east-1:
```hcl
pl_service_names = {
  workspace = "com.amazonaws.vpce.us-east-1.vpce-svc-09143d1e626de2f04"
  scc       = "com.amazonaws.vpce.us-east-1.vpce-svc-00018a8c3ff62ffdf"
}
```

## CMK Policy Template (for Existing CMK)

Your existing CMK needs this policy structure:

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
      "Sid": "AllowDatabricksControlPlane",
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
      "Sid": "AllowDatabricksGrants",
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
      "Sid": "AllowCrossAccountRoleGrants",
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

## Verification Commands

Check your resources before deployment:

```bash
# Check VPC DNS settings
aws ec2 describe-vpcs --vpc-ids vpc-xxxxx \
  --query 'Vpcs[0].[EnableDnsSupport,EnableDnsHostnames]'

# Check subnets are in different AZs
aws ec2 describe-subnets --subnet-ids subnet-xxxxx subnet-yyyyy \
  --query 'Subnets[*].[SubnetId,AvailabilityZone]'

# Check CMK exists
aws kms describe-key --key-id arn:aws:kms:region:account:key/xxxxx

# Verify CMK policy (check output includes Databricks account)
aws kms get-key-policy --key-id arn:aws:kms:region:account:key/xxxxx \
  --policy-name default
```

## Troubleshooting One-Liners

```bash
# Error: VPC Configuration Error
# Solution: Check you provided both vpc_id and subnet_ids when create_new_vpc=false

# Error: CMK Configuration Error  
# Solution: Check you provided cmk_arn when create_new_cmk=false

# Error: KMS access denied
# Solution: Update CMK policy with Databricks control plane permissions

# Error: VPC endpoint creation failed
# Solution: Verify VPC DNS settings and PrivateLink service names

# Show what mode you're running in
terraform output deployment_mode
```

## Important Outputs

After deployment, these outputs are available:

```bash
terraform output workspace_url          # Your Databricks workspace URL
terraform output workspace_id           # Workspace ID
terraform output vpc_id                 # VPC being used (created or existing)
terraform output kms_key_arn           # CMK being used (created or existing)
terraform output deployment_mode        # Shows what was created vs. existing
```

## Cost Impact

### Creating New Resources
- VPC: Free
- Subnets: Free
- VPC Endpoints: ~$7.20/endpoint/month + data transfer
- KMS Key: $1/month + API calls
- Security Groups: Free

### Using Existing Resources
- VPC Endpoints still created: ~$7.20/endpoint/month
- VPC/CMK: No additional cost (already paying for them)

## Files Reference

| File | Purpose |
|------|---------|
| `terraform.tfvars.example-new-resources` | Example for creating new resources |
| `terraform.tfvars.example-existing-resources` | Example for using existing resources |
| `README.md` | Full documentation |
| `MIGRATION_GUIDE.md` | Step-by-step migration guide |
| `CHANGES.md` | Detailed changelog |
| `QUICK_REFERENCE.md` | This file - quick lookup |

## Next Steps After Deployment

1. Wait ~20 minutes after workspace shows "RUNNING"
2. Access workspace via URL from `terraform output workspace_url`
3. Create your first cluster
4. Verify Unity Catalog access
5. Consider setting `public_access_enabled = false` in PAS for production

## Support

- For Terraform issues: Check `terraform.log` and validate configuration
- For AWS issues: Check CloudTrail logs and resource permissions
- For Databricks issues: Check Account Console and workspace logs
- For setup help: Review `MIGRATION_GUIDE.md` and `README.md`

