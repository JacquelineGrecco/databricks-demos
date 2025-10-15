# Terraform State Management for GitHub Actions

## 🚨 **Current Issue**

```
Error: creating KMS Alias (...): AlreadyExistsException
Error: creating IAM Role (...): EntityAlreadyExists
Error: creating S3 Bucket (...): BucketAlreadyExists
```

**Root Cause:** Resources exist from a previous run, but Terraform state is not being persisted between GitHub Actions runs.

## ⚡ **Immediate Solutions**

### Option 1: Clean Up and Redeploy (Quickest)

1. **Run the destroy workflow:**
   - GitHub Actions → "Destroy Infrastructure" workflow
   - Type `DESTROY` to confirm
   - Wait for completion (~15 minutes)

2. **Re-run the deployment workflow:**
   - GitHub Actions → "Terraform Databricks Deployment" workflow
   - Resources will be created fresh

### Option 2: Set Up Remote State Backend (Recommended)

Configure S3 backend to persist state between runs.

## 🏗️ **Setting Up Remote State (Recommended)**

### Step 1: Create S3 Bucket and DynamoDB Table

```bash
# Set variables
export AWS_REGION="us-east-1"
export STATE_BUCKET="jg-dbx-terraform-state"
export STATE_TABLE="jg-dbx-terraform-locks"

# Create S3 bucket for state
aws s3api create-bucket \
  --bucket ${STATE_BUCKET} \
  --region ${AWS_REGION}

# Enable versioning
aws s3api put-bucket-versioning \
  --bucket ${STATE_BUCKET} \
  --versioning-configuration Status=Enabled

# Enable encryption
aws s3api put-bucket-encryption \
  --bucket ${STATE_BUCKET} \
  --server-side-encryption-configuration '{
    "Rules": [{
      "ApplyServerSideEncryptionByDefault": {
        "SSEAlgorithm": "AES256"
      }
    }]
  }'

# Block public access
aws s3api put-public-access-block \
  --bucket ${STATE_BUCKET} \
  --public-access-block-configuration \
    BlockPublicAcls=true,IgnorePublicAcls=true,BlockPublicPolicy=true,RestrictPublicBuckets=true

# Create DynamoDB table for state locking
aws dynamodb create-table \
  --table-name ${STATE_TABLE} \
  --attribute-definitions AttributeName=LockID,AttributeType=S \
  --key-schema AttributeName=LockID,KeyType=HASH \
  --billing-mode PAY_PER_REQUEST \
  --region ${AWS_REGION}
```

### Step 2: Create Backend Configuration File

Create `workspace_deployment/aws/aws-pl-back-cmk/terraform/backend.tf`:

```hcl
terraform {
  backend "s3" {
    bucket         = "jg-dbx-terraform-state"
    key            = "databricks/pl-cmk/terraform.tfstate"
    region         = "us-east-1"
    encrypt        = true
    dynamodb_table = "jg-dbx-terraform-locks"
  }
}
```

### Step 3: Update GitHub Actions Workflow

The workflow already handles state properly with remote backend. Just add the backend configuration above.

### Step 4: Migrate Existing State (if any)

If you have local state you want to migrate:

```bash
cd workspace_deployment/aws/aws-pl-back-cmk/terraform

# Initialize with new backend
terraform init

# Terraform will ask to migrate - answer "yes"
```

## 📊 **State Backend Comparison**

| Method | Pros | Cons | Best For |
|--------|------|------|----------|
| **Local files** | Simple, no setup | Lost between runs, no locking | Local dev only |
| **Workflow artifacts** | No extra setup | Manual download needed, no locking | Testing |
| **S3 + DynamoDB** | Persistent, locked, versioned | Requires AWS resources | **Production** |

## 🔍 **Checking Current State**

### In GitHub Actions:

Check if state file exists in artifacts:
1. Go to workflow run
2. Click on "Artifacts"
3. Download `terraform-state`
4. Check if `terraform.tfstate` has content

### Locally:

```bash
cd workspace_deployment/aws/aws-pl-back-cmk/terraform

# Check if state exists
ls -la terraform.tfstate*

# View state
terraform show
```

## 🛠️ **Recovering from "Already Exists" Errors**

### Method 1: Import Existing Resources

If you want to keep existing resources:

```bash
cd workspace_deployment/aws/aws-pl-back-cmk/terraform

# Import each resource (example for KMS key)
terraform import 'module.cmk[0].aws_kms_key.databricks_cmk' <key-id>
terraform import 'module.cmk[0].aws_kms_alias.databricks_cmk_alias' alias/databricks/jg-dbx-cmk-cmk
terraform import 'module.iam.aws_iam_role.databricks' jg-dbx-cmk-databricks-cross-account
terraform import 'module.storage.aws_s3_bucket.root' jg-dbx-pl-root-bucket-cmk
terraform import 'module.unity_catalog.aws_s3_bucket.metastore' jg-dbx-cmk-unity-catalog-us-east-1
terraform import 'module.unity_catalog.aws_iam_role.unity_catalog' jg-dbx-cmk-unity-catalog-role

# This is tedious - destroy and recreate is usually faster
```

### Method 2: Destroy Existing Resources

**Via Workflow (Recommended):**
- Run "Destroy Infrastructure" workflow
- Type `DESTROY` to confirm

**Manually (if workflow fails):**

