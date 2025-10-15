# Example terraform.tfvars for wrapper
# Copy your existing values here

project = "jacqueline-grecco-ws"
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

# ==================== DATABRICKS ACCOUNT ====================
# databricks_account_id    = "your-account-id"
# databricks_account_host  = "https://accounts.cloud.databricks.com"
# databricks_client_id     = "your-client-id"
# databricks_client_secret = "your-client-secret"
# databricks_crossaccount_role_external_id = "your-external-id"


root_bucket_name = "jacqueline-grecco-root-bucket"

# ==================== PRIVATELINK ====================
pl_service_names = {
  workspace = "com.amazonaws.vpce.us-east-1.vpce-svc-09143d1e626de2f04"
  scc       = "com.amazonaws.vpce.us-east-1.vpce-svc-00018a8c3ff62ffdf"
}

enable_extra_endpoints = false