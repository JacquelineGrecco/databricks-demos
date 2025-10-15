# Variable Management Guide

This guide explains how variables are managed in this project using a **hybrid approach** combining committed configuration files with GitHub Secrets.

## 🎯 **Best Practice: Hybrid Approach**

We use **two sources** for variables:

### 📄 **terraform.tfvars (Committed to Git)**
Non-sensitive configuration that can be safely shared:
- Project names
- AWS region
- CIDR blocks
- Bucket names (non-sensitive)
- PrivateLink service names
- Feature flags (e.g., `create_new_vpc`)

### 🔐 **GitHub Secrets (NOT in Git)**
Sensitive credentials that must be protected:
- AWS Access Key ID / Secret Access Key
- Databricks Account ID
- Databricks Client ID / Secret
- External IDs

## 📂 **File Structure**

```
workspace_deployment/aws/aws-pl-back-cmk/terraform/
├── terraform.tfvars              ✅ COMMITTED - Non-sensitive config
├── terraform.tfvars.example-*    ✅ COMMITTED - Example files
├── secrets.tfvars                ❌ NEVER COMMIT - Gitignored
└── credentials.tfvars            ❌ NEVER COMMIT - Gitignored
```

## ✅ **What Goes Where**

### In `terraform.tfvars` (Safe to Commit)

```hcl
# Infrastructure Configuration
project = "my-databricks-workspace"
region  = "us-east-1"

# Networking
create_new_vpc       = true
vpc_cidr             = "10.20.0.0/16"
private_subnet_cidrs = ["10.20.1.0/24", "10.20.2.0/24"]

# Storage
root_bucket_name = "my-company-databricks-root"

# PrivateLink (public information from Databricks docs)
pl_service_names = {
  workspace = "com.amazonaws.vpce.us-east-1.vpce-svc-09143d1e626de2f04"
  scc       = "com.amazonaws.vpce.us-east-1.vpce-svc-00018a8c3ff62ffdf"
}

# CMK
create_new_cmk = true

# Features
enable_extra_endpoints = false
```

### In GitHub Secrets (Never Commit)

```
Environment: aws-pl-back-cmk

Secrets:
├── AWS_ACCESS_KEY_ID
├── AWS_SECRET_ACCESS_KEY
├── DATABRICKS_ACCOUNT_ID
├── DATABRICKS_ACCOUNT_HOST
├── DATABRICKS_CLIENT_ID
├── DATABRICKS_CLIENT_SECRET
└── DATABRICKS_CROSSACCOUNT_ROLE_EXTERNAL_ID
```

## 🔄 **How It Works**

### Local Development

When you run Terraform locally:

```bash
# Terraform reads terraform.tfvars automatically
terraform plan

# Export sensitive variables as environment variables
export TF_VAR_databricks_account_id="xxx"
export TF_VAR_databricks_client_id="xxx"
export TF_VAR_databricks_client_secret="xxx"
# ... etc

# Or use a local secrets file (not committed)
terraform plan -var-file="secrets.tfvars"
```

### GitHub Actions

The workflow automatically:

1. **Checks out code** → Gets `terraform.tfvars` from repo
2. **Sets environment variables** → Injects secrets as `TF_VAR_*`
3. **Runs Terraform** → Combines both sources

```yaml
- name: Terraform Plan
  run: terraform plan
  env:
    # Only sensitive variables passed here
    TF_VAR_databricks_account_id: ${{ secrets.DATABRICKS_ACCOUNT_ID }}
    TF_VAR_databricks_client_id: ${{ secrets.DATABRICKS_CLIENT_ID }}
    # terraform.tfvars is read automatically for other variables
```

## 📝 **Variable Precedence**

Terraform loads variables in this order (later overrides earlier):

1. Default values in `variables.tf`
2. `terraform.tfvars` (auto-loaded)
3. `*.auto.tfvars` (auto-loaded)
4. `-var-file` flags
5. **Environment variables** (`TF_VAR_*`) ← **Highest priority**

This means:
- Non-sensitive config from `terraform.tfvars` is used
- Sensitive env vars from GitHub Secrets override everything

## 🛡️ **Security Benefits**

### ✅ **Advantages of This Approach**

1. **Separation of Concerns**
   - Infrastructure config in version control
   - Credentials in secure vault (GitHub Secrets)

2. **Audit Trail**
   - Configuration changes tracked in Git
   - Credential access logged by GitHub

3. **Easy Collaboration**
   - Team can see/review infrastructure config
   - Credentials only accessible to authorized users

4. **Environment Flexibility**
   - Same terraform.tfvars for all environments
   - Different secrets per environment

5. **No Credential Leakage**
   - Can't accidentally commit credentials
   - Git history stays clean

## 📋 **Checklist: Adding New Variables**

When adding a new variable, ask:

### ❓ Is it sensitive?

**YES (credential, secret, key)** → Add to GitHub Secrets
```yaml
# In workflow
env:
  TF_VAR_new_secret: ${{ secrets.NEW_SECRET }}
```

**NO (config, name, CIDR)** → Add to terraform.tfvars
```hcl
# In terraform.tfvars
new_config_value = "some-value"
```

