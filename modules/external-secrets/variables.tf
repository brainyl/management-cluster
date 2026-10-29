variable "chart_version" {
  description = "External Secrets Operator Helm chart version"
  type        = string
  default     = "2.3.0"
}

variable "namespace" {
  description = "Namespace for External Secrets Operator"
  type        = string
  default     = "external-secrets-system"
}

variable "service_account_name" {
  description = "Service account name for External Secrets Operator"
  type        = string
  default     = "external-secrets"
}

variable "cluster_ready_dependency" {
  description = "Dependency to ensure cluster is ready"
  type        = any
  default     = null
}
