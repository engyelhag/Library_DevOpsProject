variable "project_name" {
  description = "The name of the project. Used for naming resources."
  type        = string
}

variable "environment" {
  description = "The deployment environment (e.g., 'dev', 'staging', 'prod')."
  type        = string
}

variable "tags" {
  description = "A map of common tags to apply to all resources."
  type        = map(string)
  default     = {}
}

variable "cluster_name" {
  description = "The unique name for the EKS cluster."
  type        = string
}

variable "cluster_version" {
  description = "The desired Kubernetes version for the EKS cluster. Check AWS docs for supported versions."
  type        = string
}

variable "vpc_id" {
  description = "The ID of the VPC where the EKS cluster will be deployed."
  type        = string
}

variable "subnet_ids" {
  description = "A list of subnet IDs for the EKS cluster control plane ENIs. Should typically be private subnets across multiple AZs."
  type        = list(string)
}

variable "cluster_endpoint_private_access" {
  description = "Indicates whether or not the Amazon EKS private API server endpoint is enabled."
  type        = bool
  default     = true # Secure default
}

variable "cluster_endpoint_public_access" {
  description = "Indicates whether or not the Amazon EKS public API server endpoint is enabled."
  type        = bool
  default     = false # Secure default
}

variable "cluster_endpoint_public_access_cidrs" {
  description = "List of CIDR blocks. If public access is enabled, API server requests will only be allowed from these CIDRs."
  type        = list(string)
  default     = ["0.0.0.0/0"] # Default to allow all if public access is enabled (can be restricted)
}

variable "enabled_cluster_log_types" {
  description = "A list of the desired control plane logging to enable. Valid values: 'api', 'audit', 'authenticator', 'controllerManager', 'scheduler'."
  type        = list(string)
  default     = [] # Default to no logs enabled, ["api", "audit", "authenticator", "controllerManager", "scheduler"] to enable all
}

variable "cluster_encryption_config_enabled" {
  description = "Set to true to enable Kubernetes secrets encryption using a KMS key."
  type        = bool
  default     = false
}

variable "cluster_encryption_config_kms_key_arn" {
  description = "ARN of the KMS Key to use for cluster secrets encryption. Required if cluster_encryption_config_enabled is true."
  type        = string
  default     = null
}

variable "cluster_additional_security_group_ids" {
  description = "List of additional security group IDs to apply to the control plane ENIs."
  type        = list(string)
  default     = []
}

variable "enable_cluster_creator_admin_permissions" {
  description = "Automatically grant `system:masters` permissions in the cluster to the IAM identity that creates the cluster."
  type        = bool
  default     = true # Makes initial access easier
}