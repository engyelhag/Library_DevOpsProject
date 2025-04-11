output "filesystem_id" {
  description = "The ID of the created EFS filesystem."
  value       = aws_efs_file_system.main.id
}

output "filesystem_arn" {
  description = "The ARN of the EFS filesystem."
  value       = aws_efs_file_system.main.arn
}

output "dns_name" {
  description = "The DNS name for the EFS filesystem (e.g., fs-12345678.efs.us-east-1.amazonaws.com)."
  value       = aws_efs_file_system.main.dns_name
}

output "mount_target_security_group_id" {
  description = "The ID of the security group attached to the EFS mount targets."
  value       = aws_security_group.efs_mount_target.id
}

output "mount_target_ids" {
  description = "Map of subnet IDs to EFS mount target IDs created."
  # value = values(aws_efs_mount_target.main)[*].id # Gets just the list of IDs
  value = { for k, v in aws_efs_mount_target.main : k => v.id } # Maps subnet_id => mount_target_id
}

output "mount_target_dns_names" {
  description = "Map of Availability Zone Names to Mount Target DNS Names"
  # Ref: https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/efs_mount_target#availability_zone_name
  value = { for mt in aws_efs_mount_target.main : mt.availability_zone_name => mt.mount_target_dns_name }

}