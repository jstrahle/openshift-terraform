# Validated Patterns Operator Installation with Terraform

terraform {
  required_version = ">= 1.0"
  
  required_providers {
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 2.0"
    }
    kubectl = {
      source  = "gavinbunney/kubectl"
      version = ">= 1.14.0"
    }
  }
}

# Variables
variable "operator_namespace" {
  description = "Namespace for the Validated Patterns operator"
  type        = string
  default     = "openshift-operators"
}

variable "channel" {
  description = "Operator channel"
  type        = string
  default     = "fast"
}

variable "install_plan_approval" {
  description = "Install plan approval mode"
  type        = string
  default     = "Automatic"
}

variable "starting_csv" {
  description = "Starting CSV version (optional)"
  type        = string
  default     = "patterns-operator.v0.0.61"
}

# Providers
provider "kubernetes" {
  config_path = "~/.kube/config"
}
provider "kubectl" {
  config_path = "~/.kube/config"
}


# Create Subscription for Validated Patterns Operator
resource "kubernetes_manifest" "validated_patterns_subscription" {

  manifest = {
    apiVersion = "operators.coreos.com/v1alpha1"
    kind       = "Subscription"
    metadata = {
      name      = "patterns-operator"
      namespace = var.operator_namespace
      labels = {
        "operators.coreos.com/patterns-operator.${var.operator_namespace}" = ""
      }
    }
    spec = {
      channel             = var.channel
      name                = "patterns-operator"
      source              = "community-operators"
      sourceNamespace     = "openshift-marketplace"
      installPlanApproval = var.install_plan_approval
      startingCSV         = var.starting_csv != "" ? var.starting_csv : null
    }
  }
}

# Wait for operator to be ready
resource "kubernetes_manifest" "wait_for_operator" {
  depends_on = [kubernetes_manifest.validated_patterns_subscription]
  
  manifest = {
    apiVersion = "v1"
    kind       = "ConfigMap"
    metadata = {
      name      = "validated-patterns-operator-check"
      namespace = var.operator_namespace
    }
    data = {
      check = "operator-installed"
    }
  }

  wait {
    fields = {
    "data.check" = "operator-installed"
    }
  }

  provisioner "local-exec" {
    command = <<-EOT
      echo "Waiting for Validated Patterns operator to be ready..."
      timeout=300
      while [ $timeout -gt 0 ]; do
        if oc get csv -n ${var.operator_namespace} | grep -q "patterns-operator.*Succeeded"; then
          echo "✅ Validated Patterns operator is ready"
          break
        fi
        echo "⏳ Waiting for operator installation... ($timeout seconds left)"
        sleep 10
        timeout=$((timeout - 10))
      done
      
      if [ $timeout -le 0 ]; then
        echo "❌ Timeout waiting for operator installation"
        echo "Check the installation with: oc get csv -n ${var.operator_namespace}"
        exit 1
      fi
    EOT
  }
}

resource "kubectl_manifest" "validated_patterns_pattern" {
  depends_on = [kubernetes_manifest.validated_patterns_subscription]
  
  yaml_body = yamlencode({
    apiVersion = "gitops.hybrid-cloud-patterns.io/v1alpha1"
    kind       = "Pattern"
    metadata = {
      name      = "my-pattern-example"
      namespace = var.operator_namespace
    }
    spec = {
      gitSpec = {
        inClusterGitServer = false
        pollInterval       = 180
        targetRepo         = "https://github.com/jstrahle/multicloud-gitops.git"
        targetRevision     = "my-branch"
      }
      clusterGroupName = "hub"
    }
  })

  server_side_apply = true
  wait             = true
  
  timeouts {
    create = "15m"
    update = "10m"
    delete = "10m"
  }
}

# Outputs
output "subscription_name" {
  description = "Name of the operator subscription"
  value       = "patterns-operator"
}

output "operator_namespace" {
  description = "Namespace where the operator is installed"
  value       = var.operator_namespace
}

output "verification_commands" {
  description = "Commands to verify the operator installation"
  value = [
    "# Check subscription status:",
    "oc get subscription patterns-operator -n ${var.operator_namespace}",
    "",
    "# Check CSV (ClusterServiceVersion):",
    "oc get csv -n ${var.operator_namespace} | grep patterns",
    "",
    "# Check operator pods:",
    "oc get pods -n ${var.operator_namespace} | grep patterns",
    "",
    "# Check operator logs:",
    "oc logs -n ${var.operator_namespace} -l name=patterns-operator",
    "",
    "# Check available CRDs:",
    "oc get crd | grep patterns",
    "",
    "# Example Pattern creation:",
    "cat <<EOF | oc apply -f -",
    "apiVersion: gitops.hybrid-cloud-patterns.io/v1alpha1",
    "kind: Pattern",
    "metadata:",
    "  name: example-pattern",
    "  namespace: default",
    "spec:",
    "  gitSpec:",
    "    hostname: github.com",
    "    account: hybrid-cloud-patterns",
    "    repo: example-pattern",
    "    revision: main",
    "EOF"
  ]
}