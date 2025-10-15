# Private State Bucket Access Options

This guide explains how to access the Terraform state bucket in different network scenarios.

## 🌐 **Default Setup: Public Access (Recommended for Most)**

By default, GitHub Actions runners access S3 state bucket via **public internet**:

```
GitHub Actions Runner (Public Internet)
    │
    │ HTTPS
    │ IAM Auth
    ▼
AWS S3 Public Endpoint
    │
    ▼
S3 State Bucket
```

**This is secure because:**
- ✅ Uses HTTPS/TLS encryption
- ✅ Requires valid IAM credentials
- ✅ Can restrict to your AWS account via bucket policy
- ✅ S3 access logs track all access
- ✅ No additional infrastructure needed

## 🔒 **Restricted Access Scenarios**

### Scenario 1: Restrict to Your AWS Account Only

**Use Case:** Prevent accidental public access

**Solution:** S3 Bucket Policy

```bash
# Run the script
./workspace_deployment/aws/aws-pl-back-cmk/scripts/create-state-bucket-policy.sh
```

**Result:**
- Only IAM users/roles in your AWS account can access
- GitHub Actions uses your IAM credentials → ✅ Works
- External users without valid credentials → ❌ Blocked

### Scenario 2: Private VPC-Only Access

**Use Case:** 
- Corporate policy requires all AWS API calls via VPC endpoints
- No public internet access to S3 allowed
- Air-gapped environment

**Solution:** Self-Hosted GitHub Actions Runners in Your VPC

#### Architecture:

```
┌─────────────────────────────────────────┐
│         Your Private VPC                │
│                                         │
│  ┌────────────────────┐                │
│  │ Self-Hosted        │                │
│  │ GitHub Runner      │                │
│  │ (EC2 Instance)     │                │
│  └──────────┬─────────┘                │
│             │                           │
│             │ Uses VPC Endpoints        │
│             ▼                           │
│  ┌────────────────────┐                │
│  │ S3 VPC Endpoint    │                │
│  │ (PrivateLink)      │                │
│  └──────────┬─────────┘                │
│             │                           │
└─────────────┼─────────────────────────┘
              │
              ▼
       S3 State Bucket
```

#### Setup Steps:

**1. Create S3 VPC Endpoint (Gateway)**

```bash
# Get your VPC ID and route table ID
VPC_ID="vpc-xxxxx"
ROUTE_TABLE_ID="rtb-xxxxx"
AWS_REGION="us-east-1"

# Create S3 Gateway Endpoint
aws ec2 create-vpc-endpoint \
  --vpc-id ${VPC_ID} \
  --service-name com.amazonaws.${AWS_REGION}.s3 \
  --route-table-ids ${ROUTE_TABLE_ID} \
  --vpc-endpoint-type Gateway
```

**2. Update S3 Bucket Policy for VPC-Only Access**

```bash
STATE_BUCKET="jg-dbx-terraform-state"
AWS_ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
VPCE_ID="vpce-xxxxx"  # Your S3 VPC Endpoint ID

# Create policy
cat > /tmp/vpc-only-policy.json <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "AllowVPCEndpointAccess",
      "Effect": "Allow",
      "Principal": {
        "AWS": "arn:aws:iam::${AWS_ACCOUNT_ID}:root"
      },
      "Action": "s3:*",
      "Resource": [
        "arn:aws:s3:::${STATE_BUCKET}",
        "arn:aws:s3:::${STATE_BUCKET}/*"
      ],
      "Condition": {
        "StringEquals": {
          "aws:sourceVpce": "${VPCE_ID}"
        }
      }
    },
    {
      "Sid": "DenyNonVPCAccess",
      "Effect": "Deny",
      "Principal": "*",
      "Action": "s3:*",
      "Resource": [
        "arn:aws:s3:::${STATE_BUCKET}",
        "arn:aws:s3:::${STATE_BUCKET}/*"
      ],
      "Condition": {
        "StringNotEquals": {
          "aws:sourceVpce": "${VPCE_ID}"
        }
      }
    }
  ]
}
EOF

# Apply policy
aws s3api put-bucket-policy \
  --bucket ${STATE_BUCKET} \
  --policy file:///tmp/vpc-only-policy.json
```

