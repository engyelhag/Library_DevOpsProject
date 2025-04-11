variable "project_name" {
  description = "The name of the project (e.g., 'mywebapp'). Used for naming resources."
  type        = string
}

variable "environment" {
  description = "The deployment environment (e.g., 'dev', 'staging', 'prod')."
  type        = string
}

variable "aws_region" {
  description = "The AWS region to deploy resources in."
  type        = string
}

variable "vpc_cidr_block" {
  description = "The main CIDR block for the VPC."
  type        = string
  default     = "10.0.0.0/16"
}

variable "availability_zones" {
  description = "A list of Availability Zones to use for subnets."
  type        = list(string)
  # Example: ["us-east-1a", "us-east-1b", "us-east-1c"]
  # Let the dev environment provide this via data source or hardcoding
}

variable "public_subnet_cidr_blocks" {
  description = "List of CIDR blocks for public subnets. Must match the number of AZs."
  type        = list(string)
  # Example: ["10.0.1.0/24", "10.0.2.0/24", "10.0.3.0/24"]
}

variable "private_subnet_cidr_blocks" {
  description = "List of CIDR blocks for private subnets. Must match the number of AZs."
  type        = list(string)
  # Example: ["10.0.101.0/24", "10.0.102.0/24", "10.0.103.0/24"]
}

variable "enable_nat_gateway" {
  description = "Set to true to provision NAT Gateways for private subnets."
  type        = bool
  default     = true
}

variable "single_nat_gateway" {
  description = "Set to true to provision a single NAT Gateway. If false, provisions one NAT Gateway per AZ."
  type        = bool
  default     = false # Default to HA setup (one per AZ)
}

variable "tags" {
  description = "A map of common tags to apply to all resources."
  type        = map(string)
  default     = {}
}