variable "name_prefix" {
  description = "Short name prefix for IAM resources"
  type        = string
}

variable "cluster_name" {
  description = "EKS cluster name (must exist before associations are applied)"
  type        = string
}

variable "crossplane_namespace" {
  description = "Kubernetes namespace where Crossplane is installed"
  type        = string
  default     = "crossplane-system"
}

variable "crossplane_service_account_name" {
  description = "Service account name used by all Crossplane providers (configured via DeploymentRuntimeConfig)"
  type        = string
  default     = "crossplane-provider-aws"
}

variable "crossplane_member_account_ids" {
  description = "12-digit AWS account IDs where Crossplane will assume a role of a fixed name"
  type        = list(string)
  default     = []

  validation {
    condition = alltrue([
      for id in var.crossplane_member_account_ids : can(regex("^[0-9]{12}$", id))
    ])
    error_message = "Each member account ID must be exactly 12 digits."
  }
}

variable "crossplane_member_account_role_name" {
  description = "IAM role name (not ARN) that exists in each member account and trusts the management account"
  type        = string
  default     = "crossplane-provider-aws"
}

variable "tags" {
  description = "Tags to apply to IAM resources"
  type        = map(string)
  default     = {}
}
