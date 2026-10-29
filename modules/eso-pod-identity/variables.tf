variable "name_prefix" {
  description = "Prefix for IAM role name"
  type        = string
}

variable "cluster_name" {
  description = "EKS cluster name"
  type        = string
}

variable "eso_namespace" {
  description = "Namespace where External Secrets Operator is installed"
  type        = string
  default     = "external-secrets-system"
}

variable "eso_service_account_name" {
  description = "Service account name for External Secrets Operator"
  type        = string
  default     = "external-secrets"
}
