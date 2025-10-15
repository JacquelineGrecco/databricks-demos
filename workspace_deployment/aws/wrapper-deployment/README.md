# Wrapper Example - Using Databricks Module

This wrapper demonstrates how to use the Databricks Private Link + CMK Terraform configuration as a reusable module.

## Directory Structure

```
databricks-demos/workspace_deployment/aws/aws-pl-back-cmk/
├── terraform/                    # The actual module (your existing code)
│   ├── main.tf
│   ├── variables.tf
│   ├── outputs.tf
│   └── modules/
│       ├── aws-cmk/
│       ├── aws-iam/
│       ├── aws-network/
│       ├── aws-storage/
│       └── aws-unity-catalog/
└── wrapper-example/              # Example wrapper (this directory)
    ├── main.tf                   # Calls the module
    ├── variables.tf              # Variable declarations
    ├── outputs.tf                # Pass-through outputs
    └── terraform.tfvars          # Your values
```

## How to Use

### Option A: Use Wrapper Directly

```bash
cd wrapper-example
terraform init
terraform plan
terraform apply
```

### Option B: Create Multiple Environments

Create separate directories for each environment:

```
my-databricks-workspaces/
├── modules/
│   └── databricks-pl-cmk/       # Copy or symlink your terraform/ directory here
├── dev/
│   ├── main.tf                  # Points to ../modules/databricks-pl-cmk
│   ├── variables.tf
│   ├── terraform.tfvars         # Dev-specific values
│   └── backend.tf               # Dev state backend
├── staging/
│   ├── main.tf
│   ├── variables.tf
│   ├── terraform.tfvars         # Staging-specific values
│   └── backend.tf               # Staging state backend
└── prod/
    ├── main.tf
    ├── variables.tf
    ├── terraform.tfvars         # Prod-specific values
    └── backend.tf               # Prod state backend
```

### Option C: Use Git Source

Push your `terraform/` directory to a Git repository and reference it:

```hcl
module "databricks_workspace" {
  source = "git::https://github.com/your-org/databricks-pl-cmk.git//terraform?ref=v1.0.0"
  
  project = "my-workspace"
  region  = "us-east-1"
  # ... other variables
}
```

## Benefits of This Approach

1. **Reusability**: Use the same module for multiple workspaces
2. **Version Control**: Pin to specific versions of the module
3. **Easy Updates**: Update the module once, affects all workspaces
4. **Environment Separation**: Each workspace has its own state file
5. **Consistent Configuration**: Same infrastructure pattern everywhere

## Example: Deploy Multiple Workspaces

### Dev Workspace
```bash
cd dev/
terraform apply -var="project=dev-workspace" -var="vpc_cidr=10.10.0.0/16"
```

### Staging Workspace
```bash
cd staging/
terraform apply -var="project=staging-workspace" -var="vpc_cidr=10.20.0.0/16"
```

### Prod Workspace
```bash
cd prod/
terraform apply -var="project=prod-workspace" -var="vpc_cidr=10.30.0.0/16"
```

## State Management

For production, use remote state:

```hcl
# backend.tf
terraform {
  backend "s3" {
    bucket         = "my-terraform-state"
    key            = "databricks/dev/terraform.tfstate"
    region         = "us-east-1"
    encrypt        = true
    dynamodb_table = "terraform-state-lock"
  }
}
```

## Next Steps

1. Copy this wrapper-example to your desired location
2. Update `terraform.tfvars` with your values
3. Run `terraform init`
4. Run `terraform plan` to verify
5. Run `terraform apply` to deploy

For multiple environments, create separate directories for each!

