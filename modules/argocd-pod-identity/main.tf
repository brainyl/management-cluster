# EKS Pod Identity for ArgoCD: binds the ArgoCD ServiceAccount to an IAM role
# This allows ArgoCD to authenticate to remote EKS clusters via EKS Access Entries
# Docs: https://docs.aws.amazon.com/eks/latest/userguide/pod-identities.html

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

  statement {
    sid    = "AllowSelfAssumeRole"
    effect = "Allow"
    actions = [
      "sts:AssumeRole",
      "sts:TagSession",
    ]
    principals {
      type        = "AWS"
      identifiers = ["*"]
    }
    condition {
      test     = "ArnLike"
      variable = "aws:PrincipalArn"
      values   = ["arn:aws:iam::${data.aws_caller_identity.current.account_id}:role/${var.name_prefix}-argocd"]
    }
  }
}

resource "aws_iam_role" "argocd" {
  name               = "${var.name_prefix}-argocd"
  assume_role_policy = data.aws_iam_policy_document.pod_identity_trust.json
  tags               = var.tags
}

# IAM Policy for EKS cluster access and Access Entry management
# ArgoCD needs to authenticate to EKS clusters and manage Access Entries
data "aws_iam_policy_document" "eks_access" {
  statement {
    sid    = "EKSDescribeCluster"
    effect = "Allow"
    actions = [
      "eks:DescribeCluster",
      "eks:ListClusters",
    ]
    resources = ["*"]
  }
  
  statement {
    sid    = "EKSAccessEntryManagement"
    effect = "Allow"
    actions = [
      "eks:CreateAccessEntry",
      "eks:DeleteAccessEntry",
      "eks:DescribeAccessEntry",
      "eks:ListAccessEntries",
      "eks:UpdateAccessEntry",
      "eks:AssociateAccessPolicy",
      "eks:DisassociateAccessPolicy",
      "eks:ListAssociatedAccessPolicies"
    ]
    resources = ["*"]
  }

  statement {
    sid    = "AssumeRoleForClusterAccess"
    effect = "Allow"
    actions = [
      "sts:AssumeRole",
      "sts:TagSession"
    ]
    resources = [aws_iam_role.argocd.arn]
  }
}

resource "aws_iam_role_policy" "eks_access" {
  name   = "${var.name_prefix}-argocd-eks-access"
  role   = aws_iam_role.argocd.id
  policy = data.aws_iam_policy_document.eks_access.json
}

# Pod Identity association for ArgoCD application controller
resource "aws_eks_pod_identity_association" "argocd_application_controller" {
  cluster_name    = var.cluster_name
  namespace       = var.argocd_namespace
  service_account = "argocd-application-controller"
  role_arn        = aws_iam_role.argocd.arn
}

# Pod Identity association for ArgoCD server
resource "aws_eks_pod_identity_association" "argocd_server" {
  cluster_name    = var.cluster_name
  namespace       = var.argocd_namespace
  service_account = "argocd-server"
  role_arn        = aws_iam_role.argocd.arn
}
