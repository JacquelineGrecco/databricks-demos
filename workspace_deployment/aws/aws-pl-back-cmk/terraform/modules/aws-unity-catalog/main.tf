# Unity Catalog metastore bucket
resource "aws_s3_bucket" "metastore" {
  bucket        = "${var.prefix}-unity-catalog-${var.region}"
  force_destroy = true
}

resource "aws_s3_bucket_ownership_controls" "metastore" {
  bucket = aws_s3_bucket.metastore.id
  rule {
    object_ownership = "BucketOwnerPreferred"
  }
}

resource "aws_s3_bucket_versioning" "metastore" {
  bucket = aws_s3_bucket.metastore.id
  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "metastore" {
  bucket = aws_s3_bucket.metastore.id
  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm     = "aws:kms"
      kms_master_key_id = var.kms_key_arn
    }
    bucket_key_enabled = true
  }
}

resource "aws_s3_bucket_public_access_block" "metastore" {
  bucket                  = aws_s3_bucket.metastore.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
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
      /usr/local/bin/aws iam update-assume-role-policy \
        --role-name ${aws_iam_role.unity_catalog.name} \
        --policy-document file://${abspath(local_file.trust_policy.filename)}
    EOT
  }

  depends_on = [
    aws_iam_role.unity_catalog,
    local_file.trust_policy
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
          aws_s3_bucket.metastore.arn,
          "${aws_s3_bucket.metastore.arn}/*"
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

# Bucket policy for Unity Catalog
data "aws_iam_policy_document" "metastore_bucket_policy" {
  statement {
    sid    = "Grant Unity Catalog Access"
    effect = "Allow"
    actions = [
      "s3:GetObject",
      "s3:GetObjectVersion",
      "s3:PutObject",
      "s3:PutObjectAcl",
      "s3:DeleteObject",
      "s3:ListBucket",
      "s3:GetBucketLocation"
    ]
    resources = [
      aws_s3_bucket.metastore.arn,
      "${aws_s3_bucket.metastore.arn}/*"
    ]
    principals {
      type = "AWS"
      identifiers = [
        aws_iam_role.unity_catalog.arn
      ]
    }
  }
}

resource "aws_s3_bucket_policy" "metastore" {
  bucket = aws_s3_bucket.metastore.id
  policy = data.aws_iam_policy_document.metastore_bucket_policy.json
}

