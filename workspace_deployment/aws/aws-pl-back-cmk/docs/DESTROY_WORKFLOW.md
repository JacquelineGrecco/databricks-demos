# Infrastructure Destroy Workflow Guide

This guide explains how to safely destroy your Databricks infrastructure using GitHub Actions.

## ⚠️ **IMPORTANT WARNING**

This workflow **PERMANENTLY DESTROYS** all Terraform-managed resources including:
- ✅ Databricks Workspace
- ✅ Unity Catalog Metastore and External Locations
- ✅ VPC, Subnets, Security Groups (if created by Terraform)
- ✅ VPC Endpoints
- ✅ KMS Customer Managed Keys (will enter deletion window)
- ✅ S3 Buckets (including all data, if `force_destroy = true`)
- ✅ IAM Roles and Policies

**This action is IRREVERSIBLE!**

## 🔒 **Safety Features Built-In**

The destroy workflow includes multiple safety layers:

1. ✅ **Manual Trigger Only** - Cannot run automatically
2. ✅ **Confirmation Required** - Must type "DESTROY" to proceed
3. ✅ **Environment Protection** - Uses GitHub Environment (can require approvals)
4. ✅ **Plan Display** - Shows what will be destroyed before applying
5. ✅ **Delays** - Built-in waiting periods before destruction
6. ✅ **Audit Trail** - All actions logged and stored

## 📋 **Prerequisites**

Before running the destroy workflow:

1. ✅ **Backup Important Data**
   - Export notebooks from workspace
   - Backup Unity Catalog metadata
   - Export any important configurations
   - Download workspace logs if needed

2. ✅ **Verify Access**
   - Ensure you have admin access to the GitHub repository
   - Verify AWS credentials have delete permissions
   - Confirm Databricks credentials are valid

3. ✅ **Check Dependencies**
   - Ensure no other systems depend on this infrastructure
   - Verify no active jobs or clusters
   - Confirm no external integrations will break

## 🚀 **How to Run the Destroy Workflow**

### Method 1: Via GitHub UI (Recommended)

1. Go to your GitHub repository
2. Click on **Actions** tab
3. Select **"Destroy Infrastructure"** workflow from the left sidebar
4. Click **"Run workflow"** button (top right)
5. Fill in the form:
   ```
   confirmation: DESTROY
   environment: aws-pl-back-cmk
   ```
6. Click **"Run workflow"**
7. **Wait for approval** (if environment protection is enabled)
8. Monitor the workflow execution

### Method 2: Via GitHub CLI

```bash
gh workflow run destroy-infrastructure.yml \
  -f confirmation=DESTROY \
  -f environment=aws-pl-back-cmk
```

## 📊 **What Happens During Destruction**

### Stage 1: Validation (30 seconds)
```
✓ Check confirmation text matches "DESTROY"
✓ Validate environment exists
✓ Display warning messages
```

### Stage 2: Planning (2-3 minutes)
```
✓ Initialize Terraform
✓ Generate destruction plan
✓ Display resources to be destroyed
✓ Wait 10 seconds for final review
```

### Stage 3: Execution (10-15 minutes)
```
✓ Destroy Databricks resources (workspace, Unity Catalog)
✓ Destroy networking resources (VPC endpoints, security groups)
✓ Destroy storage resources (S3 buckets)
✓ Destroy encryption resources (KMS keys)
✓ Destroy IAM resources (roles, policies)
```

### Stage 4: Cleanup
```
✓ Remove Terraform state files
✓ Clean up temporary files
✓ Upload logs as artifacts
```

## 🛡️ **Recommended: Add Environment Protection**

For extra safety, enable required approvers for the environment:

### Step 1: Configure Environment Protection

1. Go to **Settings** → **Environments**
2. Click on `aws-pl-back-cmk`
3. Under **Deployment protection rules**, enable:
   - ✅ **Required reviewers** - Add 1-2 people who must approve
   - ✅ **Wait timer** - Optional: Add 5 minute delay
4. Click **Save protection rules**

### Step 2: Test Protection

When you run the destroy workflow, it will:
1. Show "Waiting for approval" status
2. Send notification to required reviewers
3. Only proceed after approval
4. Record who approved and when

## 📝 **Destroy Workflow Execution Order**

Terraform destroys resources in reverse dependency order:

```
1. External Location (Unity Catalog)
2. Storage Credential (Unity Catalog)
3. Metastore Assignment
4. Metastore
5. Workspace
6. Private Access Settings
7. Network Configuration
8. VPC Endpoints
9. Storage Configuration
10. Credentials Configuration
11. Customer Managed Keys
12. S3 Buckets
13. VPC Resources (if created)
14. IAM Roles and Policies
```

## ⚠️ **Known Issues and Considerations**

### Issue 1: KMS Key Deletion Window

**Problem:** KMS keys cannot be immediately deleted
**Impact:** Key enters 7-30 day deletion window
**Solution:** 
```bash
# To cancel deletion (within window)
aws kms cancel-key-deletion --key-id <key-id>
```

### Issue 2: S3 Bucket Deletion

**Problem:** Buckets with versioning may take time
**Impact:** Final deletion might be delayed
**Solution:** Wait for AWS to complete deletion, or check:
```bash
aws s3 ls | grep your-bucket-prefix
```

