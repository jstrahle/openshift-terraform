# OCM Cluster Import

Terraform module to import an OpenShift cluster into Red Hat Advanced Cluster Management (ACM).

## Description

This module creates the necessary resources to attach an existing OpenShift cluster to an ACM hub cluster:

- **ManagedCluster** - Registers the cluster with ACM
- **Auto-import Secret** - Contains authentication credentials for cluster access
- **KlusterletAddonConfig** - Configures cluster management addons (monitoring, policy enforcement, etc.)
- **Namespace** - Creates dedicated namespace for cluster management

## Required variables
- cluster_name - Name of the cluster to import
- cluster_group - Cluster group label for organization
- kube_token - API token for the target cluster
- kube_server - API server URL for the target cluster

You can get the API token and URL by logging into you OCP instance and clicking you username on top right corner, and selecting "Copy login command".