**3. Set Up Self-Hosted GitHub Runner**

```bash
# Launch EC2 instance in your private VPC
aws ec2 run-instances \
  --image-id ami-0c55b159cbfafe1f0 \  # Amazon Linux 2
  --instance-type t3.medium \
  --subnet-id subnet-xxxxx \
  --security-group-ids sg-xxxxx \
  --iam-instance-profile Name=GitHubRunnerProfile \
  --tag-specifications 'ResourceType=instance,Tags=[{Key=Name,Value=github-runner}]' \
  --user-data file://setup-github-runner.sh
```

**setup-github-runner.sh:**

```bash
#!/bin/bash
# Install GitHub Actions runner on EC2

# Update system
yum update -y

# Install dependencies
yum install -y git jq aws-cli

# Download and configure GitHub Actions runner
mkdir -p /home/ec2-user/actions-runner
cd /home/ec2-user/actions-runner

RUNNER_VERSION="2.311.0"
curl -o actions-runner-linux-x64-${RUNNER_VERSION}.tar.gz \
  -L https://github.com/actions/runner/releases/download/v${RUNNER_VERSION}/actions-runner-linux-x64-${RUNNER_VERSION}.tar.gz

tar xzf actions-runner-linux-x64-${RUNNER_VERSION}.tar.gz
chown -R ec2-user:ec2-user /home/ec2-user/actions-runner

# Configure runner (requires GitHub token)
# You'll need to complete this step manually or via automation
# ./config.sh --url https://github.com/YOUR_ORG/databricks-demos --token YOUR_TOKEN

# Install as service
sudo ./svc.sh install
sudo ./svc.sh start
```

**4. Update GitHub Workflow to Use Self-Hosted Runner**

```yaml
jobs:
  terraform:
    name: Terraform Plan & Apply
    runs-on: self-hosted  # Changed from ubuntu-latest
    environment: aws-pl-back-cmk
    # ... rest of job
```

### Scenario 3: Hybrid Approach (Recommended)

**Use Case:** Balance security and simplicity

**Solution:** 
- Use GitHub-hosted runners (public internet)
- Restrict S3 bucket to your AWS account
- Use AWS OIDC for temporary credentials (no long-lived keys)
- Enable S3 access logging
- Use encryption

**This is what we've already configured!** It's secure and requires no additional infrastructure.

## 📊 **Comparison Table**

| Approach | Security | Complexity | Cost | Best For |
|----------|----------|------------|------|----------|
| **Public S3 with IAM** | ⭐⭐⭐ Good | ⭐ Simple | $ Free | Most projects |
| **S3 Bucket Policy** | ⭐⭐⭐⭐ Better | ⭐⭐ Easy | $ Free | Standard security |
| **VPC Endpoints Only** | ⭐⭐⭐⭐⭐ Best | ⭐⭐⭐⭐⭐ Complex | $$$ EC2 24/7 | Air-gapped/regulated |
| **AWS PrivateLink** | ⭐⭐⭐⭐⭐ Best | ⭐⭐⭐⭐ Hard | $$$ PrivateLink fees | Enterprise |

## ✅ **Your Current Setup (Recommended)**

Your current configuration is **secure enough for most use cases**:

```yaml
# GitHub Actions uses:
- Public internet to AWS APIs ✅
- IAM credentials from GitHub Secrets ✅
- HTTPS/TLS encryption ✅
- S3 bucket encryption ✅
- S3 versioning (audit trail) ✅
- DynamoDB locking (prevents conflicts) ✅
```

**Additional security you can add:**

```bash
# 1. Restrict bucket to your account
./workspace_deployment/aws/aws-pl-back-cmk/scripts/create-state-bucket-policy.sh

# 2. Enable S3 access logging
aws s3api put-bucket-logging \
  --bucket jg-dbx-terraform-state \
  --bucket-logging-status '{
    "LoggingEnabled": {
      "TargetBucket": "jg-dbx-access-logs",
      "TargetPrefix": "terraform-state/"
    }
  }'

# 3. Enable CloudTrail for S3 data events
aws cloudtrail put-event-selectors \
  --trail-name my-trail \
  --event-selectors '[
    {
      "ReadWriteType": "All",
      "IncludeManagementEvents": true,
      "DataResources": [{
        "Type": "AWS::S3::Object",
        "Values": ["arn:aws:s3:::jg-dbx-terraform-state/*"]
      }]
    }
  ]'
```

