# Unity Catalog uses the root bucket with a subdirectory
# No separate S3 bucket needed - simpler infrastructure!
locals {
  metastore_bucket_name = var.root_bucket_name
  metastore_path        = "unity-catalog"
}

data "aws_caller_identity" "current" {}

# IAM role for Unity Catalog to access the metastore bucket
# Created in two stages to avoid circular dependency:
# Stage 1: Create role without self-assuming (initial creation)
# Stage 2: Update role to include self-assuming (after role ARN is available)
resource "aws_iam_role" "unity_catalog" {
  name = "${var.prefix}-unity-catalog-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          AWS = "arn:aws:iam::414351767826:root"
        }
        Action = "sts:AssumeRole"
        Condition = {
          StringEquals = {
            "sts:ExternalId" = var.databricks_account_id
          }
        }
      }
    ]
  })
}

# Update the IAM role trust policy to add self-assuming capability
# This runs AFTER the role is created, using the actual role ARN
resource "aws_iam_role_policy_attachment" "unity_catalog_self_assume" {
  role       = aws_iam_role.unity_catalog.name
  policy_arn = aws_iam_policy.unity_catalog_self_assume.arn

  depends_on = [aws_iam_role.unity_catalog]
}

# Policy that allows the role to assume itself
resource "aws_iam_policy" "unity_catalog_self_assume" {
  name        = "${var.prefix}-unity-catalog-self-assume"
  description = "Allows Unity Catalog role to assume itself"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect   = "Allow"
        Action   = "sts:AssumeRole"
        Resource = aws_iam_role.unity_catalog.arn
      }
    ]
  })
}

# Generate the updated trust policy document
# Using constructed ARN to avoid circular dependency
locals {
  unity_catalog_role_arn = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:role/${var.prefix}-unity-catalog-role"

  updated_trust_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          AWS = "arn:aws:iam::414351767826:root"
        }
        Action = "sts:AssumeRole"
        Condition = {
          StringEquals = {
            "sts:ExternalId" = var.databricks_account_id
          }
        }
      },
      {
        Effect = "Allow"
        Principal = {
          AWS = local.unity_catalog_role_arn
        }
        Action = "sts:AssumeRole"
      }
    ]
  })
}

# Create a temporary file with the trust policy in the root directory
resource "local_file" "trust_policy" {
  content  = local.updated_trust_policy
  filename = "${path.root}/.trust_policy_${var.prefix}.json"
}

# Wait for IAM role to propagate before updating trust policy
# Increased to 60s to ensure the role exists in all regions
resource "time_sleep" "wait_for_role_propagation" {
  create_duration = "60s"

  depends_on = [
    aws_iam_role.unity_catalog,
    aws_iam_role_policy.unity_catalog,
    local_file.trust_policy
  ]
}

# Update trust policy using null_resource and AWS CLI
# This adds self-assuming to the trust relationship after the role is created
resource "null_resource" "update_trust_policy" {
  triggers = {
    role_name    = aws_iam_role.unity_catalog.name
    trust_policy = local.updated_trust_policy
  }

  provisioner "local-exec" {
    interpreter = ["/bin/bash", "-c"]
    command     = <<-EOT
      export AWS_PAGER=""
      aws iam update-assume-role-policy \
        --role-name ${aws_iam_role.unity_catalog.name} \
        --policy-document file://${abspath(local_file.trust_policy.filename)}
    EOT
  }

  depends_on = [
    time_sleep.wait_for_role_propagation
  ]
}

resource "aws_iam_role_policy" "unity_catalog" {
  name = "${var.prefix}-unity-catalog-policy"
  role = aws_iam_role.unity_catalog.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "s3:GetObject",
          "s3:GetObjectVersion",
          "s3:PutObject",
          "s3:PutObjectAcl",
          "s3:DeleteObject",
          "s3:ListBucket",
          "s3:GetBucketLocation"
        ]
        Resource = [
          "arn:aws:s3:::${local.metastore_bucket_name}",
          "arn:aws:s3:::${local.metastore_bucket_name}/*"
        ]
      },
      {
        Effect = "Allow"
        Action = [
          "kms:Decrypt",
          "kms:Encrypt",
          "kms:GenerateDataKey"
        ]
        Resource = [
          var.kms_key_arn
        ]
      },
      {
        Effect   = "Allow"
        Action   = "sts:AssumeRole"
        Resource = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:role/${var.prefix}-unity-catalog-role"
      }
    ]
  })
}

# No separate bucket policy needed - root bucket already has the necessary policy
# Unity Catalog IAM role will use the root bucket's existing policy