```bash
# Delete resources in reverse dependency order

# 1. KMS Alias
aws kms delete-alias --alias-name alias/databricks/jg-dbx-cmk-cmk

# 2. S3 Buckets (must be empty first)
aws s3 rm s3://jg-dbx-pl-root-bucket-cmk --recursive
aws s3api delete-bucket --bucket jg-dbx-pl-root-bucket-cmk

aws s3 rm s3://jg-dbx-cmk-unity-catalog-us-east-1 --recursive
aws s3api delete-bucket --bucket jg-dbx-cmk-unity-catalog-us-east-1

# 3. IAM Roles (detach policies first)
aws iam list-attached-role-policies --role-name jg-dbx-cmk-databricks-cross-account
aws iam detach-role-policy --role-name jg-dbx-cmk-databricks-cross-account --policy-arn <arn>
aws iam delete-role-policy --role-name jg-dbx-cmk-databricks-cross-account --policy-name <name>
aws iam delete-role --role-name jg-dbx-cmk-databricks-cross-account

aws iam list-attached-role-policies --role-name jg-dbx-cmk-unity-catalog-role
aws iam detach-role-policy --role-name jg-dbx-cmk-unity-catalog-role --policy-arn <arn>
aws iam delete-role-policy --role-name jg-dbx-cmk-unity-catalog-role --policy-name <name>
aws iam delete-role --role-name jg-dbx-cmk-unity-catalog-role

# 4. Continue with other resources...
```

## 🎯 **Best Practice Workflow**

### For GitHub Actions:

1. **Set up remote state backend** (S3 + DynamoDB)
2. **Use one of these patterns:**

**Pattern A: State in S3 (Recommended)**
```yaml
- name: Terraform Init
  working-directory: ./workspace_deployment/aws/aws-pl-back-cmk/terraform
  run: terraform init -input=false
  # Automatically uses backend.tf configuration
```

**Pattern B: State in Artifacts (Simple)**
```yaml
# Download state before running
- name: Download Previous State
  uses: actions/download-artifact@v4
  with:
    name: terraform-state
    path: ./workspace_deployment/aws/aws-pl-back-cmk/terraform
  continue-on-error: true  # OK if first run

# Upload state after running
- name: Upload Terraform State
  uses: actions/upload-artifact@v4
  with:
    name: terraform-state
    path: |
      workspace_deployment/aws/aws-pl-back-cmk/terraform/terraform.tfstate
```

### For Local Development:

1. **Use same remote backend** as GitHub Actions
2. **Or use separate workspace:**
   ```bash
   terraform workspace new local-dev
   terraform workspace select local-dev
   ```

## 🔐 **Security Considerations**

### Remote State:

✅ **Enable:**
- S3 bucket encryption
- S3 bucket versioning
- S3 public access block
- DynamoDB point-in-time recovery
- IAM policies restricting access

❌ **Avoid:**
- Public S3 buckets
- Unencrypted state
- Shared credentials in state

### State File Contains Sensitive Data:

- Database passwords
- API keys
- Private keys
- IAM credentials

**Always encrypt and restrict access!**

## 📝 **Quick Start Guide**

### To Fix Your Current Issue:

**Option 1: Destroy and Recreate (Fastest)**

```bash
# 1. Go to GitHub Actions
# 2. Run "Destroy Infrastructure" workflow
# 3. Type "DESTROY" to confirm
# 4. Wait for completion
# 5. Re-run deployment workflow
```

**Option 2: Set Up Remote State (Best Long-term)**

```bash
# 1. Create S3 bucket and DynamoDB table (commands above)
# 2. Create backend.tf file
# 3. Commit and push
# 4. Run destroy workflow to clean up
# 5. Re-run deployment workflow
```

## 🐛 **Troubleshooting**

### Issue: "Error acquiring the state lock"

**Cause:** Another process is running or previous run didn't release lock

**Solution:**
```bash
# Force unlock (use carefully!)
terraform force-unlock <LOCK_ID>

# Or delete DynamoDB lock item
aws dynamodb delete-item \
  --table-name jg-dbx-terraform-locks \
  --key '{"LockID": {"S": "jg-dbx-terraform-state/databricks/pl-cmk/terraform.tfstate"}}'
```

### Issue: "Failed to load backend"

**Cause:** S3 bucket or DynamoDB table doesn't exist

**Solution:** Create them using commands in Step 1 above

### Issue: "Backend configuration changed"

**Cause:** backend.tf was modified

**Solution:**
```bash
terraform init -reconfigure
```

## 📚 **Additional Resources**

- [Terraform S3 Backend Docs](https://developer.hashicorp.com/terraform/language/settings/backends/s3)
- [State Locking with DynamoDB](https://developer.hashicorp.com/terraform/language/settings/backends/s3#dynamodb-table-permissions)
- [Terraform Cloud (Alternative)](https://www.terraform.io/cloud)

## ✅ **Recommended Setup for Your Project**

Based on your setup, here's what I recommend:

1. **Create backend configuration:**
   ```bash
   cd workspace_deployment/aws/aws-pl-back-cmk/terraform
   cat > backend.tf << 'EOF'
terraform {
  backend "s3" {
    bucket         = "jg-dbx-terraform-state"
    key            = "databricks/pl-cmk/terraform.tfstate"
    region         = "us-east-1"
    encrypt        = true
    dynamodb_table = "jg-dbx-terraform-locks"
  }
}
EOF
   ```

2. **Create the S3 backend:**
   ```bash
   ./workspace_deployment/aws/aws-pl-back-cmk/scripts/setup-remote-state.sh
   ```

3. **Clean up existing resources:**
   - Run destroy workflow

4. **Deploy fresh:**
   - Run deployment workflow
   - State will now be persisted in S3

This ensures consistent state across all GitHub Actions runs! 🚀

