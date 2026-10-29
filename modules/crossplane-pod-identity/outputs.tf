output "crossplane_aws_role_arn" {
  description = "Management-account IAM role assumed by the Crossplane provider via Pod Identity"
  value       = aws_iam_role.crossplane_aws.arn
}

output "crossplane_aws_role_name" {
  description = "IAM role name"
  value       = aws_iam_role.crossplane_aws.name
}

output "crossplane_assumable_role_arns" {
  description = "Resolved ARNs Crossplane may assume (same name in each member account)"
  value       = local.assumable_role_arns
}

output "pod_identity_association_ids" {
  description = "EKS Pod Identity association IDs"
  value       = [aws_eks_pod_identity_association.crossplane.association_id]
}
