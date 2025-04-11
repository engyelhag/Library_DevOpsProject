locals {
  common_tags = merge(var.tags, {
    Project             = var.project_name
    Environment         = var.environment
    ManagedBy           = "Terraform"
    "eks:cluster-name"  = var.cluster_name # Recommended tag for association
    "eks:nodegroup-name"= var.node_group_name
  })

  node_group_name_unique = "${var.cluster_name}-${var.node_group_name}" # Ensure unique name for role/node group resource
}

# --- IAM Role for EKS Worker Nodes ---
data "aws_iam_policy_document" "node_assume_role" {
  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["ec2.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "node" {
  name               = "${local.node_group_name_unique}-node-role"
  assume_role_policy = data.aws_iam_policy_document.node_assume_role.json
  tags               = merge(local.common_tags, { Name = "${local.node_group_name_unique}-node-role" })
}

# --- Attach Required Policies to Node Role ---
resource "aws_iam_role_policy_attachment" "node_AmazonEKSWorkerNodePolicy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSWorkerNodePolicy"
  role       = aws_iam_role.node.name
}

resource "aws_iam_role_policy_attachment" "node_AmazonEKS_CNI_Policy" {
  # Required for IP address management via the VPC CNI plugin
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy"
  role       = aws_iam_role.node.name
}

resource "aws_iam_role_policy_attachment" "node_AmazonEC2ContainerRegistryReadOnly" {
  # Required to pull images from ECR
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
  role       = aws_iam_role.node.name
}

resource "aws_iam_role_policy_attachment" "node_AmazonSSMManagedInstanceCore" {
  # Optional: Allows node access via Session Manager for debugging
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
  role       = aws_iam_role.node.name
}


# --- EKS Managed Node Group ---
resource "aws_eks_node_group" "main" {
  cluster_name    = var.cluster_name
  node_group_name = var.node_group_name # Use the specific group name here
  node_role_arn   = aws_iam_role.node.arn
  subnet_ids      = var.node_subnet_ids
  instance_types  = var.instance_types
  ami_type        = var.ami_type
  disk_size       = var.disk_size
  capacity_type   = var.capacity_type
  version         = var.cluster_version # Use cluster version for node compatibility
  release_version = null # Let EKS determine the latest AMI release for the version/ami_type

  scaling_config {
    desired_size = var.desired_size
    min_size     = var.min_size
    max_size     = var.max_size
  }

  update_config {
    # Ensure max_unavailable is calculated based on percentage
    max_unavailable_percentage = var.max_unavailable_percentage
  }

  labels = merge(
    var.kubernetes_labels # Merge custom labels
  )

  # Convert list of taint objects to the format expected by the resource
  dynamic "taint" {
    for_each = var.kubernetes_taints
    content {
      key    = taint.value.key
      value  = taint.value.value
      effect = taint.value.effect
    }
  }

  # Security Groups: By default, EKS managed node groups use the cluster primary security group.
  # Ensure the cluster SG (from EKS module output) has appropriate rules, e.g., allow traffic
  # to the EFS SG (from EFS module output) on port 2049 if needed. Rules are managed outside this module.

  force_update_version = var.force_update_version

  tags = merge(local.common_tags, {
    Name = local.node_group_name_unique # Apply consistent name tag to underlying ASG/instances
  })

  # Ensure IAM role and policies are ready before creating the node group
  depends_on = [
    aws_iam_role_policy_attachment.node_AmazonEKSWorkerNodePolicy,
    aws_iam_role_policy_attachment.node_AmazonEKS_CNI_Policy,
    aws_iam_role_policy_attachment.node_AmazonEC2ContainerRegistryReadOnly,
    aws_iam_role_policy_attachment.node_AmazonSSMManagedInstanceCore,
  ]
}