variable "cluster_name" {
  description = "EKS cluster name (must be unique in the account/region)"
  type        = string
}

variable "kubernetes_version" {
  description = "EKS control plane Kubernetes version"
  type        = string
}

variable "vpc_id" {
  description = "VPC ID where the cluster runs"
  type        = string
}

variable "private_subnet_ids" {
  description = "Private subnet IDs for the EKS control plane and workloads"
  type        = list(string)
}

variable "cluster_endpoint_public_access" {
  description = "Whether the Kubernetes API server endpoint is reachable from the internet"
  type        = bool
  default     = true
}

variable "cluster_endpoint_private_access" {
  description = "Whether the Kubernetes API server endpoint is reachable from inside the VPC"
  type        = bool
  default     = true
}

variable "node_pools" {
  description = "EKS Auto Mode built-in node pools (see AWS docs for valid names)"
  type        = list(string)
  default     = ["general-purpose", "system"]
}

variable "tags" {
  description = "Tags applied to the cluster and related AWS resources"
  type        = map(string)
  default     = {}
}

variable "authentication_mode" {
  description = "Authentication mode for the cluster. Valid values: CONFIG_MAP, API, API_AND_CONFIG_MAP"
  type        = string
  default     = "API"
}
