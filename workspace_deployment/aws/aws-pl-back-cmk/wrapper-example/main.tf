# Example wrapper that uses the Terraform configuration as a module
# This allows you to reuse the same infrastructure pattern for multiple workspaces

terraform {
  required_version = ">= 1.5.0"
}

module "databricks_workspace" {
  # Source points to your existing terraform directory
  source = "../terraform"

  # Core Configuration
  project = var.project
  region  = var.region

  # Networking Configuration
  create_new_vpc             = var.create_new_vpc
  vpc_cidr                   = var.vpc_cidr
  private_subnet_cidrs       = var.private_subnet_cidrs
  existing_vpc_id            = var.existing_vpc_id
  existing_subnet_ids        = var.existing_subnet_ids
  existing_security_group_id = var.existing_security_group_id

  # CMK Configuration
  create_new_cmk   = var.create_new_cmk
  existing_cmk_arn = var.existing_cmk_arn

  # Databricks Configuration
  databricks_account_id                    = var.databricks_account_id
  databricks_account_host                  = var.databricks_account_host
  databricks_client_id                     = var.databricks_client_id
  databricks_client_secret                 = var.databricks_client_secret
  databricks_crossaccount_role_external_id = var.databricks_crossaccount_role_external_id

  # Storage & PrivateLink
  root_bucket_name       = var.root_bucket_name
  pl_service_names       = var.pl_service_names
  enable_extra_endpoints = var.enable_extra_endpoints
}

