resource "helm_release" "argocd" {
  name             = "argocd"
  repository       = "https://argoproj.github.io/argo-helm"
  chart            = "argo-cd"
  version          = var.chart_version
  namespace        = var.namespace
  create_namespace = true

  skip_crds = false

  values = [templatefile("${path.module}/values.yaml.tpl", {
    server_service_type = var.server_service_type
  })]
}

resource "null_resource" "ingress_class_params" {
  count = var.ingress_enabled ? 1 : 0

  triggers = {
    cluster_endpoint = var.cluster_endpoint
    manifest = templatefile("${path.module}/templates/ingress-class-params.yaml.tpl", {
      scheme = var.ingress_scheme
    })
  }

  provisioner "local-exec" {
    command = <<-EOT
      aws eks update-kubeconfig --name ${var.cluster_name} --region ${var.region}
      kubectl config use-context arn:aws:eks:${var.region}:$(aws sts get-caller-identity --query Account --output text):cluster/${var.cluster_name}
      echo '${self.triggers.manifest}' | kubectl apply --validate=false -f -
    EOT
  }

  provisioner "local-exec" {
    when    = destroy
    command = "echo '${self.triggers.manifest}' | kubectl delete -f - || true"
  }

  depends_on = [helm_release.argocd]
}

resource "null_resource" "ingress_class" {
  count = var.ingress_enabled ? 1 : 0

  triggers = {
    cluster_endpoint = var.cluster_endpoint
    manifest         = file("${path.module}/templates/ingress-class.yaml.tpl")
  }

  provisioner "local-exec" {
    command = <<-EOT
      kubectl config use-context arn:aws:eks:${var.region}:$(aws sts get-caller-identity --query Account --output text):cluster/${var.cluster_name}
      echo '${self.triggers.manifest}' | kubectl apply --validate=false -f -
    EOT
  }

  provisioner "local-exec" {
    when    = destroy
    command = "echo '${self.triggers.manifest}' | kubectl delete -f - || true"
  }

  depends_on = [null_resource.ingress_class_params]
}

resource "null_resource" "argocd_ingress" {
  count = var.ingress_enabled ? 1 : 0

  triggers = {
    cluster_endpoint = var.cluster_endpoint
    manifest = templatefile("${path.module}/templates/ingress.yaml.tpl", {
      namespace = var.namespace
    })
  }

  provisioner "local-exec" {
    command = <<-EOT
      kubectl config use-context arn:aws:eks:${var.region}:$(aws sts get-caller-identity --query Account --output text):cluster/${var.cluster_name}
      echo '${self.triggers.manifest}' | kubectl apply --validate=false -f -
    EOT
  }

  provisioner "local-exec" {
    when    = destroy
    command = "echo '${self.triggers.manifest}' | kubectl delete -f - || true"
  }

  depends_on = [null_resource.ingress_class]
}

resource "kubernetes_manifest" "root_application" {
  count = var.create_root_application ? 1 : 0

  depends_on = [helm_release.argocd]

  manifest = yamldecode(templatefile("${path.module}/templates/root-application.yaml.tpl", {
    app_name              = var.root_application_name
    namespace             = var.namespace
    repo_url              = var.control_plane_repo_url
    target_revision       = var.control_plane_target_revision
    chart_path            = var.control_plane_chart_path
    destination_namespace = var.root_destination_namespace
    automated_sync        = var.root_automated_sync
  }))
}

# GitHub credentials secret (created once) - uses original template
resource "null_resource" "github_credentials_secret" {
  count = length(var.github_repos) > 0 ? 1 : 0

  triggers = {
    cluster_endpoint = var.cluster_endpoint
    manifest = templatefile("${path.module}/templates/github-credentials-secret.yaml.tpl", {
      github_token             = var.github_token
      repo_url                 = var.github_repos[0] # First repo for backward compatibility
      repo_secret_name         = "github-repo-${replace(replace(var.github_repos[0], "https://github.com/", ""), "/", "-")}"
      aws_region               = var.region
      argocd_namespace         = var.namespace
      crossplane_namespace     = var.crossplane_namespace
      provider_config_name     = var.crossplane_provider_config_name
      eso_service_account_name = var.eso_service_account_name
      eso_workload_role_arn    = var.eso_workload_role_arn
    })
  }

  provisioner "local-exec" {
    command = <<-EOT
      kubectl config use-context arn:aws:eks:${var.region}:$(aws sts get-caller-identity --query Account --output text):cluster/${var.cluster_name}
      echo '${self.triggers.manifest}' | kubectl apply -f -
    EOT
  }

  depends_on = [helm_release.argocd]
}

# ArgoCD repository ExternalSecrets, including the root control-plane repository.
resource "null_resource" "github_repo_secrets" {
  for_each = toset(var.github_repos)

  triggers = {
    cluster_endpoint = var.cluster_endpoint
    manifest = templatefile("${path.module}/templates/github-external-secret.yaml.tpl", {
      repo_url         = each.value
      repo_secret_name = "github-repo-${replace(replace(each.value, "https://github.com/", ""), "/", "-")}"
      argocd_namespace = var.namespace
    })
  }

  provisioner "local-exec" {
    command = <<-EOT
      kubectl config use-context arn:aws:eks:${var.region}:$(aws sts get-caller-identity --query Account --output text):cluster/${var.cluster_name}
      echo '${self.triggers.manifest}' | kubectl apply -f -
    EOT
  }

  depends_on = [
    helm_release.argocd,
    null_resource.github_credentials_secret
  ]
}
