variable "namespace" {
  description = "Kubernetes namespace for Crossplane"
  type        = string
  default     = "crossplane-system"
}

variable "chart_version" {
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

variable "crossplane_service_account_name" {
  description = "ServiceAccount name used by Crossplane providers (must match Pod Identity association)"
  type        = string
  default     = "crossplane-provider-aws"
}

variable "cluster_ready_dependency" {
  description = "Dependency to ensure cluster is ready before installing Crossplane"
  type        = any
  default     = null
}


variable "deployment_runtime_config_name" {
  description = "Name of the DeploymentRuntimeConfig resource"
  type        = string
  default     = "default"
}

variable "cluster_endpoint" {
  description = "Cluster endpoint; changes replay Kubernetes bootstrap hooks after cluster replacement"
  type        = string
}

variable "schema_revision" {
  description = "Revision marker to refresh Crossplane after installed XRD schemas expand"
  type        = string
  default     = "initial"
}
