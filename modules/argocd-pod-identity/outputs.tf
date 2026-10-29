output "role_arn" {
  description = "ARN of the IAM role for ArgoCD Pod Identity"
  value       = aws_iam_role.argocd.arn
}

output "role_name" {
  description = "Name of the IAM role for ArgoCD Pod Identity"
  value       = aws_iam_role.argocd.name
}

output "role_id" {
  description = "ID of the IAM role for ArgoCD Pod Identity"
  value       = aws_iam_role.argocd.id
}
