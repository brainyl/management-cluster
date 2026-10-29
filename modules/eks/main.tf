# Community module: https://registry.terraform.io/modules/terraform-aws-modules/eks/aws/latest
# EKS Auto Mode: https://github.com/terraform-aws-modules/terraform-aws-eks/blob/master/examples/eks-auto-mode/main.tf

module "eks" {
  source  = "terraform-aws-modules/eks/aws"
  version = "21.17.1"

  name               = var.cluster_name
  kubernetes_version = var.kubernetes_version

  endpoint_public_access  = var.cluster_endpoint_public_access
  endpoint_private_access = var.cluster_endpoint_private_access

  # The EKS module resolves the Terraform caller to its persistent IAM identity.
  # This automatically preserves root operator access across SSO session renewal.
  enable_cluster_creator_admin_permissions = true
  authentication_mode                      = var.authentication_mode

  # EKS Auto Mode: AWS-managed node pools + add-ons (includes eks-pod-identity-agent by default)
  compute_config = {
    enabled    = true
    node_pools = var.node_pools
  }

  # Disable control plane logging
  enabled_log_types = []

  vpc_id     = var.vpc_id
  subnet_ids = var.private_subnet_ids

  tags = var.tags
}
