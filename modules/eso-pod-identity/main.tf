# IAM Role for External Secrets Operator Pod Identity (base role, no permissions)
resource "aws_iam_role" "eso" {
  name = "${var.name_prefix}-eso-pod-identity"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Service = "pods.eks.amazonaws.com"
        }
        Action = [
          "sts:AssumeRole",
          "sts:TagSession"
        ]
      }
    ]
  })
}

# Data sources
data "aws_caller_identity" "current" {}

data "aws_eks_cluster" "cluster" {
  name = var.cluster_name
}

# Workload role with actual Secrets Manager permissions
resource "aws_iam_role" "eso_workload" {
  name = "${var.name_prefix}-eso-workload"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          AWS = aws_iam_role.eso.arn
        }
        Action = [
          "sts:AssumeRole",
          "sts:TagSession"
        ]
      }
    ]
  })
}

# IAM Policy for Secrets Manager access
resource "aws_iam_role_policy" "eso_secretsmanager" {
  name = "secretsmanager-access"
  role = aws_iam_role.eso_workload.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "secretsmanager:GetSecretValue",
          "secretsmanager:GetResourcePolicy",
          "secretsmanager:DescribeSecret",
          "secretsmanager:ListSecretVersionIds"
        ]
        Resource = "*"
      },
      {
        Effect = "Allow"
        Action = [
          "secretsmanager:ListSecrets"
        ]
        Resource = "*"
      }
    ]
  })
}

# Pod Identity Association for ESO operator namespace
resource "aws_eks_pod_identity_association" "eso" {
  cluster_name    = var.cluster_name
  namespace       = var.eso_namespace
  service_account = var.eso_service_account_name
  role_arn        = aws_iam_role.eso.arn
}
