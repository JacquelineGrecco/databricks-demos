# Variables for the wrapper - just declarations
# Values are provided in terraform.tfvars

variable "project" {
  type        = string
  description = "Project name for resource naming"
}

variable "region" {
  type        = string
  description = "AWS region"
}

# ==================== NETWORKING OPTIONS ====================
variable "create_new_vpc" {
  type        = bool
  default     = true
  description = "Set to true to create new VPC, false to use existing VPC"
}

variable "vpc_cidr" {
  type        = string
  default     = ""
  description = "CIDR block for new VPC (required if create_new_vpc = true)"
}

variable "private_subnet_cidrs" {
  type        = list(string)
  default     = []
  description = "Two CIDR blocks in distinct AZs (required if create_new_vpc = true)"
}

variable "existing_vpc_id" {
  type        = string
  default     = ""
  description = "ID of existing VPC (required if create_new_vpc = false)"
}

variable "existing_subnet_ids" {
  type        = list(string)
  default     = []
  description = "List of existing subnet IDs in different AZs (required if create_new_vpc = false)"
}

variable "existing_security_group_id" {
  type        = string
  default     = ""
  description = "ID of existing security group for Databricks workspace (optional)"
}

# ==================== CMK OPTIONS ====================
variable "create_new_cmk" {
  type        = bool
  default     = true
  description = "Set to true to create new CMK, false to use existing CMK"
}

variable "existing_cmk_arn" {
  type        = string
  default     = ""
  description = "ARN of existing KMS CMK (required if create_new_cmk = false)"
}

# ==================== DATABRICKS ====================
variable "databricks_account_id" {
  type        = string
  description = "Databricks account ID"
}

variable "databricks_account_host" {
  type        = string
  default     = "https://accounts.cloud.databricks.com"
  description = "Databricks account console host"
}

variable "databricks_client_id" {
  type        = string
  sensitive   = true
  description = "Databricks service principal client ID"
}

variable "databricks_client_secret" {
  type        = string
  sensitive   = true
  description = "Databricks service principal client secret"
}

variable "databricks_crossaccount_role_external_id" {
  type        = string
  description = "External ID for Databricks cross-account role"
  default     = var.databricks_account_id
}

# ==================== STORAGE & PRIVATELINK ====================
variable "root_bucket_name" {
  type        = string
  description = "S3 bucket name for workspace storage"
}

variable "pl_service_names" {
  type = object({
    workspace = string
    scc       = string
  })
  description = "PrivateLink VPC endpoint service names for your region"
}

variable "enable_extra_endpoints" {
  type        = bool
  default     = false
  description = "Enable additional VPC endpoints (STS, Kinesis, S3)"
}

