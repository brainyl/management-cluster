variable "namespace" {
  description = "Kubernetes namespace for Argo CD"
  type        = string
  default     = "argocd"
}

variable "chart_version" {
  description = "argo-helm chart version (argo-cd); pin for reproducible workshops"
  type        = string
  default     = "10.10.5"
}

variable "server_service_type" {
  description = "Argo CD server Service type (LoadBalancer for public demo; ClusterIP + port-forward is stricter)"
  type        = string
  default     = "ClusterIP"
}

variable "cluster_name" {
  description = "EKS cluster name for kubeconfig"
  type        = string
}

variable "region" {
  description = "AWS region"
  type        = string
}

variable "create_root_application" {
  description = "Create an Argo CD Application that points at your control-plane Git repo (set true once the repo exists)"
  type        = bool
  default     = false
}

variable "root_automated_sync" {
  description = "Automatically sync the root application; leave false during staged layer validation"
  type        = bool
  default     = false
}

variable "root_application_name" {
  description = "Name of the Argo CD Application resource for the GitOps root"
  type        = string
  default     = "control-plane-root"
}

variable "control_plane_repo_url" {
  description = "Git repository URL for the control-plane Helm chart / manifests"
  type        = string
  default     = ""
}

variable "control_plane_target_revision" {
  description = "Git revision (branch, tag, or commit) for the control-plane repo"
  type        = string
  default     = "main"
}

variable "control_plane_chart_path" {
  description = "Path within the Git repo to the Helm chart (for example charts/root-app)"
  type        = string
  default     = "charts/root-app"
}

variable "root_destination_namespace" {
  description = "Namespace to deploy the root Helm release into (often argocd for bootstrap charts)"
  type        = string
  default     = "argocd"
}

variable "ingress_enabled" {
  description = "Enable ALB Ingress for ArgoCD"
  type        = bool
  default     = false
}

variable "ingress_scheme" {
  description = "ALB scheme (internet-facing or internal)"
  type        = string
  default     = "internet-facing"
}

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

variable "crossplane_namespace" {
  description = "Namespace where Crossplane is installed"
  type        = string
  default     = "crossplane-system"
}

variable "crossplane_provider_config_name" {
  description = "Name of the Crossplane ProviderConfig"
  type        = string
  default     = "default"
}

variable "eso_service_account_name" {
  description = "Service account name for External Secrets Operator"
  type        = string
  default     = "external-secrets"
}

variable "eso_workload_role_arn" {
  description = "ARN of the workload IAM role that ESO will assume"
  type        = string
}

variable "cluster_endpoint" {
  description = "Cluster endpoint; changes replay Kubernetes bootstrap hooks after cluster replacement"
  type        = string
}