## 🎯 **Decision Guide**

**Choose Public S3 Access if:**
- ✅ Standard corporate environment
- ✅ Want simple setup and maintenance
- ✅ Trust GitHub's infrastructure security
- ✅ Use IAM credentials properly
- ✅ Want to minimize costs

**Choose Self-Hosted Runners if:**
- ⚠️ Regulatory requirements for air-gapped deployment
- ⚠️ Corporate policy mandates VPC-only AWS access
- ⚠️ Need to access other private resources during deployment
- ⚠️ Have dedicated team to maintain runner infrastructure

## 🔐 **Security Best Practices (All Approaches)**

1. ✅ **Use AWS OIDC instead of static credentials**
   - No long-lived access keys
   - Temporary credentials per workflow run
   - Scoped to specific GitHub repository

2. ✅ **Enable S3 bucket versioning**
   - Already configured in setup script
   - Protects against accidental deletions
   - Allows rollback of state

3. ✅ **Enable S3 encryption**
   - Already configured (AES256)
   - Protects data at rest

4. ✅ **Restrict IAM permissions**
   - Only allow necessary actions on state bucket
   - Use separate IAM role for Terraform operations

5. ✅ **Enable access logging**
   - Track all state bucket access
   - Audit who accessed what and when

6. ✅ **Use DynamoDB locking**
   - Already configured
   - Prevents concurrent Terraform runs

## 📝 **Example: Complete Secure Setup**

```bash
# 1. Create state infrastructure
./workspace_deployment/aws/aws-pl-back-cmk/scripts/setup-remote-state.sh

# 2. Apply restrictive bucket policy
./workspace_deployment/aws/aws-pl-back-cmk/scripts/create-state-bucket-policy.sh

# 3. Enable access logging
aws s3api put-bucket-logging \
  --bucket jg-dbx-terraform-state \
  --bucket-logging-status '{
    "LoggingEnabled": {
      "TargetBucket": "my-log-bucket",
      "TargetPrefix": "state-access/"
    }
  }'

# 4. Set up AWS OIDC for GitHub Actions (one-time)
# See: docs/GITHUB_ENVIRONMENT_SETUP.md

# 5. Deploy!
# GitHub Actions workflow will now:
# - Use temporary OIDC credentials ✅
# - Access S3 via public endpoint with IAM auth ✅
# - State encrypted at rest ✅
# - All access logged ✅
```

## ❓ **FAQ**

### Q: Is it safe for GitHub Actions to access S3 from public internet?

**A: Yes!** As long as you use proper IAM authentication:
- S3 doesn't care WHERE the request comes from
- S3 cares WHO is making the request (IAM credentials)
- HTTPS encrypts data in transit
- IAM policies control what can be accessed

### Q: Can someone intercept my state file?

**A: No:**
- HTTPS/TLS encryption in transit
- S3 encryption at rest
- Requires valid IAM credentials to read
- GitHub Secrets are encrypted

### Q: What if my company blocks all public AWS access?

**A:** You need self-hosted runners in your VPC (Scenario 2 above)

### Q: Should I use PrivateLink for the state bucket?

**A:** Only if required by policy. It adds significant complexity and cost with minimal security benefit over properly configured IAM + bucket policies.

## 📚 **Additional Resources**

- [AWS S3 Security Best Practices](https://docs.aws.amazon.com/AmazonS3/latest/userguide/security-best-practices.html)
- [GitHub Actions Self-Hosted Runners](https://docs.github.com/en/actions/hosting-your-own-runners)
- [AWS OIDC for GitHub Actions](https://docs.github.com/en/actions/deployment/security-hardening-your-deployments/configuring-openid-connect-in-amazon-web-services)
- [Terraform S3 Backend](https://developer.hashicorp.com/terraform/language/settings/backends/s3)

---

**Bottom Line:** Your current setup with public S3 access + IAM credentials is **secure and recommended** for most use cases. Only add complexity if required by specific policies or regulations.


