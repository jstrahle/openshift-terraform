# Validated Patterns Operator

Terraform module to install the Validated Patterns operator on OpenShift and deploy a pattern.

## Description

This module:
- Installs the Validated Patterns operator via OLM
- Waits for operator readiness
- Creates a Pattern resource pointing to your Git repository

## Required variables
- pattern_name - Name of the pattern to install
- pattern_repo - Git repository URL containing the pattern
- pattern_branch - Git branch to use
