variable "project_name" {
  description = "The name of the project. Used for naming resources."
  type        = string
}

variable "environment" {
  description = "The deployment environment."
  type        = string
}

variable "tags" {
  description = "A map of common tags to apply."
  type        = map(string)
  default     = {}
}

variable "node_group_name" {
  description = "A unique name for the EKS Node Group."
  type        = string
}

variable "cluster_name" {
  description = "The name of the EKS cluster this node group belongs to."
  type        = string
}

variable "cluster_version" {
  description = "The Kubernetes version of the EKS cluster (should match the cluster being joined)."
  type        = string
}

variable "node_subnet_ids" {
  description = "A list of subnet IDs (typically private) where worker nodes will be deployed."
  type        = list(string)
}

variable "instance_types" {
  description = "List of EC2 instance types for the worker nodes."
  type        = list(string)
  default     = ["t3.medium"]
}

variable "ami_type" {
  description = "Type of Amazon Machine Image (AMI) associated with the EKS Node Group. E.g., AL2_x86_64, AL2_ARM_64, BOTTLEROCKET_x86_64."
  type        = string
  default     = "AL2_x86_64" # Standard Amazon Linux 2
}

variable "disk_size" {
  description = "Disk size in GiB for worker node root volumes."
  type        = number
  default     = 20 # GiB
}

variable "desired_size" {
  description = "Desired number of worker nodes."
  type        = number
}

variable "min_size" {
  description = "Minimum number of worker nodes."
  type        = number
}

variable "max_size" {
  description = "Maximum number of worker nodes."
  type        = number
}

variable "max_unavailable_percentage" {
  description = "The maximum percentage of nodes unavailable during node group updates."
  type        = number
  default     = 33 # Allows about 1/3rd to be updated at a time
}

variable "capacity_type" {
  description = "Type of capacity for the nodes: ON_DEMAND or SPOT."
  type        = string
  default     = "ON_DEMAND"
  validation {
    condition     = contains(["ON_DEMAND", "SPOT"], var.capacity_type)
    error_message = "Valid values for capacity_type are ON_DEMAND or SPOT."
  }
}

variable "force_update_version" {
  description = "Force node group update when launching nodes with a new Kubernetes version."
  type        = bool
  default     = false
}

variable "kubernetes_labels" {
  description = "Map of Kubernetes labels to apply to the nodes."
  type        = map(string)
  default     = {}
}

variable "kubernetes_taints" {
  description = "List of Kubernetes taints to apply to the nodes. Each element is an object with keys: 'key', 'value', 'effect'."
  type = list(object({
    key    = string
    value  = string
    effect = string # NO_SCHEDULE, PREFER_NO_SCHEDULE, NO_EXECUTE
  }))
  default = []
  validation {
    # Basic check for required keys and valid effect
    condition = alltrue([
      for taint in var.kubernetes_taints :
      lookup(taint, "key", null) != null &&
      lookup(taint, "value", null) != null &&
      lookup(taint, "effect", null) != null &&
      contains(["NO_SCHEDULE", "PREFER_NO_SCHEDULE", "NO_EXECUTE"], taint.effect)
    ])
    error_message = "Each taint must have 'key', 'value', and 'effect' attributes. Effect must be NO_SCHEDULE, PREFER_NO_SCHEDULE, or NO_EXECUTE."
  }
}