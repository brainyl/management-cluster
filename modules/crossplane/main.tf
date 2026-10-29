resource "helm_release" "crossplane" {
  name             = "crossplane"
  repository       = "https://charts.crossplane.io/stable"
  chart            = "crossplane"
  version          = var.chart_version
  namespace        = var.namespace
  create_namespace = true

  values = [templatefile("${path.module}/values.yaml.tpl", { schema_revision = var.schema_revision })]

  depends_on = [var.cluster_ready_dependency]
}

# Install Crossplane AWS provider family
# Using null_resource with kubectl to avoid kubernetes_manifest validation issues during plan
# Updates re-apply Providers in place; never delete them in a replacement hook,
# because deleting a Provider can remove its CRDs and managed resource objects.
resource "null_resource" "deployment_runtime_config" {
  triggers = {
    cluster_endpoint = var.cluster_endpoint
    manifest = templatefile("${path.module}/templates/deployment-runtime-config.yaml.tpl", {
      runtime_config_name  = var.deployment_runtime_config_name
      service_account_name = var.crossplane_service_account_name
    })
  }

  provisioner "local-exec" {
    command = <<-EOT
      echo '${self.triggers.manifest}' | kubectl apply -f -
    EOT
  }

  provisioner "local-exec" {
    when    = destroy
    command = <<-EOT
      echo '${self.triggers.manifest}' | kubectl delete -f - || true
    EOT
  }

  depends_on = [helm_release.crossplane]
}

resource "null_resource" "provider_aws_ec2" {
  count = var.install_aws_providers ? 1 : 0

  triggers = {
    cluster_endpoint = var.cluster_endpoint
    manifest = templatefile("${path.module}/templates/provider-aws-ec2.yaml.tpl", {
      provider_version    = var.aws_provider_version
      runtime_config_name = var.deployment_runtime_config_name
    })
  }

  provisioner "local-exec" {
    command = <<-EOT
      echo '${self.triggers.manifest}' | kubectl apply -f -
    EOT
  }

  depends_on = [
    helm_release.crossplane,
    null_resource.deployment_runtime_config
  ]
}

resource "null_resource" "provider_aws_eks" {
  count = var.install_aws_providers ? 1 : 0

  triggers = {
    cluster_endpoint = var.cluster_endpoint
    manifest = templatefile("${path.module}/templates/provider-aws-eks.yaml.tpl", {
      provider_version    = var.aws_provider_version
      runtime_config_name = var.deployment_runtime_config_name
    })
  }

  provisioner "local-exec" {
    command = <<-EOT
      echo '${self.triggers.manifest}' | kubectl apply -f -
    EOT
  }

  depends_on = [
    helm_release.crossplane,
    null_resource.deployment_runtime_config
  ]
}

resource "null_resource" "provider_aws_iam" {
  count = var.install_aws_providers ? 1 : 0

  triggers = {
    cluster_endpoint = var.cluster_endpoint
    manifest = templatefile("${path.module}/templates/provider-aws-iam.yaml.tpl", {
      provider_version    = var.aws_provider_version
      runtime_config_name = var.deployment_runtime_config_name
    })
  }

  provisioner "local-exec" {
    command = <<-EOT
      echo '${self.triggers.manifest}' | kubectl apply -f -
    EOT
  }

  depends_on = [
    helm_release.crossplane,
    null_resource.deployment_runtime_config
  ]
}

resource "null_resource" "provider_aws_secretsmanager" {
  count = var.install_aws_providers ? 1 : 0

  triggers = {
    cluster_endpoint = var.cluster_endpoint
    manifest = templatefile("${path.module}/templates/provider-aws-secretsmanager.yaml.tpl", {
      provider_version    = var.aws_provider_version
      runtime_config_name = var.deployment_runtime_config_name
    })
  }

  provisioner "local-exec" {
    command = <<-EOT
      echo '${self.triggers.manifest}' | kubectl apply -f -
    EOT
  }

  depends_on = [
    helm_release.crossplane,
    null_resource.deployment_runtime_config
  ]
}

# Wait for providers to become healthy
resource "time_sleep" "wait_for_providers" {
  count = var.install_aws_providers ? 1 : 0

  depends_on = [
    null_resource.provider_aws_ec2,
    null_resource.provider_aws_eks,
    null_resource.provider_aws_iam,
    null_resource.provider_aws_secretsmanager
  ]

  triggers = {
    cluster_endpoint = var.cluster_endpoint
  }

  create_duration = "60s"
}

# Create ProviderConfig using Pod Identity
resource "null_resource" "provider_config" {
  count = var.create_provider_config ? 1 : 0

  triggers = {
    cluster_endpoint = var.cluster_endpoint
    manifest = templatefile("${path.module}/templates/provider-config.yaml.tpl", {
      provider_config_name = var.provider_config_name
      service_account_name = var.crossplane_service_account_name
    })
  }

  provisioner "local-exec" {
    command = <<-EOT
      echo '${self.triggers.manifest}' | kubectl apply -f -
    EOT
  }

  depends_on = [time_sleep.wait_for_providers]
}
