# Provider configuration is sourced from environments/dev/providers.tf
# Variables are defined in environments/dev/variables.tf
# Backend configuration is in environments/dev/backend.tf

# --- VPC Module Instantiation ---
# This block creates the core networking infrastructure (VPC, Subnets, Gateways, Routing)
# for the 'dev' environment using the reusable VPC module.

module "vpc" {
  # The source points to the directory containing the VPC module's Terraform code.
  # The path is relative to this main.tf file.
  source = "../../modules/vpc"

  # --- Module Inputs ---
  # These values are passed from the environment-specific variables
  # defined in environments/dev/variables.tf into the VPC module's variables.

  project_name = var.project_name
  environment  = var.environment
  aws_region   = var.aws_region # Pass region, might be used by module internals or just for consistency

  vpc_cidr_block             = var.vpc_cidr_block
  availability_zones         = var.availability_zones
  public_subnet_cidr_blocks  = var.public_subnet_cidr_blocks
  private_subnet_cidr_blocks = var.private_subnet_cidr_blocks

  enable_nat_gateway         = var.enable_nat_gateway
  single_nat_gateway         = var.single_nat_gateway

  tags                       = var.common_tags # Pass the map of common tags
}

# --- EFS Module Instantiation ---
# Creates the Elastic File System (EFS) and required mount targets
# within the private subnets defined by the VPC module. It depends on the VPC outputs.

module "efs" {
  source = "../../modules/efs"

  # --- Module Inputs ---
  project_name = var.project_name
  environment  = var.environment
  tags         = var.common_tags

  # Inputs sourced directly from VPC module outputs:
  vpc_id             = module.vpc.vpc_id             # Use the VPC ID output from the VPC module
  private_subnet_ids = module.vpc.private_subnet_ids # Use the private subnet IDs output from the VPC module
  vpc_cidr_block     = module.vpc.vpc_cidr_block     # Use the VPC CIDR output for the default SG rule

  # Optional inputs (using module defaults for now):
  # We could define variables like var.dev_efs_performance_mode in variables.tf
  # and pass them here if we needed to override the module defaults for dev.
  # e.g., efs_performance_mode = var.dev_efs_performance_mode

  # The allowed_security_groups input defaults to [] in the module,
  # so the SG rule will allow traffic from the vpc_cidr_block by default.
  # We can update this later if we want to restrict it to the Node Group SG ID.
  # allowed_security_groups = [module.node_group.node_security_group_id] # Example for future integration

  # Implicit dependency: Terraform knows this module depends on 'module.vpc'
  # because we are referencing its outputs (vpc_id, private_subnet_ids, etc.).
}

# --- EKS Module Instantiation ---
# Creates the EKS Control Plane, its IAM Role, and OIDC Provider.
# Depends on the VPC module outputs for networking configuration.

module "eks" {
  source = "../../modules/eks"

  # --- Module Inputs ---
  project_name = var.project_name
  environment  = var.environment
  tags         = var.common_tags

  # EKS specific configuration from dev variables
  cluster_name    = var.eks_cluster_name
  cluster_version = var.eks_cluster_version

  # Inputs sourced from VPC module outputs:
  vpc_id     = module.vpc.vpc_id             # Cluster operates within this VPC
  subnet_ids = module.vpc.private_subnet_ids # Control plane ENIs placed in private subnets

  # Optional inputs demonstration (using module defaults for now):
  # To enable all control plane logs uncomment the following line:
  # enabled_cluster_log_types = ["api", "audit", "authenticator", "controllerManager", "scheduler"]

  # To enable public endpoint access restricted to a specific IP, uncomment below:
  # cluster_endpoint_public_access       = true
  # cluster_endpoint_public_access_cidrs = ["YOUR_IP_ADDRESS/32"] # Replace with actual IP CIDR

  # Relying on module defaults for:
  # - cluster_endpoint_private_access = true
  # - cluster_endpoint_public_access = false
  # - cluster_encryption_config_enabled = false
  # - enable_cluster_creator_admin_permissions = true

  # Implicit dependency: Terraform knows this module depends on 'module.vpc'.
}

# --- Node Group Module Instantiation ---
# Creates the EKS Managed Node Group (Worker Nodes) that will join the cluster.
# Depends on VPC outputs (subnets) and EKS outputs (cluster name).

module "primary_workers" {
  # Using a descriptive name for this instance of the node group module
  source = "../../modules/node-group"

  # --- Module Inputs ---
  project_name = var.project_name
  environment  = var.environment
  tags         = var.common_tags

  # Name for this specific node group within the cluster
  node_group_name = "primary-workers"

  # Inputs from EKS module output & dev variables:
  cluster_name    = module.eks.cluster_name # Link to the created cluster
  cluster_version = var.eks_cluster_version # Ensure nodes match cluster K8s version

  # Inputs from VPC module output:
  node_subnet_ids = module.vpc.private_subnet_ids # Deploy worker nodes in private subnets

  # Node configuration from dev variables:
  instance_types = var.node_group_instance_types
  desired_size   = var.node_group_desired_size
  min_size       = var.node_group_min_size
  max_size       = var.node_group_max_size

  # Optional inputs (using module defaults as defined in modules/node-group/variables.tf):
  # ami_type                     = "AL2_x86_64"
  # disk_size                    = 30
  # capacity_type                = "ON_DEMAND"
  # max_unavailable_percentage = 33
  # kubernetes_labels            = { ... } # Add custom labels if needed
  # kubernetes_taints            = [ ... ] # Add taints if needed

  # Implicit dependency: Terraform knows this module depends on 'module.vpc' and 'module.eks'.
}

# --- Load Balancer Module Instantiation ---
# ---- LET THE CONTROLLER CREATE THE LB ----
# Creates the Application Load Balancer, Listeners, Target Group, and Security Group.
# Depends on VPC module outputs for network placement.

# module "load_balancer" {
#   source = "../../modules/load-balancer"

#   # --- Module Inputs ---
#   project_name = var.project_name
#   environment  = var.environment
#   tags         = var.common_tags

#   # Inputs from VPC module output:
#   vpc_id            = module.vpc.vpc_id             # LB lives in this VPC
#   public_subnet_ids = module.vpc.public_subnet_ids # Place LB in public subnets

#   # Optional inputs (using module defaults suitable for dev environment):
#   # - internet-facing Application LB
#   # - HTTP listener enabled on port 80
#   # - Default target group created (instance type, port 80)
#   # - Ingress from 0.0.0.0/0 allowed
#   # - No HTTPS, No Access Logs, No Deletion Protection

#   # To enable HTTPS, you would set:
#   # enable_https_listener = true
#   # acm_certificate_arn   = var.lb_acm_certificate_arn # Define this in variables.tf

#   # To enable access logs, you would set:
#   # enable_access_logs          = true
#   # access_logs_s3_bucket_name = var.lb_access_logs_bucket_name # Define this in variables.tf

#   # To change target type for AWS Load Balancer Controller (IP targets), set:
#   # default_target_group_type = "ip"

#   # Implicit dependency: Terraform knows this module depends on 'module.vpc'.
# }