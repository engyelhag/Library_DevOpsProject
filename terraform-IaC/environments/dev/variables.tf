# --- General Environment Configuration ---

variable "aws_region" {
  description = "AWS region for the dev environment."
  type        = string
  default     = "eu-west-1" # Matches provider and backend config
}

variable "project_name" {
  description = "The name of the project."
  type        = string
  default     = "cls-project"
}

variable "environment" {
  description = "The deployment environment name."
  type        = string
  default     = "dev"
}

variable "common_tags" {
  description = "Common tags to apply to all resources in the dev environment via modules."
  type        = map(string)
  default = {
    Environment = "dev"
    Project     = "cls-project" # Should match var.project_name
    ManagedBy   = "Terraform"
    Owner       = "DevTeam-Mourad" # Example specific tag
  }
}

# --- VPC Configuration for Dev ---
# These values will be passed to the VPC module

variable "vpc_cidr_block" {
  description = "The CIDR block for the VPC in the dev environment."
  type        = string
  default     = "10.10.0.0/16" # Specific CIDR for dev
}

variable "availability_zones" {
  description = "Availability zones to use in the dev environment (eu-west-1)."
  type        = list(string)
  # Using 3 AZs is standard practice for high availability in eu-west-1
  default     = ["eu-west-1a", "eu-west-1b", "eu-west-1c"]
}

variable "public_subnet_cidr_blocks" {
  description = "CIDR blocks for public subnets in the dev environment. Count must match AZs."
  type        = list(string)
  # Ensure these CIDRs are within the main vpc_cidr_block
  default     = ["10.10.1.0/24", "10.10.2.0/24", "10.10.3.0/24"]
}

variable "private_subnet_cidr_blocks" {
  description = "CIDR blocks for private subnets in the dev environment. Count must match AZs."
  type        = list(string)
  # Ensure these CIDRs are within the main vpc_cidr_block and don't overlap public
  default     = ["10.10.101.0/24", "10.10.102.0/24", "10.10.103.0/24"]
}

variable "enable_nat_gateway" {
  description = "Enable NAT Gateway creation for the dev VPC? (Set to false for pure private env)."
  type        = bool
  default     = true
}

variable "single_nat_gateway" {
  description = "Use a single NAT Gateway (cost saving) or one per AZ (HA) in dev."
  type        = bool
  default     = true # Often preferred for dev to save costs
}

# --- EKS Configuration Placeholder Variables ---
# Anticipating inputs needed for the EKS and Node Group modules

variable "eks_cluster_name" {
  description = "Name for the EKS cluster in dev."
  type        = string
  default     = "cls-eks-cluster"
}

variable "eks_cluster_version" {
  description = "Kubernetes version for the EKS cluster (Check AWS for latest supported)."
  type        = string
  default     = "1.32"
}

variable "node_group_instance_types" {
  description = "List of EC2 instance types for the EKS worker nodes in dev."
  type        = list(string)
  default     = ["t3.medium"] # Cost-effective general purpose for dev
}

variable "node_group_desired_size" {
  description = "Desired number of worker nodes in the node group."
  type        = number
  default     = 2
}

variable "node_group_min_size" {
  description = "Minimum number of worker nodes for scaling."
  type        = number
  default     = 1
}

variable "node_group_max_size" {
  description = "Maximum number of worker nodes for scaling."
  type        = number
  default     = 3
}

# --- Add other environment-specific variables as needed ---