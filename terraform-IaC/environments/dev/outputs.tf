# This file defines the outputs exposed by the dev environment configuration.
# Values will be populated by referencing outputs from the instantiated modules
# in environments/dev/main.tf once they are added.

output "dev_vpc_id" {
  description = "The ID of the VPC created for the dev environment."
  value       = module.vpc.vpc_id
}

output "dev_public_subnet_ids" {
  description = "List of public subnet IDs in the dev VPC."
  value       = module.vpc.public_subnet_ids
}

output "dev_private_subnet_ids" {
  description = "List of private subnet IDs in the dev VPC."
  value       = module.vpc.private_subnet_ids
}

output "dev_efs_filesystem_id" {
  description = "The ID of the EFS filesystem created for dev."
  value       = module.efs.filesystem_id
}

output "dev_eks_cluster_endpoint" {
  description = "The endpoint URL for the dev EKS cluster."
  value       = module.eks.cluster_endpoint
}

output "dev_eks_cluster_name" {
 description = "The name of the dev EKS cluster."
 value = module.eks.cluster_name # Assuming eks module outputs the name
}

output "dev_eks_cluster_oidc_provider_arn" {
  description = "The OIDC Provider ARN for the dev EKS cluster (for IRSA)."
  value       = module.eks.cluster_oidc_provider_arn
}

# output "dev_load_balancer_dns_name" {
#   description = "The DNS name of the dev application load balancer."
#   value       = module.load_balancer.lb_dns_name
# }

output "dev_kubeconfig_command" {
 description = "Command to update kubeconfig for the dev cluster."
 value       = "aws eks update-kubeconfig --region ${var.aws_region} --name ${module.eks.cluster_name}"
}