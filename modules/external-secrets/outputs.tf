output "namespace" {
  description = "Namespace where External Secrets Operator is installed"
  value       = var.namespace
}

output "service_account_name" {
  description = "Service account name for External Secrets Operator"
  value       = var.service_account_name
}

output "release_name" {
  description = "Helm release name"
  value       = helm_release.external_secrets.name
}
