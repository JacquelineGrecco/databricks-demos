# GitHub Environment Setup Guide

This guide helps you set up and verify GitHub Environments and Secrets for your Databricks deployment.

## ✅ What I Fixed in Your Workflow

I added the `environment` key to your workflow, which was missing:

```yaml
jobs:
  terraform:
    name: Terraform Plan & Apply
    runs-on: ubuntu-latest
    environment: aws-pl-back-cmk  # <-- THIS WAS MISSING!
```

## 🔍 How to Verify Your Environment is Configured

### Step 1: Check Environment Exists

1. Go to your GitHub repository
2. Click **Settings** → **Environments**
3. You should see `aws-pl-back-cmk` listed

### Step 2: Verify Secrets in Environment

Click on `aws-pl-back-cmk` environment and verify these secrets are set:

**Required AWS Secrets:**
- ✅ `AWS_ACCESS_KEY_ID`
- ✅ `AWS_SECRET_ACCESS_KEY`

**OR (if using OIDC):**
- ✅ `AWS_ROLE_ARN`

**Required Databricks Secrets:**
- ✅ `DATABRICKS_ACCOUNT_ID`
- ✅ `DATABRICKS_ACCOUNT_HOST`
- ✅ `DATABRICKS_CLIENT_ID`
- ✅ `DATABRICKS_CLIENT_SECRET`

**Required Terraform Variables (add as secrets):**
- ✅ `TF_VAR_project`
- ✅ `TF_VAR_root_bucket_name`
- ✅ `TF_VAR_databricks_crossaccount_role_external_id`
- ✅ `TF_VAR_vpc_cidr` (if creating new VPC)
- ✅ `TF_VAR_private_subnet_cidrs` (if creating new VPC)
- ✅ `TF_VAR_pl_service_names_workspace`
- ✅ `TF_VAR_pl_service_names_scc`

### Step 3: Update Workflow to Use Environment Variables

Your workflow needs to pass all TF_VAR variables. Add these to the env section:

```yaml
- name: Terraform Plan
  working-directory: ./workspace_deployment/aws/aws-pl-back-cmk/terraform
  run: terraform plan -no-color -out=tfplan
  env:
    TF_VAR_region: ${{ env.AWS_REGION }}
    TF_VAR_project: ${{ secrets.TF_VAR_project }}
    TF_VAR_databricks_account_id: ${{ secrets.DATABRICKS_ACCOUNT_ID }}
    TF_VAR_databricks_account_host: ${{ secrets.DATABRICKS_ACCOUNT_HOST }}
    TF_VAR_databricks_client_id: ${{ secrets.DATABRICKS_CLIENT_ID }}
    TF_VAR_databricks_client_secret: ${{ secrets.DATABRICKS_CLIENT_SECRET }}
    TF_VAR_root_bucket_name: ${{ secrets.TF_VAR_root_bucket_name }}
    TF_VAR_databricks_crossaccount_role_external_id: ${{ secrets.TF_VAR_databricks_crossaccount_role_external_id }}
    TF_VAR_create_new_vpc: "true"
    TF_VAR_vpc_cidr: ${{ secrets.TF_VAR_vpc_cidr }}
    TF_VAR_private_subnet_cidrs: ${{ secrets.TF_VAR_private_subnet_cidrs }}
    TF_VAR_pl_service_names: ${{ secrets.TF_VAR_pl_service_names }}
    TF_VAR_create_new_cmk: "true"
    TF_VAR_enable_extra_endpoints: "false"
```

## 🎯 Option 1: Using Static AWS Credentials (Current Setup)

Your workflow is currently set up for static credentials.

### In GitHub Environment `aws-pl-back-cmk`, add:

```
AWS_ACCESS_KEY_ID=AKIAxxxxxxxxxxxxx
AWS_SECRET_ACCESS_KEY=xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx
```

### Workflow Configuration:
```yaml
- name: Configure AWS Credentials
  uses: aws-actions/configure-aws-credentials@v4
  with:
    aws-access-key-id: ${{ secrets.AWS_ACCESS_KEY_ID }}
    aws-secret-access-key: ${{ secrets.AWS_SECRET_ACCESS_KEY }}
    aws-region: ${{ env.AWS_REGION }}
```

## 🔐 Option 2: Using OIDC (Recommended - More Secure)

### Prerequisites:
1. Create OIDC provider in AWS (one-time setup)
2. Create IAM role that trusts GitHub
3. Add role ARN to GitHub environment

### Setup Steps:

#### 1. Create OIDC Provider in AWS:
```bash
aws iam create-open-id-connect-provider \
  --url https://token.actions.githubusercontent.com \
  --client-id-list sts.amazonaws.com \
  --thumbprint-list 6938fd4d98bab03faadb97b34396831e3780aea1
```

