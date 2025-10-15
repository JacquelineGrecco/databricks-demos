# Required AWS Permissions for Terraform

This document lists the minimum AWS permissions needed to deploy Databricks infrastructure with this Terraform configuration.

## 🚨 **Current Error**

```
User: arn:aws:iam::332745928618:user/jacqueline_grecco is not authorized 
to perform: ec2:DescribeAvailabilityZones
```

**Root Cause:** The IAM user/role running Terraform doesn't have sufficient permissions.

## ✅ **Quick Fix: Attach Policy**

### Option 1: AdministratorAccess (Development Only)

**Pros:** Simple, works immediately
**Cons:** Too broad for production

```bash
# Via AWS Console:
IAM → Users → jacqueline_grecco → Add permissions → AdministratorAccess

# Via AWS CLI:
aws iam attach-user-policy \
  --user-name jacqueline_grecco \
  --policy-arn arn:aws:iam::aws:policy/AdministratorAccess
```

### Option 2: PowerUserAccess (Better)

**Pros:** Allows most operations except IAM user management
**Cons:** Still quite broad

```bash
aws iam attach-user-policy \
  --user-name jacqueline_grecco \
  --policy-arn arn:aws:iam::aws:policy/PowerUserAccess
```

## 📋 **Minimum Required Permissions (Production)**

For production environments, create a custom policy with only required permissions:

### Create `databricks-terraform-policy.json`:

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "EC2Permissions",
      "Effect": "Allow",
      "Action": [
        "ec2:AuthorizeSecurityGroupEgress",
        "ec2:AuthorizeSecurityGroupIngress",
        "ec2:CreateNetworkInterface",
        "ec2:CreateSecurityGroup",
        "ec2:CreateSubnet",
        "ec2:CreateTags",
        "ec2:CreateVpc",
        "ec2:CreateVpcEndpoint",
        "ec2:CreateInternetGateway",
        "ec2:CreateRouteTable",
        "ec2:CreateRoute",
        "ec2:DeleteNetworkInterface",
        "ec2:DeleteSecurityGroup",
        "ec2:DeleteSubnet",
        "ec2:DeleteTags",
        "ec2:DeleteVpc",
        "ec2:DeleteVpcEndpoints",
        "ec2:DeleteInternetGateway",
        "ec2:DeleteRouteTable",
        "ec2:DeleteRoute",
        "ec2:DescribeAvailabilityZones",
        "ec2:DescribeNetworkInterfaces",
        "ec2:DescribeSecurityGroups",
        "ec2:DescribeSubnets",
        "ec2:DescribeVpcs",
        "ec2:DescribeVpcEndpoints",
        "ec2:DescribeVpcAttribute",
        "ec2:DescribeInternetGateways",
        "ec2:DescribeRouteTables",
        "ec2:ModifyVpcAttribute",
        "ec2:RevokeSecurityGroupEgress",
        "ec2:RevokeSecurityGroupIngress",
        "ec2:AttachInternetGateway",
        "ec2:DetachInternetGateway",
        "ec2:AssociateRouteTable",
        "ec2:DisassociateRouteTable"
      ],
      "Resource": "*"
    },
    {
      "Sid": "S3Permissions",
      "Effect": "Allow",
      "Action": [
        "s3:CreateBucket",
        "s3:DeleteBucket",
        "s3:DeleteBucketPolicy",
        "s3:DeleteObject",
        "s3:DeleteObjectVersion",
        "s3:GetBucketAcl",
        "s3:GetBucketLocation",
        "s3:GetBucketPolicy",
        "s3:GetBucketPublicAccessBlock",
        "s3:GetBucketVersioning",
        "s3:GetEncryptionConfiguration",
        "s3:GetObject",
        "s3:GetObjectVersion",
        "s3:ListBucket",
        "s3:ListBucketVersions",
        "s3:PutBucketAcl",
        "s3:PutBucketPolicy",
        "s3:PutBucketPublicAccessBlock",
        "s3:PutBucketVersioning",
        "s3:PutEncryptionConfiguration",
        "s3:PutBucketOwnershipControls",
        "s3:GetBucketOwnershipControls",
        "s3:PutObject",
        "s3:PutObjectAcl"
      ],
      "Resource": "*"
    },
    {
      "Sid": "IAMPermissions",
      "Effect": "Allow",
      "Action": [
        "iam:AttachRolePolicy",
        "iam:CreatePolicy",
        "iam:CreateRole",
        "iam:CreateServiceLinkedRole",
        "iam:DeletePolicy",
        "iam:DeleteRole",
        "iam:DeleteRolePolicy",
        "iam:DetachRolePolicy",
        "iam:GetPolicy",
        "iam:GetPolicyVersion",
        "iam:GetRole",
        "iam:GetRolePolicy",
        "iam:ListAttachedRolePolicies",
        "iam:ListInstanceProfilesForRole",
        "iam:ListPolicyVersions",
        "iam:ListRolePolicies",
        "iam:PassRole",
        "iam:PutRolePolicy",
        "iam:UpdateAssumeRolePolicy",
        "iam:UpdateRole",
        "iam:TagRole",
        "iam:UntagRole",
        "iam:GetUser"
      ],
      "Resource": "*"
    },
    {
      "Sid": "KMSPermissions",
      "Effect": "Allow",
      "Action": [
        "kms:CreateAlias",
        "kms:CreateGrant",
        "kms:CreateKey",
        "kms:Decrypt",
        "kms:DeleteAlias",
        "kms:DescribeKey",
        "kms:Encrypt",
        "kms:GenerateDataKey",
        "kms:GetKeyPolicy",
        "kms:GetKeyRotationStatus",
        "kms:ListAliases",
        "kms:ListGrants",
        "kms:ListKeyPolicies",
        "kms:ListResourceTags",
        "kms:PutKeyPolicy",
        "kms:ScheduleKeyDeletion",
        "kms:TagResource",
        "kms:UntagResource"
      ],
      "Resource": "*"
    },
    {
      "Sid": "STSPermissions",
      "Effect": "Allow",
      "Action": [
        "sts:AssumeRole",
        "sts:GetCallerIdentity"
      ],
      "Resource": "*"
    }
  ]
}
```

### Apply the Custom Policy:

```bash
# Create the policy
aws iam create-policy \
  --policy-name DatabricksTerraformPolicy \
  --policy-document file://databricks-terraform-policy.json

