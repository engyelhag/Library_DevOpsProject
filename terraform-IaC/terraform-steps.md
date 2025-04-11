# Terraform EKS Project Setup Guide

This guide outlines the steps to build an AWS EKS environment with Terraform, including VPC, EFS, EKS Cluster, Node Groups, and Load Balancer setup.

---

## Directory Structure

Start by creating the following basic directory structure:

```
terraform-IaC/
├── environments/
│   ├── dev/
│   │   ├── main.tf
│   │   ├── variables.tf
│   │   ├── outputs.tf
│   │   └── backend.tf
│   └── prod/
│       ├── main.tf
│       ├── variables.tf
│       ├── outputs.tf
│       └── backend.tf
└── modules/
    ├── vpc/
    │   ├── main.tf
    │   ├── variables.tf
    │   └── outputs.tf
    ├── efs/
    │   ├── main.tf
    │   ├── variables.tf
    │   └── outputs.tf
    ├── eks/
    │   ├── main.tf
    │   ├── variables.tf
    │   └── outputs.tf
    ├── node-group/
    │   ├── main.tf
    │   ├── variables.tf
    │   └── outputs.tf
    └── load-balancer/
        ├── main.tf
        ├── variables.tf
        └── outputs.tf
```

---

## Phase 1: Environment & Foundational Networking (VPC)

### 1. Configure the Development Environment (`environments/dev`)
- Create `backend.tf` for remote state configuration.
- Create `variables.tf` for environment-specific values (region, CIDRs, names, etc.).
- Create `main.tf` to configure the AWS provider.
- Create `outputs.tf` (initially empty or with placeholders).

### 2. Implement the VPC Module (`modules/vpc`)
- Define resources:
  - VPC
  - Public and Private Subnets
  - Internet Gateway (IGW)
  - NAT Gateway(s) with Elastic IP(s)
  - Route Tables and Associations
- Create `variables.tf` to define input variables.
- Create `outputs.tf` to define outputs.

### 3. Integrate the VPC Module
- Add a `module "vpc"` block to `main.tf`.
- Pass required variables from `variables.tf` to the VPC module.

---

## Phase 2: Persistent Storage (EFS)

### 4. Implement the EFS Module (`modules/efs`)
- Define resources:
  - EFS Filesystem
  - Mount Targets (in Private Subnets)
  - EFS Security Group (allowing NFS traffic)
- Create `variables.tf` for input variables (e.g., VPC ID, Private Subnet IDs).
- Create `outputs.tf` to output the EFS filesystem ID and security group ID.

### 5. Integrate the EFS Module
- Add a `module "efs"` block to `main.tf`.
- Pass required variables, including outputs from the `vpc` module.

---

## Phase 3: Kubernetes Control Plane (EKS)

### 6. Implement the EKS Module (`modules/eks`)
- Define resources:
  - EKS Cluster
  - Cluster IAM Role with attached policies
  - OIDC Provider (for IRSA)
- Create `variables.tf` for input variables (e.g., VPC ID, Subnet IDs).
- Create `outputs.tf` to output the Cluster Endpoint, OIDC Provider ARN, Cluster CA Certificate, and Security Group ID.

### 7. Integrate the EKS Module
- Add a `module "eks"` block to `main.tf`.
- Pass required variables, including outputs from the `vpc` module.

---

## Phase 4: Kubernetes Worker Nodes (Node Group)

### 8. Implement the Node Group Module (`modules/node-group`)
- Define resources:
  - Managed Node Group
  - Node Group IAM Role with attached policies
- Create `variables.tf` for input variables (e.g., Cluster Name, Private Subnet IDs).
- Create `outputs.tf` to output Node Group IAM Role ARN and Node Group ID/ARN.

### 9. Integrate the Node Group Module
- Add a `module "node_group"` block to `main.tf`.
- Pass required variables, including outputs from `vpc` and `eks` modules.

---

## Phase 5: Traffic Ingress (Load Balancer)

### 10. Implement the Load Balancer Module (`modules/load-balancer`)
- Define resources:
  - Application Load Balancer (ALB)
  - Target Group(s)
  - Listener(s)
  - Load Balancer Security Group
- Create `variables.tf` for input variables (e.g., VPC ID, Public Subnet IDs).
- Create `outputs.tf` to output Load Balancer DNS Name, Hosted Zone ID, and Security Group ID.

### 11. Integrate the Load Balancer Module
- Add a `module "load_balancer"` block to `main.tf`.
- Pass required variables, including outputs from the `vpc` module.

---

## Phase 6: Finalization

### 12. Finalize Outputs
- Update `environments/dev/outputs.tf` to expose important top-level outputs:
  - Load Balancer DNS Name
  - EKS Cluster Endpoint
  - EFS Filesystem ID
- Reference the appropriate outputs from the respective modules.

---

# Summary

At the end of these phases, you will have a fully functional AWS EKS environment with scalable networking, persistent storage (EFS), managed Kubernetes worker nodes, and an Application Load Balancer ready to serve your applications.

---
