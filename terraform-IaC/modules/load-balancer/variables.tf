variable "project_name" {
  description = "The name of the project."
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

variable "vpc_id" {
  description = "The ID of the VPC where the Load Balancer will be deployed."
  type        = string
}

variable "public_subnet_ids" {
  description = "A list of public subnet IDs for the Load Balancer."
  type        = list(string)
}

variable "internal" {
  description = "Set to true to create an internal Load Balancer."
  type        = bool
  default     = false # Default to internet-facing
}

variable "load_balancer_type" {
  description = "The type of load balancer to create ('application' or 'network')."
  type        = string
  default     = "application"
  validation {
    condition     = contains(["application", "network"], var.load_balancer_type)
    error_message = "Load balancer type must be 'application' or 'network'."
  }
}

variable "enable_http_listener" {
  description = "Set to true to create an HTTP listener on port 80."
  type        = bool
  default     = true
}

variable "enable_https_listener" {
  description = "Set to true to create an HTTPS listener on port 443."
  type        = bool
  default     = false # Default to HTTP only for simplicity
}

variable "acm_certificate_arn" {
  description = "The ARN of the ACM certificate for the HTTPS listener. Required if enable_https_listener is true."
  type        = string
  default     = null
}

variable "create_default_target_group" {
  description = "Set to true to create a default target group for listeners."
  type        = bool
  default     = true
}

variable "default_target_group_port" {
  description = "Port for the default target group."
  type        = number
  default     = 80
}

variable "default_target_group_protocol" {
  description = "Protocol for the default target group (HTTP, HTTPS, TCP, etc.)."
  type        = string
  default     = "HTTP"
}

variable "default_target_group_type" {
  description = "Target type for the default target group ('instance', 'ip', 'lambda')."
  type        = string
  default     = "instance" # Common starting point, 'ip' better with AWS LB Controller
  validation {
    condition     = contains(["instance", "ip", "lambda"], var.default_target_group_type)
    error_message = "Default target group type must be 'instance', 'ip', or 'lambda'."
  }
}

variable "health_check_path" {
  description = "The destination for the health check request for the default target group."
  type        = string
  default     = "/"
}

variable "health_check_protocol" {
  description = "Protocol for the health check (HTTP, HTTPS, TCP, etc.)."
  type        = string
  default     = "HTTP"
}


variable "ingress_cidr_blocks" {
  description = "List of CIDR blocks allowed to access the Load Balancer listeners."
  type        = list(string)
  default     = ["0.0.0.0/0"] # Default to allow public access
}

# variable "egress_cidr_blocks" {
#   description = "List of CIDR blocks the Load Balancer is allowed to send traffic to."
#   type        = list(string)
#   default     = ["0.0.0.0/0"] # Allow outbound to anywhere by default
# }

variable "enable_access_logs" {
  description = "Set to true to enable Load Balancer access logging."
  type        = bool
  default     = false # Recommend enabling in production
}

variable "access_logs_s3_bucket_name" {
  description = "The name of the S3 bucket where access logs are stored. Required if enable_access_logs is true. Bucket must exist."
  type        = string
  default     = null
}

variable "access_logs_s3_prefix" {
  description = "Optional prefix for the access log object keys."
  type        = string
  default     = null
}

variable "enable_deletion_protection" {
  description = "If true, deletion of the load balancer will be disabled."
  type        = bool
  default     = false
}

variable "idle_timeout" {
  description = "The time in seconds that the connection is allowed to be idle."
  type        = number
  default     = 60
}