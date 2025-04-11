variable "project_name" {
  description = "The name of the project (e.g., 'mywebapp'). Used for naming resources."
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

variable "vpc_id" {
  description = "The ID of the VPC where the EFS filesystem and mount targets will be created."
  type        = string
}

variable "vpc_cidr_block" {
  description = "The primary CIDR block of the VPC. Used for the default security group rule."
  type        = string
}

variable "private_subnet_ids" {
  description = "A list of private subnet IDs where EFS mount targets should be created (one per AZ recommended)."
  type        = list(string)
}

variable "efs_performance_mode" {
  description = "The performance mode of the EFS file system. Valid values are generalPurpose or maxIO."
  type        = string
  default     = "generalPurpose"
  validation {
    condition     = contains(["generalPurpose", "maxIO"], var.efs_performance_mode)
    error_message = "Valid values for efs_performance_mode are generalPurpose or maxIO."
  }
}

variable "efs_throughput_mode" {
  description = "The throughput mode for the EFS file system. Valid values are bursting, provisioned, or elastic."
  type        = string
  default     = "bursting" # Elastic is newer, Bursting is common default
  validation {
    condition     = contains(["bursting", "provisioned", "elastic"], var.efs_throughput_mode)
    error_message = "Valid values for efs_throughput_mode are bursting, provisioned, or elastic."
  }
}

variable "efs_provisioned_throughput_in_mibps" {
  description = "The throughput, in MiB/s, that you want to provision for a file system that uses the 'provisioned' throughput mode."
  type        = number
  default     = null # Only required if throughput_mode is 'provisioned'
}

variable "enable_backup_policy" {
  description = "Set to true to enable the default AWS Backup policy for EFS."
  type        = bool
  default     = true # Recommended to keep backups enabled
}

variable "enable_lifecycle_policy" {
  description = "Set to true to enable a lifecycle policy."
  type        = bool
  default     = false # Default to disabled for simplicity
}

variable "lifecycle_transition_to_ia" {
  description = "Specifies the number of days since the last access before transitioning files to Infrequent Access (IA). Use values like AFTER_7_DAYS, AFTER_14_DAYS, etc."
  type        = string
  default     = "AFTER_30_DAYS" # Example, only used if enable_lifecycle_policy is true
  validation {
    condition     = var.enable_lifecycle_policy ? can(regex("^AFTER_(7|14|30|60|90)_DAYS$", var.lifecycle_transition_to_ia)) : true
    error_message = "Valid format is AFTER_X_DAYS where X is 7, 14, 30, 60, or 90."
  }
}

variable "allowed_security_groups" {
  description = "Optional list of security group IDs that are allowed to connect to EFS (NFS port). If empty, defaults to allowing traffic from the VPC CIDR block."
  type        = list(string)
  default     = []
}