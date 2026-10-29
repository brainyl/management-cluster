# General Configuration
variable "aws_region" {
  description = "AWS region for the management cluster"
  type        = string
  default     = "us-west-2"
}

variable "environment" {
  description = "Environment name (e.g., production, staging)"
  type        = string
  default     = "production"
}

variable "cluster_name" {
  description = "Name of the EKS cluster"
  type        = string
}

# VPC Configuration
variable "vpc_cidr" {
  description = "CIDR block for VPC"
  type        = string
  default     = "10.0.0.0/16"
}

variable "availability_zones" {
  description = "List of availability zones"
  type        = list(string)
  default     = ["us-west-2a", "us-west-2b", "us-west-2c"]
}

variable "private_subnet_cidrs" {
  description = "CIDR blocks for private subnets"
  type        = list(string)
  default     = ["10.0.1.0/24", "10.0.2.0/24", "10.0.3.0/24"]
}

variable "public_subnet_cidrs" {
  description = "CIDR blocks for public subnets"
  type        = list(string)
  default     = ["10.0.101.0/24", "10.0.102.0/24", "10.0.103.0/24"]
}

variable "enable_nat_gateway" {
  description = "Enable NAT Gateway for private subnets"
  type        = bool
  default     = true
}

variable "single_nat_gateway" {
  description = "Use a single NAT Gateway for all private subnets (cost optimization)"
  type        = bool
  default     = false
}

# EKS Configuration
variable "cluster_version" {
  description = "Kubernetes version for EKS cluster"
  type        = string
  default     = "1.37"
}

# Crossplane Pod Identity Configuration
variable "crossplane_namespace" {
  description = "Kubernetes namespace for Crossplane"
  type        = string
  default     = "crossplane-system"
}

variable "crossplane_service_account_name" {
  description = "Service account name used by all Crossplane providers (via DeploymentRuntimeConfig)"
  type        = string
  default     = "crossplane-provider-aws"
}

variable "crossplane_member_account_ids" {
  description = "List of AWS account IDs that Crossplane can assume roles in"
  type        = list(string)
  default     = []
}

variable "crossplane_member_account_role_name" {
  description = "IAM role name in member accounts that Crossplane will assume"
  type        = string
  default     = "crossplane-provider-aws"
}

# ArgoCD Configuration
variable "argocd_chart_version" {
  description = "ArgoCD Helm chart version"
  type        = string
  default     = "10.10.5"
}

variable "argocd_server_service_type" {
  description = "ArgoCD server Service type (LoadBalancer or ClusterIP)"
  type        = string
  default     = "ClusterIP"
}

variable "create_root_application" {
  description = "Create ArgoCD root Application pointing to control-plane repo"
  type        = bool
  default     = false
}

variable "root_automated_sync" {
  description = "Automatically sync the root application and its downstream applications"
  type        = bool
  default     = false
}

variable "root_application_name" {
  description = "Name of the ArgoCD root Application"
  type        = string
  default     = "control-plane-root"
}

variable "control_plane_repo_url" {
  description = "Git repository URL for control-plane configuration"
  type        = string
  default     = ""
}

variable "control_plane_target_revision" {
  description = "Git branch/tag for control-plane repo"
  type        = string
  default     = "main"
}

variable "control_plane_chart_path" {
  description = "Path to Helm chart in control-plane repo"
  type        = string
  default     = "charts/root-app"
}

variable "root_destination_namespace" {
  description = "Namespace for root Application deployment"
  type        = string
  default     = "argocd"
}

variable "argocd_ingress_enabled" {
  description = "Enable ALB Ingress for ArgoCD"
  type        = bool
  default     = false
}

variable "argocd_ingress_scheme" {
  description = "ALB scheme (internet-facing or internal)"
  type        = string
  default     = "internet-facing"
}

# Crossplane Configuration
variable "crossplane_chart_version" {
  description = "Crossplane Helm chart version"
  type        = string
  default     = "2.4.3"
}

variable "enable_composition_webhook_schema_validation" {
  description = "Enable composition webhook schema validation"
  type        = bool
  default     = true
}

variable "install_aws_providers" {
  description = "Install AWS provider family (EC2, EKS, IAM)"
  type        = bool
  default     = true
}

variable "aws_provider_version" {
  description = "Version of Upbound AWS provider family"
  type        = string
  default     = "v2.9.3"
}

variable "create_provider_config" {
  description = "Create ProviderConfig for AWS providers"
  type        = bool
  default     = true
}

variable "provider_config_name" {
  description = "Name of the ProviderConfig resource"
  type        = string
  default     = "default"
}

# Tagging and Labeling Configuration
variable "project_name" {
  description = "Project name for resource tagging"
  type        = string
  default     = "crossplane-control-plane"
}

variable "owner" {
  description = "Owner or team responsible for the resources"
  type        = string
  default     = "platform-team"
}

variable "cost_center" {
  description = "Cost center for billing and chargeback"
  type        = string
  default     = "engineering"
}

variable "git_repo_url" {
  description = "Git repository URL for infrastructure code"
  type        = string
  default     = ""
}

variable "additional_tags" {
  description = "Additional AWS tags to apply to all resources (merged with standard tags)"
  type        = map(string)
  default     = {}
}

variable "additional_k8s_labels" {
  description = "Additional Kubernetes labels to apply to all K8s resources (merged with standard labels)"
  type        = map(string)
  default     = {}
}

# External Secrets Operator Configuration
variable "eso_chart_version" {
  description = "External Secrets Operator Helm chart version"
  type        = string
  default     = "2.3.0"
}

variable "eso_service_account_name" {
  description = "Service account name for External Secrets Operator"
  type        = string
  default     = "external-secrets"
}

# GitHub Repository Secret Configuration
variable "github_token" {
  description = "GitHub personal access token for repository access"
  type        = string
  sensitive   = true
  default     = ""
}

variable "github_repos" {
  description = "List of GitHub repository URLs for ArgoCD connections"
  type        = list(string)
  default     = []
}

variable "crossplane_schema_revision" {
  description = "Root Crossplane schema revision; bump after installing expanded XRDs"
  type        = string
  default     = "2026-10-24-operator-access"
}
