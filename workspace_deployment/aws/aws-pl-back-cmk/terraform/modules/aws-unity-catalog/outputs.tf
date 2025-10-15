output "metastore_bucket_name" {
  description = "Name of the Unity Catalog metastore bucket (same as root bucket)"
  value       = local.metastore_bucket_name
}

output "metastore_bucket_arn" {
  description = "ARN of the Unity Catalog metastore bucket (same as root bucket)"
  value       = "arn:aws:s3:::${local.metastore_bucket_name}"
}

output "metastore_path" {
  description = "Path within the bucket used for Unity Catalog metastore"
  value       = local.metastore_path
}

output "unity_catalog_role_arn" {
  description = "ARN of the Unity Catalog IAM role (with self-assuming enabled)"
  value       = aws_iam_role.unity_catalog.arn
}

output "unity_catalog_role_id" {
  description = "ID of the Unity Catalog IAM role"
  value       = aws_iam_role.unity_catalog.id
}

output "unity_catalog_role_name" {
  description = "Name of the Unity Catalog IAM role"
  value       = aws_iam_role.unity_catalog.name
}

output "trust_policy_updated" {
  description = "Indicates that the trust policy has been updated with self-assuming capability"
  value       = null_resource.update_trust_policy.id
  depends_on  = [null_resource.update_trust_policy]
}

