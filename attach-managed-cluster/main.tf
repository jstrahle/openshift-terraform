# Open Cluster Management - Cluster Import Terraform Template

terraform {
  required_version = ">= 1.0"
  
  required_providers {
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 2.0"
    }
  }
}

# Variables
variable "cluster_name" {
  description = "Name of the cluster to import (used for both name and namespace)"
  type        = string
}

variable "cluster_group" {
  description = "Cluster group label"
  type        = string
}

variable "kube_token" {
  description = "API token for the cluster to import"
  type        = string
  sensitive   = true
}

variable "kube_server" {
  description = "API server URL for the cluster to import"
  type        = string
}

variable "auto_import_retry" {
  description = "Number of auto import retries"
  type        = string
  default     = "2"
}

variable "additional_labels" {
  description = "Additional labels for the cluster"
  type        = map(string)
  default     = {}
}

variable "addon_config" {
  description = "KlusterletAddonConfig settings"
  type = object({
    application_manager     = optional(bool, true)
    policy_controller      = optional(bool, true)
    search_collector       = optional(bool, true)
    cert_policy_controller = optional(bool, true)
  })
  default = {}
}

# Provider
provider "kubernetes" {
  config_path = "~/.kube/config"
}

# Local values for labels
locals {
  cluster_labels = merge({
    name         = var.cluster_name
    cloud        = "auto-detect"
    vendor       = "auto-detect"
    clusterGroup = var.cluster_group
    group-one    = ""
  }, var.additional_labels)
}

# Create namespace for the imported cluster
resource "kubernetes_namespace" "cluster_namespace" {
  metadata {
    name = var.cluster_name
    labels = {
      name = var.cluster_name
    }
  }
}

# ManagedCluster resource
resource "kubernetes_manifest" "managed_cluster" {
  manifest = {
    apiVersion = "cluster.open-cluster-management.io/v1"
    kind       = "ManagedCluster"
    metadata = {
      name        = var.cluster_name
      labels      = local.cluster_labels
      annotations = {}
    }
    spec = {
      hubAcceptsClient = true
    }
  }

}

# Auto-import secret
resource "kubernetes_secret" "auto_import_secret" {
  depends_on = [kubernetes_namespace.cluster_namespace]

  metadata {
    name      = "auto-import-secret"
    namespace = var.cluster_name
  }
  type = "Opaque"
  data = {
    autoImportRetry = var.auto_import_retry
    token      = var.kube_token
    server     = var.kube_server
  }
}



# KlusterletAddonConfig
resource "kubernetes_manifest" "klusterlet_addon_config" {
  depends_on = [kubernetes_namespace.cluster_namespace]

  manifest = {
    apiVersion = "agent.open-cluster-management.io/v1"
    kind       = "KlusterletAddonConfig"
    metadata = {
      name      = var.cluster_name
      namespace = var.cluster_name
    }
    spec = {
      clusterName      = var.cluster_name
      clusterNamespace = var.cluster_name
      clusterLabels    = local.cluster_labels
      applicationManager = {
        enabled = var.addon_config.application_manager
      }
      policyController = {
        enabled = var.addon_config.policy_controller
      }
      searchCollector = {
        enabled = var.addon_config.search_collector
      }
      certPolicyController = {
        enabled = var.addon_config.cert_policy_controller
      }
    }
  }

}

# Outputs
output "cluster_name" {
  description = "Name of the imported cluster"
  value       = var.cluster_name
}

output "cluster_namespace" {
  description = "Namespace created for the cluster"
  value       = kubernetes_namespace.cluster_namespace.metadata[0].name
}

output "cluster_labels" {
  description = "Labels applied to the cluster"
  value       = local.cluster_labels
}

output "verification_commands" {
  description = "Commands to verify the cluster import"
  value = [
    "# Check ManagedCluster status:",
    "oc get managedcluster ${var.cluster_name}",
    "",
    "# Check cluster namespace:",
    "oc get namespace ${var.cluster_name}",
    "",
    "# Check auto-import secret:",
    "oc get secret auto-import-secret -n ${var.cluster_name}",
    "",
    "# Check KlusterletAddonConfig:",
    "oc get klusterletaddonconfig ${var.cluster_name} -n ${var.cluster_name}",
    "",
    "# Check cluster import status:",
    "oc get managedcluster ${var.cluster_name} -o jsonpath='{.status.conditions}'",
    "",
    "# Check klusterlet status:",
    "oc get klusterletaddonconfig ${var.cluster_name} -n ${var.cluster_name} -o yaml"
  ]
}