#### 2. Create IAM Role Trust Policy:

Create `github-trust-policy.json`:
```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Federated": "arn:aws:iam::YOUR_ACCOUNT_ID:oidc-provider/token.actions.githubusercontent.com"
      },
      "Action": "sts:AssumeRoleWithWebIdentity",
      "Condition": {
        "StringEquals": {
          "token.actions.githubusercontent.com:aud": "sts.amazonaws.com"
        },
        "StringLike": {
          "token.actions.githubusercontent.com:sub": "repo:YOUR_GITHUB_ORG/databricks-demos:environment:aws-pl-back-cmk"
        }
      }
    }
  ]
}
```

**Important:** Replace:
- `YOUR_ACCOUNT_ID` with your AWS account ID
- `YOUR_GITHUB_ORG/databricks-demos` with your actual repo path

#### 3. Create the Role:
```bash
aws iam create-role \
  --role-name GitHubActions-Databricks-PL-CMK \
  --assume-role-policy-document file://github-trust-policy.json

# Attach admin policy (or create a more restrictive one)
aws iam attach-role-policy \
  --role-name GitHubActions-Databricks-PL-CMK \
  --policy-arn arn:aws:iam::aws:policy/AdministratorAccess
```

#### 4. Add Role ARN to GitHub Environment:

In your `aws-pl-back-cmk` environment, add:
```
AWS_ROLE_ARN=arn:aws:iam::YOUR_ACCOUNT_ID:role/GitHubActions-Databricks-PL-CMK
```

#### 5. Update Workflow:
```yaml
- name: Configure AWS Credentials
  uses: aws-actions/configure-aws-credentials@v4
  with:
    role-to-assume: ${{ secrets.AWS_ROLE_ARN }}
    aws-region: ${{ env.AWS_REGION }}
```

## 🧪 How to Test

### 1. Check Which Environment is Used:

In your workflow run logs, you'll see:
```
✓ Using environment: aws-pl-back-cmk
```

### 2. Verify Secrets are Accessible:

Add a test step to your workflow (remove after testing):
```yaml
- name: Test Environment Variables
  run: |
    echo "Environment: ${GITHUB_ENV}"
    echo "AWS Access Key set: $(if [ -n "$AWS_ACCESS_KEY_ID" ]; then echo "YES"; else echo "NO"; fi)"
    echo "Databricks Account ID set: $(if [ -n "$TF_VAR_databricks_account_id" ]; then echo "YES"; else echo "NO"; fi)"
```

### 3. Manual Workflow Trigger:

1. Go to **Actions** tab
2. Click your workflow
3. Click **Run workflow**
4. Select branch and click **Run workflow**
5. Check the logs for errors

## 🐛 Common Issues

### Issue 1: "Credentials could not be loaded"

**Solution:**
- ✅ Verify `environment: aws-pl-back-cmk` is in workflow
- ✅ Check secrets exist in the ENVIRONMENT, not repo secrets
- ✅ Ensure secret names match exactly (case-sensitive)

### Issue 2: "Environment 'aws-pl-back-cmk' not found"

**Solution:**
- Create the environment in Settings → Environments
- Add required approval if needed (optional)
- Add all secrets to the environment

### Issue 3: Secrets Not Available

**Difference between Repository Secrets and Environment Secrets:**

**Repository Secrets** (Settings → Secrets and variables → Actions → Repository secrets):
- Available to ALL workflows
- No approval required
- Use: `${{ secrets.SECRET_NAME }}`

**Environment Secrets** (Settings → Environments → [environment name] → Secrets):
- Only available when workflow specifies `environment: aws-pl-back-cmk`
- Can require approvals
- Use: `${{ secrets.SECRET_NAME }}` (same syntax, but only works with environment specified)

**Your setup needs ENVIRONMENT secrets** since you're using environment-specific deployments!

## 📋 Quick Checklist

- [ ] Environment `aws-pl-back-cmk` exists
- [ ] Workflow has `environment: aws-pl-back-cmk` line
- [ ] All required secrets are in the ENVIRONMENT (not repository)
- [ ] Workflow has `working-directory` for all Terraform steps
- [ ] All `TF_VAR_*` environment variables are set
- [ ] AWS credentials are properly configured (static or OIDC)
- [ ] Workflow runs without credential errors

## 🎯 Next Steps

1. ✅ Verify environment exists and has secrets
2. ✅ Push the updated workflow
3. ✅ Trigger a workflow run manually
4. ✅ Check the logs for "Using environment: aws-pl-back-cmk"
5. ✅ Verify AWS CLI step succeeds with `aws sts get-caller-identity`

Good luck! 🚀

