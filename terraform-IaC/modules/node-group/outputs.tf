output "node_group_id" {
  description = "The ID of the EKS Node Group."
  # Example: us-east-1:xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx
  value = aws_eks_node_group.main.id
}

output "node_group_arn" {
  description = "The ARN of the EKS Node Group."
  value = aws_eks_node_group.main.arn
}

output "node_group_name" {
  description = "The name of the EKS Node Group."
  value = aws_eks_node_group.main.node_group_name
}

output "node_group_status" {
  description = "Status of the EKS Node Group."
  value = aws_eks_node_group.main.status
}

output "node_group_resources" {
  description = "Resource information of the EKS Node Group."
  # Contains ASG names, instance profile, etc.
  value = aws_eks_node_group.main.resources
  sensitive = true # Contains potentially sensitive ARNs/names
}

output "node_iam_role_arn" {
  description = "The ARN of the IAM role created for the worker nodes."
  value = aws_iam_role.node.arn
}

output "node_iam_role_name" {
  description = "The Name of the IAM role created for the worker nodes."
  value = aws_iam_role.node.name
}