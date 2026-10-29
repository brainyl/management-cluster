output "crossplane_namespace" {
  description = "Namespace where Crossplane is installed"
  value       = helm_release.crossplane.namespace
}

output "crossplane_chart_version" {
  description = "Installed Crossplane chart version"
  value       = helm_release.crossplane.version
}

output "provider_config_name" {
  description = "Name of the created ProviderConfig"
  value       = var.create_provider_config ? var.provider_config_name : null
}
