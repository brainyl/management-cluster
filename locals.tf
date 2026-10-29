# Local values for consistent tagging and labeling across resources

locals {
  # Standard AWS tags applied to all resources
  standard_tags = {
    # Core identification
    Environment = var.environment
    ManagedBy   = "Terraform"
    Cluster     = var.cluster_name
    Region      = var.aws_region

    # Organizational
    Project    = var.project_name
    Owner      = var.owner
    CostCenter = var.cost_center

    # Operational
    Tier               = "management" # management, infra-plane, or client
    GitRepo            = var.git_repo_url
    TerraformWorkspace = terraform.workspace
  }

  # Merge standard tags with user-provided custom tags
  # User tags take precedence if there's a conflict
  common_tags = merge(
    local.standard_tags,
    var.additional_tags
  )

  # Standard Kubernetes labels for all K8s resources
  standard_k8s_labels = {
    "app.kubernetes.io/managed-by"     = "terraform"
    "app.kubernetes.io/part-of"        = "crossplane-control-plane"
    "platform.company.com/cluster"     = var.cluster_name
    "platform.company.com/environment" = var.environment
    "platform.company.com/tier"        = "management"
  }

  # Merge standard K8s labels with user-provided custom labels
  common_k8s_labels = merge(
    local.standard_k8s_labels,
    var.additional_k8s_labels
  )

  # EKS-specific tags (for cluster and node groups)
  eks_tags = merge(
    local.common_tags,
    {
      "kubernetes.io/cluster/${var.cluster_name}" = "owned"
    }
  )

  # VPC tags for AWS Load Balancer Controller
  vpc_tags = merge(
    local.common_tags,
    {
      Name                                        = "${var.cluster_name}-vpc"
      "kubernetes.io/cluster/${var.cluster_name}" = "shared"
    }
  )

  # Subnet tags for EKS and Load Balancer Controller
  public_subnet_tags = merge(
    local.common_tags,
    {
      "kubernetes.io/role/elb"                    = "1"
      "kubernetes.io/cluster/${var.cluster_name}" = "shared"
      Tier                                        = "public"
    }
  )

  private_subnet_tags = merge(
    local.common_tags,
    {
      "kubernetes.io/role/internal-elb"           = "1"
      "kubernetes.io/cluster/${var.cluster_name}" = "shared"
      Tier                                        = "private"
    }
  )
}