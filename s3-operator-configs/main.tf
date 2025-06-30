# Complete Terraform configuration for ACK S3 Controller with RHCS provider
# This automatically fetches cluster information and sets up everything

terraform {
  required_version = ">= 1.0"
  
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    rhcs = {
      source  = "terraform-redhat/rhcs"
      version = ">= 1.6.0"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 2.0"
    }
    http = {
      source  = "hashicorp/http"
      version = "~> 3.0"
    }
  }
}

# Variables
variable "cluster_id" {
  description = "ROSA cluster ID or name"
  type        = string
}

variable "aws_region" {
  description = "AWS region"
  type        = string
  default     = "us-west-2"
}

variable "environment" {
  description = "Environment name"
  type        = string
  default     = "dev"
}

variable "service" {
  description = "ACK service name"
  type        = string
  default     = "s3"
}

# RHCS authentication variables (optional - can use environment variables instead)
variable "rhcs_token" {
  description = "Red Hat Cloud Services API token"
  type        = string
  sensitive   = true
}

variable "rhcs_url" {
  description = "Red Hat Cloud Services API URL"
  type        = string
  default     = "https://api.openshift.com"
}

# Providers
provider "aws" {
  region = var.aws_region
}

# RHCS provider with authentication
# You can configure this in several ways (see variables below)
provider "rhcs" {
token = var.rhcs_token
}

provider "kubernetes" {
  config_path = "~/.kube/config"
}

# Data sources - Get cluster information from ROSA
data "rhcs_cluster_rosa_classic" "cluster" {
  id = var.cluster_id
}

# Validation to ensure cluster data is available
locals {
  cluster_validation = data.rhcs_cluster_rosa_classic.cluster.id != null ? true : false
}

# Get current AWS account
data "aws_caller_identity" "current" {}

# Fetch ACK policies
data "http" "policy_arns" {
  url = "https://raw.githubusercontent.com/aws-controllers-k8s/${var.service}-controller/main/config/iam/recommended-policy-arn"
}

data "http" "inline_policy" {
  url = "https://raw.githubusercontent.com/aws-controllers-k8s/${var.service}-controller/main/config/iam/recommended-inline-policy"
}

# Local values
locals {
  cluster_name         = data.rhcs_cluster_rosa_classic.cluster.name
  oidc_provider        = replace(data.rhcs_cluster_rosa_classic.cluster.sts.oidc_endpoint_url, "https://", "")
  ack_namespace        = "ack-system"
  service_account_name = "ack-${var.service}-controller"
  iam_role_name        = "ack-${var.service}-controller-${local.cluster_name}-${var.environment}"
  policy_arns          = [for arn in split("\n", trimspace(data.http.policy_arns.response_body)) : arn if arn != ""]
}

# Create IAM role for ACK controller
resource "aws_iam_role" "ack_controller" {
  name = local.iam_role_name

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Federated = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:oidc-provider/${local.oidc_provider}"
        }
        Action = "sts:AssumeRoleWithWebIdentity"
        Condition = {
          StringEquals = {
            "${local.oidc_provider}:sub" = "system:serviceaccount:${local.ack_namespace}:${local.service_account_name}"
          }
        }
      }
    ]
  })

  tags = {
    Purpose     = "ACK-${var.service}-Controller"
    Cluster     = local.cluster_name
    Environment = var.environment
    ManagedBy   = "terraform"
  }
}

# Attach recommended policies to IAM role
resource "aws_iam_role_policy_attachment" "ack_controller_policies" {
  depends_on = [aws_iam_role.ack_controller]
  count      = length(local.policy_arns)
  role       = aws_iam_role.ack_controller.name
  policy_arn = local.policy_arns[count.index]
}

# Create ConfigMap for ACK controller
resource "kubernetes_config_map" "ack_user_config" {
  depends_on = [aws_iam_role.ack_controller]
  metadata {
    name      = "ack-${var.service}-user-config"
    namespace = local.ack_namespace
  }

  data = {
    ACK_ENABLE_DEVELOPMENT_LOGGING         = var.environment == "prod" ? "false" : "true"
    ACK_LOG_LEVEL                          = var.environment == "prod" ? "info" : "debug"
    ACK_WATCH_NAMESPACE                    = ""
    AWS_REGION                             = var.aws_region
    AWS_ENDPOINT_URL                       = ""
    ACK_RESOURCE_TAGS                      = "rosa_cluster_ack,environment=${var.environment}"
    ENABLE_LEADER_ELECTION                 = "true"
    LEADER_ELECTION_NAMESPACE              = ""
    RECONCILE_DEFAULT_MAX_CONCURRENT_SYNCS = "1"
    FEATURE_FLAGS                          = ""
    FEATURE_GATES                          = ""
  }
}

# Annotate service account with IAM role ARN
resource "kubernetes_annotations" "service_account_patch" {
  depends_on = [aws_iam_role.ack_controller]

  kind       = "ServiceAccount"
  metadata = {
    name      = local.service_account_name
    namespace = local.ack_namespace
  }
  annotations = {
    "eks.amazonaws.com/role-arn" = aws_iam_role.ack_controller.arn
  }
}


# Restart deployment to pick up new service account annotation
resource "kubernetes_annotations" "restart_deployment" {
  depends_on = [kubernetes_annotations.service_account_patch]

  kind       = "Deployment"
  metadata = {
    name      = "ack-${var.service}-controller"
    namespace = local.ack_namespace
  }
  annotations = {
    "kubectl.kubernetes.io/restartedAt" = timestamp()
  }
}
 

# Outputs
output "cluster_name" {
  description = "ROSA cluster name"
  value       = local.cluster_name
}

output "oidc_provider" {
  description = "OIDC provider URL"
  value       = data.rhcs_cluster_rosa_classic.cluster.sts.oidc_endpoint_url
}

output "iam_role_arn" {
  description = "ARN of the created IAM role"
  value       = aws_iam_role.ack_controller.arn
}

output "iam_role_name" {
  description = "Name of the created IAM role"
  value       = aws_iam_role.ack_controller.name
}

output "service_account_name" {
  description = "Name of the service account"
  value       = local.service_account_name
}

output "cluster_info" {
  description = "Complete cluster information"
  value = {
    cluster_id        = var.cluster_id
    cluster_name      = local.cluster_name
    oidc_provider     = local.oidc_provider
    aws_account_id    = data.aws_caller_identity.current.account_id
    environment       = var.environment
    service           = var.service
  }
}