# Attach to user
aws iam attach-user-policy \
  --user-name jacqueline_grecco \
  --policy-arn arn:aws:iam::332745928618:policy/DatabricksTerraformPolicy
```

## 🔍 **Current User Permissions**

Check what permissions your user currently has:

```bash
# List attached policies
aws iam list-attached-user-policies --user-name jacqueline_grecco

# List inline policies
aws iam list-user-policies --user-name jacqueline_grecco
```

## ⚡ **Immediate Solution for GitHub Actions**

If running via GitHub Actions, ensure the IAM user/role has sufficient permissions:

### If using Static Credentials:

The IAM user associated with `AWS_ACCESS_KEY_ID` needs permissions above.

### If using OIDC:

The IAM role specified in `AWS_ROLE_ARN` needs permissions above.

## 🛡️ **Permission Boundaries (Optional)**

For extra security, you can add permission boundaries:

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "ec2:*",
        "s3:*",
        "iam:*",
        "kms:*"
      ],
      "Resource": "*",
      "Condition": {
        "StringLike": {
          "aws:RequestedRegion": "us-east-1"
        }
      }
    }
  ]
}
```

This limits operations to specific regions only.

## 📊 **Permission Test**

Test if your user has required permissions:

```bash
# Test EC2 permissions
aws ec2 describe-availability-zones

# Test S3 permissions
aws s3 ls

# Test IAM permissions
aws iam get-user

# Test KMS permissions
aws kms list-keys
```

If any fail, you're missing permissions for that service.

## 🚀 **Recommended Approach**

### For Development/Testing:
1. Attach `AdministratorAccess` or `PowerUserAccess`
2. Fast and simple

### For Production:
1. Create custom policy with minimum permissions (above)
2. Test thoroughly in dev environment
3. Apply to production IAM user/role
4. Review and audit regularly

## ⚠️ **Security Best Practices**

1. ✅ **Use IAM roles** instead of users when possible (especially in GitHub Actions with OIDC)
2. ✅ **Rotate credentials** regularly
3. ✅ **Use separate accounts** for dev/staging/prod
4. ✅ **Enable MFA** for users with admin access
5. ✅ **Monitor CloudTrail** for API calls
6. ✅ **Use permission boundaries** to limit maximum permissions
7. ✅ **Follow principle of least privilege**

## 📝 **Next Steps**

1. Choose your approach (AdministratorAccess for quick fix, or custom policy for production)
2. Apply the policy to your IAM user
3. Verify permissions with test commands above
4. Re-run your Terraform workflow
5. Monitor CloudTrail logs to see which permissions are actually used
6. Refine policy if needed

---

**Quick Command to Fix Your Current Error:**

```bash
# Quickest fix (development only):
aws iam attach-user-policy \
  --user-name jacqueline_grecco \
  --policy-arn arn:aws:iam::aws:policy/AdministratorAccess

# Then re-run terraform
terraform plan
```