### Issue 3: VPC Deletion Dependencies

**Problem:** VPC might have lingering ENIs
**Impact:** VPC deletion might fail temporarily
**Solution:** Terraform will retry, or manually check:
```bash
aws ec2 describe-network-interfaces --filters Name=vpc-id,Values=<vpc-id>
```

### Issue 4: Databricks Workspace Deletion

**Problem:** Workspace deletion can take 10+ minutes
**Impact:** Workflow might timeout
**Solution:** Check Databricks Account Console for status

## 🧪 **Testing the Destroy Workflow**

### Dry Run (Recommended First Time)

1. **Comment out the actual destroy** in the workflow:
   ```yaml
   # - name: Terraform Destroy
   #   run: terraform apply -auto-approve destroy.tfplan
   ```

2. Run workflow to see the plan without destroying
3. Review logs to verify what would be destroyed
4. Uncomment when ready to actually destroy

### Partial Destroy

To destroy specific resources only:

```bash
# Locally (not in workflow)
cd workspace_deployment/aws/aws-pl-back-cmk/terraform

# Destroy specific resource
terraform destroy -target=databricks_external_location.unity_catalog

# Destroy multiple resources
terraform destroy \
  -target=databricks_external_location.unity_catalog \
  -target=databricks_storage_credential.unity_catalog
```

## 📚 **Recovery Options**

If you accidentally destroy infrastructure:

### Option 1: Restore from State Backup
```bash
# State is saved as artifact in workflow
# Download and restore
terraform state push terraform.tfstate.backup
```

### Option 2: Redeploy
```bash
# Run the deployment workflow again
# All resources will be recreated
```

### Option 3: Import Existing Resources
```bash
# If some resources weren't destroyed
terraform import <resource_type>.<name> <resource_id>
```

## 🔍 **Monitoring Destruction Progress**

### In GitHub Actions:
- Watch the workflow logs in real-time
- Each resource destruction is logged
- Final summary shows completion status

### In AWS Console:
```bash
# Check resource deletion
aws ec2 describe-vpcs --filters Name=tag:Name,Values=*databricks*
aws s3 ls | grep databricks
aws kms list-keys
aws iam list-roles | grep databricks
```

### In Databricks Console:
- Account Console → Workspaces (should show deleted)
- Account Console → Metastores (should show removed)

## 📋 **Post-Destruction Checklist**

After successful destruction:

- [ ] Verify all AWS resources deleted in console
- [ ] Check for any orphaned resources (ENIs, EIPs)
- [ ] Confirm S3 buckets are empty/deleted
- [ ] Verify KMS keys in deletion state
- [ ] Check IAM roles removed
- [ ] Confirm Databricks workspace deleted in Account Console
- [ ] Remove GitHub environment (optional)
- [ ] Remove GitHub secrets (optional)
- [ ] Document destruction in change log

## 🆘 **Emergency Stop**

If you need to stop destruction mid-way:

### Via GitHub UI:
1. Go to Actions → Running workflow
2. Click **Cancel workflow** button (top right)
3. Note: Resources already destroyed cannot be recovered

### What to Do Next:
1. Check which resources were destroyed (in logs)
2. Verify remaining resources in AWS/Databricks
3. Decide: continue destruction or restore

## 💡 **Best Practices**

1. ✅ **Always backup first** - Export critical data
2. ✅ **Test in dev** - Try destroy workflow in dev environment first
3. ✅ **Enable approvals** - Require human approval for production
4. ✅ **Run during maintenance** - Schedule during low-activity periods
5. ✅ **Notify stakeholders** - Let team know about planned destruction
6. ✅ **Document reasons** - Keep audit trail of why destroyed
7. ✅ **Review logs** - Save workflow logs for compliance

## 📞 **Support**

If issues occur during destruction:

1. **Check workflow logs** - Detailed error messages
2. **Review Terraform state** - What was destroyed
3. **Check AWS CloudTrail** - AWS-side audit logs
4. **Contact support** - Databricks or AWS if needed

## 🎯 **Example: Complete Destruction Process**

```bash
# 1. Backup data
databricks workspace export_dir /Workspace /local/backup

# 2. Run destroy workflow via GitHub Actions
# (Manual trigger with confirmation)

# 3. Monitor progress
# Watch GitHub Actions logs

# 4. Verify completion
aws ec2 describe-vpcs --filters Name=tag:Project,Values=my-project
aws s3 ls | grep my-project

# 5. Clean up local files
cd workspace_deployment/aws/aws-pl-back-cmk/terraform
rm -rf .terraform terraform.tfstate*

# 6. Document
echo "Infrastructure destroyed on $(date)" >> CHANGELOG.md
```

---

## ⚠️ **Final Warning**

**THIS WORKFLOW PERMANENTLY DESTROYS YOUR INFRASTRUCTURE**

- No undo button
- Data will be lost
- Recovery requires full redeployment
- Some resources (KMS keys) have mandatory waiting periods

**Only use when you're absolutely certain you want to destroy everything!**

---

**Questions? Review the logs, check the AWS console, and verify twice before destroying!** 🚨

