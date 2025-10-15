# Terraform Remote State Backend Configuration
# This stores state in S3 with DynamoDB locking
# Ensures state persistence across GitHub Actions runs

terraform {
  backend "s3" {
    bucket         = "jg-dbx-terraform-state"
    key            = "databricks/pl-cmk/terraform.tfstate"
    region         = "us-east-1"
    encrypt        = true
    dynamodb_table = "jg-dbx-terraform-locks"

    # Optional: Add these for additional security
    # kms_key_id     = "arn:aws:kms:us-east-1:ACCOUNT_ID:key/KEY_ID"
    # acl            = "private"
  }
}

