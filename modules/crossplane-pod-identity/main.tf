# EKS Pod Identity: binds the Crossplane ServiceAccount to a management-account IAM role.
# Uses DeploymentRuntimeConfig to configure all providers to use the same service account.
# Docs: https://docs.aws.amazon.com/eks/latest/userguide/pod-identities.html
#
# Requires the cluster add-on `eks-pod-identity-agent` (enabled in modules/eks by default).
# No IRSA annotation on the ServiceAccount—EKS injects credentials from this association.

data "aws_caller_identity" "current" {}

data "aws_iam_policy_document" "pod_identity_trust" {
  statement {
    sid    = "EksPodIdentity"
    effect = "Allow"
    actions = [
      "sts:AssumeRole",
      "sts:TagSession",
    ]
    principals {
      type        = "Service"
      identifiers = ["pods.eks.amazonaws.com"]
    }
    condition {
      test     = "StringEquals"
      variable = "aws:SourceAccount"
      values   = [data.aws_caller_identity.current.account_id]
    }
  }
}

resource "aws_iam_role" "crossplane_aws" {
  name               = "${var.name_prefix}-crossplane-aws"
  assume_role_policy = data.aws_iam_policy_document.pod_identity_trust.json
  tags               = var.tags
}

locals {
  assumable_role_arns = [
    for id in var.crossplane_member_account_ids :
    "arn:aws:iam::${id}:role/${var.crossplane_member_account_role_name}"
  ]
}

data "aws_iam_policy_document" "crossplane_assume" {
  count = length(local.assumable_role_arns) > 0 ? 1 : 0

  statement {
    sid    = "AssumeMemberAccountRoles"
    effect = "Allow"
    actions = [
      "sts:AssumeRole",
      "sts:TagSession",
    ]
    resources = local.assumable_role_arns
  }
}

resource "aws_iam_role_policy" "crossplane_assume" {
  count = length(local.assumable_role_arns) > 0 ? 1 : 0

  name   = "${var.name_prefix}-crossplane-assume"
  role   = aws_iam_role.crossplane_aws.id
  policy = data.aws_iam_policy_document.crossplane_assume[0].json
}

# Single Pod Identity association for the shared Crossplane service account
# All providers will use this service account via DeploymentRuntimeConfig
resource "aws_eks_pod_identity_association" "crossplane" {
  cluster_name    = var.cluster_name
  namespace       = var.crossplane_namespace
  service_account = var.crossplane_service_account_name
  role_arn        = aws_iam_role.crossplane_aws.arn
}

# IAM Policy for Secrets Manager access (for GitHub credentials)
data "aws_iam_policy_document" "secretsmanager" {
  statement {
    sid    = "SecretsManagerAccess"
    effect = "Allow"
    actions = [
      "secretsmanager:CreateSecret",
      "secretsmanager:DeleteSecret",
      "secretsmanager:DescribeSecret",
      "secretsmanager:GetSecretValue",
      "secretsmanager:PutSecretValue",
      "secretsmanager:TagResource",
      "secretsmanager:UntagResource",
      "secretsmanager:UpdateSecret",
      "secretsmanager:RestoreSecret",
      "secretsmanager:GetResourcePolicy",
      "secretsmanager:PutResourcePolicy",
      "secretsmanager:DeleteResourcePolicy",
      "secretsmanager:ListSecretVersionIds"
    ]
    resources = ["*"]
  }
}

resource "aws_iam_role_policy" "secretsmanager" {
  name   = "${var.name_prefix}-crossplane-secretsmanager"
  role   = aws_iam_role.crossplane_aws.id
  policy = data.aws_iam_policy_document.secretsmanager.json
}

# WARNING: AdministratorAccess is NOT best practice for production!
# This grants full AWS account access for Crossplane to provision infra-plane clusters.
# In production, you should:
# 1. Use granular policies with only required permissions
# 2. Use resource-level restrictions with tags
# 3. Use IAM permission boundaries
# 4. Implement least-privilege access
#
# This is for development/testing only.
resource "aws_iam_role_policy_attachment" "admin_access" {
  role       = aws_iam_role.crossplane_aws.name
  policy_arn = "arn:aws:iam::aws:policy/AdministratorAccess"
}