### ❓ Examples by Type

| Variable Type | Where | Example |
|--------------|-------|---------|
| AWS Credentials | Secrets | `AWS_ACCESS_KEY_ID` |
| Databricks Credentials | Secrets | `DATABRICKS_CLIENT_SECRET` |
| External IDs | Secrets | `databricks_crossaccount_role_external_id` |
| Account IDs | Secrets | `databricks_account_id` |
| Project Name | tfvars | `project = "my-workspace"` |
| Region | tfvars | `region = "us-east-1"` |
| CIDR Blocks | tfvars | `vpc_cidr = "10.0.0.0/16"` |
| Bucket Names | tfvars | `root_bucket_name = "my-bucket"` |
| Feature Flags | tfvars | `create_new_vpc = true` |
| Service Names | tfvars | `pl_service_names = {...}` |

## 🔧 **Local Development Setup**

### Option 1: Environment Variables (Recommended)

```bash
# Create a file: ~/.databricks-env (don't commit this!)
export TF_VAR_databricks_account_id="xxx"
export TF_VAR_databricks_account_host="https://accounts.cloud.databricks.com"
export TF_VAR_databricks_client_id="xxx"
export TF_VAR_databricks_client_secret="xxx"
export TF_VAR_databricks_crossaccount_role_external_id="xxx"

# Source it before running Terraform
source ~/.databricks-env
cd workspace_deployment/aws/aws-pl-back-cmk/terraform
terraform plan
```

### Option 2: Separate Secrets File

```bash
# Create secrets.tfvars (gitignored)
cat > secrets.tfvars <<EOF
databricks_account_id    = "xxx"
databricks_account_host  = "https://accounts.cloud.databricks.com"
databricks_client_id     = "xxx"
databricks_client_secret = "xxx"
databricks_crossaccount_role_external_id = "xxx"
EOF

# Use with -var-file
terraform plan -var-file="secrets.tfvars"
```

## 🧪 **Testing Variable Setup**

### Verify terraform.tfvars is readable:
```bash
cd workspace_deployment/aws/aws-pl-back-cmk/terraform
terraform console
> var.project
"jg-dbx-cmk"
> var.vpc_cidr
"10.20.0.0/16"
```

### Verify secrets are set:
```bash
# Check environment variables
env | grep TF_VAR

# Or in terraform console (if env vars are set)
terraform console
> var.databricks_account_id
"0d26daa6-..."  # Your account ID
```

## 🔄 **Updating Configuration**

### To Change Non-Sensitive Config:

1. Edit `terraform.tfvars`
2. Commit and push to Git
3. GitHub Actions automatically uses new values

### To Change Sensitive Credentials:

1. Go to GitHub → Settings → Environments → `aws-pl-back-cmk`
2. Update secret values
3. Re-run workflow (it will use new secrets)

## 📚 **Examples**

### Example: Adding a New Non-Sensitive Variable

```hcl
# 1. Add to variables.tf
variable "enable_monitoring" {
  type        = bool
  default     = false
  description = "Enable CloudWatch monitoring"
}

# 2. Add to terraform.tfvars
enable_monitoring = true

# 3. Commit both files
git add variables.tf terraform.tfvars
git commit -m "Add monitoring flag"
```

### Example: Adding a New Sensitive Variable

```hcl
# 1. Add to variables.tf
variable "api_key" {
  type        = string
  sensitive   = true
  description = "External API key"
}

# 2. Add to GitHub Secrets as: API_KEY

# 3. Update workflow
env:
  TF_VAR_api_key: ${{ secrets.API_KEY }}
```

## ⚠️ **Common Mistakes to Avoid**

### ❌ DON'T: Commit credentials to terraform.tfvars
```hcl
# BAD - Never do this!
databricks_client_secret = "dapi123abc..."  # ❌
```

### ✅ DO: Reference from secrets
```hcl
# In terraform.tfvars - leave commented
# databricks_client_secret = ""  # Set via GitHub Secrets

# In workflow
env:
  TF_VAR_databricks_client_secret: ${{ secrets.DATABRICKS_CLIENT_SECRET }}  # ✅
```

### ❌ DON'T: Put configuration in secrets
```yaml
# BAD - This should be in terraform.tfvars
secrets:
  VPC_CIDR: "10.20.0.0/16"  # ❌
```

### ✅ DO: Keep config in terraform.tfvars
```hcl
# GOOD - Non-sensitive config in file
vpc_cidr = "10.20.0.0/16"  # ✅
```

## 🎯 **Summary**

| Aspect | terraform.tfvars | GitHub Secrets |
|--------|------------------|----------------|
| **Content** | Infrastructure config | Credentials |
| **Visibility** | Committed to Git | Encrypted, access-controlled |
| **Changes** | PR review required | Immediate |
| **Audit** | Git history | GitHub audit log |
| **Examples** | CIDR, names, flags | API keys, passwords |
| **Priority** | Lower | Higher (overrides) |

---

**Remember:** When in doubt, treat it as sensitive and use GitHub Secrets! 🔐

