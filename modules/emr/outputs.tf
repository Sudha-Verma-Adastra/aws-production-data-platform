
output "cluster_id" {
  description = "EMR cluster ID when enabled"
  value       = var.enabled ? aws_emr_cluster.spark[0].id : null
}

output "cluster_name" {
  description = "EMR cluster name when enabled"
  value       = var.enabled ? aws_emr_cluster.spark[0].name : null
}

output "emr_ec2_role_arn" {
  description = "EMR EC2 instance role ARN when enabled"
  value       = var.enabled ? aws_iam_role.emr_ec2[0].arn : null
}
