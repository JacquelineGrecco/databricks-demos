# ====================================================================
# NON-SENSITIVE CONFIGURATION
# This file is safe to commit to Git
# Sensitive credentials are stored in GitHub Secrets
# ====================================================================

project = "jg-dbx-cmk"
region  = "us-east-1"

# ==================== NETWORKING - CREATE NEW ====================
create_new_vpc       = true
vpc_cidr             = "10.20.0.0/16"
private_subnet_cidrs = ["10.20.1.0/24", "10.20.2.0/24"]

# Leave these empty when creating new VPC
existing_vpc_id            = ""
existing_subnet_ids        = []
existing_security_group_id = ""

# ==================== CMK - CREATE NEW ====================
create_new_cmk   = true
existing_cmk_arn = ""

# ==================== STORAGE & PRIVATELINK ====================
root_bucket_name = "jg-dbx-pl-root-bucket-cmk"

# PrivateLink VPC endpoint service names for your region
# From: https://docs.databricks.com/administration-guide/cloud-configurations/aws/privatelink.html
pl_service_names = {
  workspace = "com.amazonaws.vpce.us-east-1.vpce-svc-09143d1e626de2f04"
  scc       = "com.amazonaws.vpce.us-east-1.vpce-svc-00018a8c3ff62ffdf"
}

enable_extra_endpoints = false

# ====================================================================
# SENSITIVE VARIABLES - NOT DEFINED HERE
# These must be provided via GitHub Secrets:
# ====================================================================
# databricks_account_id                    → DATABRICKS_ACCOUNT_ID
# databricks_account_host                  → DATABRICKS_ACCOUNT_HOST
# databricks_client_id                     → DATABRICKS_CLIENT_ID
# databricks_client_secret                 → DATABRICKS_CLIENT_SECRET
# databricks_crossaccount_role_external_id → DATABRICKS_CROSSACCOUNT_ROLE_EXTERNAL_ID
# ====================================================================

