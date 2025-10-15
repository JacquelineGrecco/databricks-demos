# Provider configurations for the wrapper
# These are needed to manage state from previous direct deployments

provider "aws" {
  region = var.region
}

# Account-level provider (used for mws_* resources)
provider "databricks" {
  alias         = "mws"
  account_id    = var.databricks_account_id
  host          = var.databricks_account_host
  client_id     = var.databricks_client_id
  client_secret = var.databricks_client_secret
}

# Workspace-level provider for Unity Catalog resources
# Note: This will fail on first run before workspace exists
# But needed to clean up orphaned state from previous runs
provider "databricks" {
  alias         = "workspace"
  host          = try(module.databricks_workspace_private_link_cmk.workspace_url, "https://placeholder.cloud.databricks.com")
  client_id     = var.databricks_client_id
  client_secret = var.databricks_client_secret
}

