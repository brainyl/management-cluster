resource "helm_release" "external_secrets" {
  name             = "external-secrets"
  repository       = "https://charts.external-secrets.io"
  chart            = "external-secrets"
  version          = var.chart_version
  namespace        = var.namespace
  create_namespace = true

  values = [
    yamlencode({
      installCRDs = true
      resources = {
        requests = { cpu = "100m", memory = "128Mi" }
      }
      webhook = {
        resources = { requests = { cpu = "100m", memory = "128Mi" } }
      }
      certController = {
        resources = { requests = { cpu = "100m", memory = "128Mi" } }
      }
      serviceAccount = {
        create = true
        name   = var.service_account_name
      }
    })
  ]

  depends_on = [var.cluster_ready_dependency]
}
