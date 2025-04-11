output "cluster_name" {
  description = "The name of the EKS cluster."
  value       = aws_eks_cluster.main.name
}

output "cluster_arn" {
  description = "The Amazon Resource Name (ARN) of the cluster."
  value       = aws_eks_cluster.main.arn
}

output "cluster_id" {
  description = "The name/id (same value) of the cluster."
  value       = aws_eks_cluster.main.id
}

output "cluster_endpoint" {
  description = "The endpoint for the Kubernetes API server."
  value       = aws_eks_cluster.main.endpoint
}

output "cluster_version" {
  description = "The Kubernetes version deployed in the cluster."
  value       = aws_eks_cluster.main.version
}

output "cluster_certificate_authority_data" {
  description = "Base64 encoded certificate data required to communicate with the cluster."
  value       = aws_eks_cluster.main.certificate_authority[0].data
  sensitive   = true # Treat CA data as sensitive
}

output "cluster_oidc_issuer_url" {
  description = "The URL of the OIDC identity provider."
  value       = aws_eks_cluster.main.identity[0].oidc[0].issuer
}

# Output the ARN of the OIDC provider, whether newly created or pre-existing
output "cluster_oidc_provider_arn" {
  description = "The ARN of the IAM OpenID Connect provider."
  value       = aws_iam_openid_connect_provider.oidc_provider.arn
}

output "cluster_security_group_id" {
  description = "The security group ID attached by EKS to the cluster control plane."
  # This is the primary SG created and managed by EKS.
  value = aws_eks_cluster.main.vpc_config[0].cluster_security_group_id
}

output "cluster_iam_role_arn" {
  description = "The ARN of the IAM role created for the EKS cluster."
  value       = aws_iam_role.cluster.arn
}