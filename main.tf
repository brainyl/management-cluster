# Root management cluster
# scripts/bootstrap.sh applies foundation, controllers, then GitOps in dependency order.

terraform {
  required_version = "~> 1.5"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.28"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 2.35"
    }
    helm = {
      source  = "hashicorp/helm"
      version = "~> 2.17"
    }
    time = {
      source  = "hashicorp/time"
      version = "~> 0.12"
    }
  }
}

provider "aws" {
  region = var.aws_region

  default_tags {
    tags = {
      Environment = var.environment
      ManagedBy   = "Terraform"
      Cluster     = var.cluster_name
    }
  }
}

# Kubernetes and Helm providers configured after EKS cluster creation
provider "kubernetes" {
  host                   = module.eks.cluster_endpoint
  cluster_ca_certificate = base64decode(module.eks.cluster_certificate_authority_data)

  exec {
    api_version = "client.authentication.k8s.io/v1beta1"
    command     = "aws"
    args = [
      "eks",
      "get-token",
      "--cluster-name",
      module.eks.cluster_name,
      "--region",
      var.aws_region
    ]
  }
}

provider "helm" {
  kubernetes {
    host                   = module.eks.cluster_endpoint
    cluster_ca_certificate = base64decode(module.eks.cluster_certificate_authority_data)

    exec {
      api_version = "client.authentication.k8s.io/v1beta1"
      command     = "aws"
      args = [
        "eks",
        "get-token",
        "--cluster-name",
        module.eks.cluster_name,
        "--region",
        var.aws_region
      ]
    }
  }
}

# VPC Module
module "vpc" {
  source = "./modules/vpc"

  name               = "${var.cluster_name}-vpc"
  cidr               = var.vpc_cidr
  azs                = var.availability_zones
  private_subnets    = var.private_subnet_cidrs
  public_subnets     = var.public_subnet_cidrs
  enable_nat_gateway = var.enable_nat_gateway
  single_nat_gateway = var.single_nat_gateway
}

# EKS Module
module "eks" {
  source = "./modules/eks"

  cluster_name        = var.cluster_name
  kubernetes_version  = var.cluster_version
  vpc_id              = module.vpc.vpc_id
  private_subnet_ids  = module.vpc.private_subnets
  authentication_mode = "API"
}

# Crossplane Pod Identity
module "crossplane_pod_identity" {
  source = "./modules/crossplane-pod-identity"

  name_prefix                         = var.cluster_name
  cluster_name                        = module.eks.cluster_name
  crossplane_namespace                = var.crossplane_namespace
  crossplane_service_account_name     = var.crossplane_service_account_name
  crossplane_member_account_ids       = var.crossplane_member_account_ids
  crossplane_member_account_role_name = var.crossplane_member_account_role_name
}

# External Secrets Operator Pod Identity
module "eso_pod_identity" {
  source = "./modules/eso-pod-identity"

  depends_on = [module.eks]

  name_prefix              = var.cluster_name
  cluster_name             = module.eks.cluster_name
  eso_namespace            = "external-secrets-system"
  eso_service_account_name = var.eso_service_account_name
}

# ArgoCD Pod Identity
module "argocd_pod_identity" {
  source = "./modules/argocd-pod-identity"

  depends_on = [module.eks]

  name_prefix      = var.cluster_name
  cluster_name     = module.eks.cluster_name
  argocd_namespace = "argocd"
}

# External Secrets Operator
module "external_secrets" {
  source = "./modules/external-secrets"

  depends_on = [
    module.eks,
    module.eso_pod_identity
  ]

  chart_version            = var.eso_chart_version
  service_account_name     = var.eso_service_account_name
  cluster_ready_dependency = module.eks.cluster_name
}

# ArgoCD Module
module "argocd" {
  source = "./modules/argocd"

  depends_on = [
    module.eks,
    module.crossplane,
    module.external_secrets,
    module.argocd_pod_identity
  ]

  cluster_name        = var.cluster_name
  region              = var.aws_region
  cluster_endpoint    = module.eks.cluster_endpoint
  chart_version       = var.argocd_chart_version
  server_service_type = var.argocd_server_service_type
  ingress_enabled     = var.argocd_ingress_enabled
  ingress_scheme      = var.argocd_ingress_scheme

  create_root_application       = var.create_root_application
  root_automated_sync           = var.root_automated_sync
  root_application_name         = var.root_application_name
  control_plane_repo_url        = var.control_plane_repo_url
  control_plane_target_revision = var.control_plane_target_revision
  control_plane_chart_path      = var.control_plane_chart_path
  root_destination_namespace    = var.root_destination_namespace

  # GitHub repository secrets
  github_token                    = var.github_token
  github_repos                    = var.github_repos
  crossplane_namespace            = var.crossplane_namespace
  crossplane_provider_config_name = var.provider_config_name
  eso_service_account_name        = var.eso_service_account_name
  eso_workload_role_arn           = module.eso_pod_identity.workload_role_arn
}

# Crossplane Module
module "crossplane" {
  source = "./modules/crossplane"

  depends_on = [
    module.eks,
    module.crossplane_pod_identity
  ]

  cluster_endpoint                             = module.eks.cluster_endpoint
  schema_revision                              = var.crossplane_schema_revision
  chart_version                                = var.crossplane_chart_version
  enable_composition_webhook_schema_validation = var.enable_composition_webhook_schema_validation

  install_aws_providers = var.install_aws_providers
  aws_provider_version  = var.aws_provider_version

  create_provider_config          = var.create_provider_config
  provider_config_name            = var.provider_config_name
  crossplane_service_account_name = var.crossplane_service_account_name

  cluster_ready_dependency = module.eks.cluster_name
}
