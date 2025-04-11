locals {
  common_tags = merge(var.tags, {
    Project     = var.project_name
    Environment = var.environment
    ManagedBy   = "Terraform"
  })
}

# --- EFS Filesystem ---
resource "aws_efs_file_system" "main" {
  creation_token = "${var.project_name}-${var.environment}-efs" # Ensures idempotency
  encrypted      = true                                         # Enable encryption at rest (default KMS key)
  performance_mode = var.efs_performance_mode
  throughput_mode  = var.efs_throughput_mode
  provisioned_throughput_in_mibps = var.efs_throughput_mode == "provisioned" ? var.efs_provisioned_throughput_in_mibps : null

  dynamic "lifecycle_policy" {
    for_each = var.enable_lifecycle_policy ? [1] : []
    content {
      transition_to_ia = var.lifecycle_transition_to_ia
      # transition_to_primary_storage_class = "AFTER_1_ACCESS" # Optionally move back from IA on access
    }
  }

  tags = merge(local.common_tags, {
    Name = "${var.project_name}-${var.environment}-efs"
  })
}

# --- EFS Backup Policy ---
# Note: Requires AWS Backup service opt-in for the region/account.
resource "aws_efs_backup_policy" "policy" {
  count = var.enable_backup_policy ? 1 : 0

  file_system_id = aws_efs_file_system.main.id

  backup_policy {
    status = "ENABLED"
  }
}


# --- Security Group for EFS Mount Targets ---
resource "aws_security_group" "efs_mount_target" {
  name        = "${var.project_name}-${var.environment}-efs-sg"
  description = "Allow NFS traffic to EFS mount targets"
  vpc_id      = var.vpc_id

  tags = merge(local.common_tags, {
    Name = "${var.project_name}-${var.environment}-efs-sg"
  })
}

# --- Security Group Rules ---

# Ingress Rule: Allow NFS (TCP 2049) from specified sources

# Rule 1: Allow from VPC CIDR (if allowed_security_groups is empty)
resource "aws_security_group_rule" "allow_nfs_from_vpc" {
  count = length(var.allowed_security_groups) == 0 ? 1 : 0

  type              = "ingress"
  protocol          = "tcp"
  from_port         = 2049 # NFS port
  to_port           = 2049 # NFS port
  cidr_blocks       = [var.vpc_cidr_block]
  security_group_id = aws_security_group.efs_mount_target.id
  description       = "Allow NFS traffic from within the VPC"
}

# Rule 2: Allow from specific Security Groups (if provided)
resource "aws_security_group_rule" "allow_nfs_from_sg" {
  for_each = toset(var.allowed_security_groups) # Use for_each for lists

  type                     = "ingress"
  protocol                 = "tcp"
  from_port                = 2049 # NFS port
  to_port                  = 2049 # NFS port
  source_security_group_id = each.value
  security_group_id        = aws_security_group.efs_mount_target.id
  description              = "Allow NFS traffic from specific SG ${each.value}"
}


# Egress Rule: Allow all outbound traffic (generally needed for EFS operations)
resource "aws_security_group_rule" "allow_all_outbound" {
  type              = "egress"
  protocol          = "-1" # All protocols
  from_port         = 0
  to_port           = 0
  cidr_blocks       = ["0.0.0.0/0"]
  security_group_id = aws_security_group.efs_mount_target.id
  description       = "Allow all outbound traffic"
}

# --- EFS Mount Targets ---
# Create one mount target for each private subnet provided
resource "aws_efs_mount_target" "main" {
  # Use for_each keyed by subnet ID for stable management
  for_each = { for k, v in var.private_subnet_ids : k => v }

  file_system_id  = aws_efs_file_system.main.id
  subnet_id       = each.value
  security_groups = [aws_security_group.efs_mount_target.id]

  # Mount targets implicitly depend on the filesystem and SG.
  # Explicit dependency can be added if needed, but usually not required here.
  # depends_on = [aws_efs_file_system.main, aws_security_group.efs_mount_target]
}