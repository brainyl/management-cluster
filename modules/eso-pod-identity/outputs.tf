output "role_arn" {
  description = "ARN of the IAM role for External Secrets Operator"
  value       = aws_iam_role.eso.arn
}

output "workload_role_arn" {
  description = "ARN of the workload IAM role that ESO will assume"
  value       = aws_iam_role.eso_workload.arn
}

output "role_name" {
  description = "Name of the IAM role"
  value       = aws_iam_role.eso.name
}
