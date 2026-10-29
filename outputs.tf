# VPC Outputs
output "vpc_id" {
  description = "ID of the VPC"
  value       = module.vpc.vpc_id
}

output "private_subnet_ids" {
  description = "IDs of private subnets"
  value       = module.vpc.private_subnets
}

output "public_subnet_ids" {
  description = "IDs of public subnets"
  value       = module.vpc.public_subnets
}

# EKS Outputs
output "cluster_name" {
  description = "Name of the EKS cluster"
  value       = module.eks.cluster_name
}

output "cluster_endpoint" {
  description = "Endpoint for EKS cluster"
  value       = module.eks.cluster_endpoint
}

output "cluster_version" {
  description = "Kubernetes version of the EKS cluster"
  value       = module.eks.cluster_version
}

output "oidc_provider_arn" {
  description = "ARN of the OIDC provider for the EKS cluster"
  value       = module.eks.oidc_provider_arn
}

# Crossplane Pod Identity Outputs
output "crossplane_role_arn" {
  description = "ARN of the IAM role for Crossplane providers"
  value       = module.crossplane_pod_identity.crossplane_aws_role_arn
}

output "crossplane_role_name" {
  description = "Name of the IAM role for Crossplane providers"
  value       = module.crossplane_pod_identity.crossplane_aws_role_name
}

# ArgoCD Pod Identity Outputs
output "argocd_role_arn" {
  description = "ARN of the IAM role for ArgoCD Pod Identity"
  value       = module.argocd_pod_identity.role_arn
}

output "argocd_role_name" {
  description = "Name of the IAM role for ArgoCD Pod Identity"
  value       = module.argocd_pod_identity.role_name
}

# ArgoCD Outputs
output "argocd_namespace" {
  description = "Namespace where ArgoCD is installed"
  value       = module.argocd.argocd_namespace
}

output "argocd_chart_version" {
  description = "Installed ArgoCD chart version"
  value       = module.argocd.argocd_chart_version
}

# Crossplane Outputs
output "crossplane_namespace" {
  description = "Namespace where Crossplane is installed"
  value       = module.crossplane.crossplane_namespace
}

output "crossplane_chart_version" {
  description = "Installed Crossplane chart version"
  value       = module.crossplane.crossplane_chart_version
}

output "provider_config_name" {
  description = "Name of the Crossplane ProviderConfig"
  value       = module.crossplane.provider_config_name
}

# Connection Instructions
output "configure_kubectl" {
  description = "Command to configure kubectl"
  value       = "aws eks update-kubeconfig --name ${module.eks.cluster_name} --region ${var.aws_region}"
}

output "get_argocd_password" {
  description = "Command to get ArgoCD admin password"
  value       = "kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath='{.data.password}' | base64 -d"
}

output "argocd_port_forward" {
  description = "Command to port-forward to ArgoCD UI"
  value       = "kubectl port-forward svc/argocd-server -n argocd 8080:80"
}
