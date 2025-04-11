locals {
  common_tags = merge(var.tags, {
    Project     = var.project_name
    Environment = var.environment
    ManagedBy   = "Terraform"
  })
}

# --- IAM Role for EKS Cluster ---
data "aws_iam_policy_document" "cluster_assume_role" {
  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["eks.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "cluster" {
  name               = "${var.cluster_name}-cluster-role"
  assume_role_policy = data.aws_iam_policy_document.cluster_assume_role.json
  tags               = merge(local.common_tags, { Name = "${var.cluster_name}-cluster-role" })
}

resource "aws_iam_role_policy_attachment" "cluster_AmazonEKSClusterPolicy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSClusterPolicy"
  role       = aws_iam_role.cluster.name
}

# Attaching ServiceLinkedRolePolicy is often required for EKS to manage resources like LBs
resource "aws_iam_role_policy_attachment" "cluster_AmazonEKSServicePolicy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSServicePolicy"
  role       = aws_iam_role.cluster.name
}


# --- EKS Cluster ---
resource "aws_eks_cluster" "main" {
  name    = var.cluster_name
  version = var.cluster_version
  role_arn = aws_iam_role.cluster.arn

  vpc_config {
    subnet_ids              = var.subnet_ids
    endpoint_private_access = var.cluster_endpoint_private_access
    endpoint_public_access  = var.cluster_endpoint_public_access
    public_access_cidrs     = var.cluster_endpoint_public_access ? var.cluster_endpoint_public_access_cidrs : []
    security_group_ids      = var.cluster_additional_security_group_ids # EKS creates a primary one automatically
  }

  enabled_cluster_log_types = var.enabled_cluster_log_types

  dynamic "encryption_config" {
    for_each = var.cluster_encryption_config_enabled ? [1] : []
    content {
      provider {
        key_arn = var.cluster_encryption_config_kms_key_arn
      }
      resources = ["secrets"] # Only secrets encryption is supported
    }
  }

  access_config {
    bootstrap_cluster_creator_admin_permissions = var.enable_cluster_creator_admin_permissions
    authentication_mode                         = "API_AND_CONFIG_MAP" # Standard mode
  }


  tags = merge(local.common_tags, {
    Name = var.cluster_name
    # Add specific EKS tags if needed
    # "eksctl.cluster.k8s.io/v1alpha1/cluster-name" = var.cluster_name # Example if mimicking eksctl
  })

  # Ensure IAM role and policies are settled before creating the cluster
  depends_on = [
    aws_iam_role_policy_attachment.cluster_AmazonEKSClusterPolicy,
    aws_iam_role_policy_attachment.cluster_AmazonEKSServicePolicy,
  ]
}


# --- IAM OIDC Provider for IRSA ---
# Allows Kubernetes service accounts to assume IAM roles

resource "aws_iam_openid_connect_provider" "oidc_provider" {
 url             = aws_eks_cluster.main.identity[0].oidc[0].issuer
  client_id_list  = ["sts.amazonaws.com"]
  # thumbprint_list = [data.tls_certificate.eks_oidc_thumbprint.certificates[0].sha1_fingerprint] # If manual thumbprint needed

  tags = merge(local.common_tags, {
    Name = "${var.cluster_name}-oidc-provider"
  })
}