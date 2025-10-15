variable "prefix" {
  type        = string
  description = "Prefix for resource names"
}

variable "region" {
  type        = string
  description = "AWS region"
}

variable "databricks_account_id" {
  type        = string
  description = "Databricks account ID"
}

variable "cross_account_role_arn" {
  type        = string
  description = "ARN of the Databricks cross-account IAM role"
}

variable "kms_key_arn" {
  type        = string
  description = "ARN of the KMS key for S3 encryption"
}

variable "root_bucket_name" {
  type        = string
  description = "Name of the root S3 bucket to use for Unity Catalog metastore"
}

