# Pass through outputs from the module

# ==================== WORKSPACE OUTPUTS ====================
output "workspace_url" {
  value       = module.databricks_workspace.workspace_url
  description = "Databricks workspace URL"
}

output "workspace_id" {
  value       = module.databricks_workspace.workspace_id
  description = "Workspace ID"
}

output "workspace_deployment_name" {
  value       = module.databricks_workspace.workspace_deployment_name
  description = "Workspace deployment name"
}

# ==================== NETWORKING OUTPUTS ====================
output "vpc_id" {
  value       = module.databricks_workspace.vpc_id
  description = "VPC ID (created or existing)"
}

output "subnet_ids" {
  value       = module.databricks_workspace.subnet_ids
  description = "Subnet IDs (created or existing)"
}

output "workspace_security_group_id" {
  value       = module.databricks_workspace.workspace_security_group_id
  description = "Workspace security group ID"
}

output "vpc_endpoint_workspace_id" {
  value       = module.databricks_workspace.vpc_endpoint_workspace_id
  description = "VPC endpoint ID for Databricks workspace"
}

output "vpc_endpoint_scc_id" {
  value       = module.databricks_workspace.vpc_endpoint_scc_id
  description = "VPC endpoint ID for SCC relay"
}

# ==================== ENCRYPTION OUTPUTS ====================
output "kms_key_arn" {
  value       = module.databricks_workspace.kms_key_arn
  description = "KMS key ARN (created or existing)"
}

output "customer_managed_key_id" {
  value       = module.databricks_workspace.customer_managed_key_id
  description = "Databricks customer managed key ID"
}

# ==================== UNITY CATALOG OUTPUTS ====================
output "metastore_id" {
  value       = module.databricks_workspace.metastore_id
  description = "Unity Catalog metastore ID"
}

output "metastore_bucket" {
  value       = module.databricks_workspace.metastore_bucket
  description = "Unity Catalog metastore S3 bucket name"
}

output "unity_catalog_role_arn" {
  value       = module.databricks_workspace.unity_catalog_role_arn
  description = "Unity Catalog IAM role ARN"
}

output "unity_catalog_role_name" {
  value       = module.databricks_workspace.unity_catalog_role_name
  description = "Unity Catalog IAM role name"
}

# ==================== IAM OUTPUTS ====================
output "cross_account_role_arn" {
  value       = module.databricks_workspace.cross_account_role_arn
  description = "Cross-account IAM role ARN"
}

output "root_bucket_name" {
  value       = module.databricks_workspace.root_bucket_name
  description = "Workspace root S3 bucket name"
}

# ==================== CONFIGURATION INFO ====================
output "deployment_mode" {
  value       = module.databricks_workspace.deployment_mode
  description = "Shows whether resources were created or existing resources were used"
}

