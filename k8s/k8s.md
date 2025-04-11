# Kubernetes Manifests Overview

This directory contains the Kubernetes manifests required to deploy the Simple Website application (Backend + PostgreSQL Database) onto the EKS cluster provisioned by Terraform.

## Structure

The manifests are organized using [Kustomize](https://kustomize.io/) with a base and overlay structure:

* **`base/`**: Contains the common, environment-agnostic resource definitions for the application components.
* **`overlays/dev/`**: Contains Kustomize configurations specific to the `dev` environment. Currently, this overlay mainly inherits from the base but serves as the entry point for dev deployments and allows for future dev-specific customizations (e.g., image tags, replica counts, resource limits).

## Manifest Overview (`base/`)

* **`efs-storageclass.yaml`**: Defines a `StorageClass` named `eks-efs-sc` using the `efs.csi.aws.com` provisioner.
    * Configured for **dynamic provisioning** using EFS Access Points (`provisioningMode: efs-ap`).
    * Requires the EFS `fileSystemId` parameter to be set. This is handled via parameterization (see below).
* **`efs-pvc.yaml`**: Defines a `PersistentVolumeClaim` named `eks-efs-pvc` that requests storage using the `eks-efs-sc` StorageClass. This triggers the EFS CSI driver to dynamically provision an EFS Access Point and make the volume available.
* **`postgres-secret.yaml`**: (Not provided, but assumed) Defines the Kubernetes Secret (`postgres-secret`) containing the database username, password, and database name (`POSTGRES_USER`, `POSTGRES_PASSWORD`, `POSTGRES_DB`). This must be created separately or added here.
* **`postgres.yaml`**: Deploys PostgreSQL as a single-replica (`replicas: 1`) Deployment.
    * Mounts the persistent volume claimed by `eks-efs-pvc` at `/var/lib/postgresql/data`.
    * Uses `securityContext` (UID/GID 999) to align with the default `postgres` user and expected EFS permissions from dynamic provisioning.
    * Retrieves credentials from `postgres-secret`.
* **`postgres-service.yaml`**: Creates a `ClusterIP` service (`postgres-service`) for internal cluster access to the PostgreSQL database pods on port 5432.
* **`backend.yaml`**: Deploys the backend application as a Deployment.
    * Considered stateless (no volumes mounted).
    * Connects to the database using the internal service name (`postgres-service`) via the `DATABASE_URL` environment variable.
    * Retrieves database credentials from `postgres-secret`.
    * The image tag is currently `:latest`; consider using immutable tags for better deployment control.
* **`backend-service.yaml`**: Creates a `ClusterIP` service (`backend-service`) for internal cluster access to the backend application pods on port 5000. This service is targeted by the Ingress resource.
* **`ingress.yaml`**: Defines how external traffic reaches the backend service via the AWS Application Load Balancer (ALB).
    * Uses `spec.ingressClassName: alb` to specify the AWS Load Balancer Controller.
    * Configured for an `internet-facing` scheme.
    * Uses `target-type: ip` (Recommended) to route traffic directly to pod IPs.
    * Routes HTTP traffic for path `/` to the `backend-service` on port `5000`.
    * **Requires specific annotations** to integrate correctly (see Parameterization and Prerequisites).

## Parameterization & Pipeline Integration

To integrate with the specific AWS resources created by Terraform, some values are injected during the CD pipeline (Jenkins):

1.  **EFS Filesystem ID:**
    * The `efs-storageclass.yaml` in `base/` uses the placeholder `${EFS_FILESYSTEM_ID}` for the `fileSystemId` parameter.
    * The Jenkins pipeline retrieves the actual EFS Filesystem ID from the Terraform output (`module.efs.filesystem_id`).
    * It uses `kustomize build k8s/overlays/dev | envsubst '\$EFS_FILESYSTEM_ID' | kubectl apply ...` to substitute this placeholder before applying the manifests.
2.  **Ingress ALB Name (Recommended):**
    * It's recommended to add the annotation `alb.ingress.kubernetes.io/load-balancer-name: ${ALB_NAME}` to `ingress.yaml` (or via a Kustomize patch).
    * The `${ALB_NAME}` (e.g., `simple-website-dev-lb`) should be derived from Terraform (`module.load_balancer.lb_name` or constructed from variables) and passed to/substituted by the pipeline similar to the EFS ID.
3.  **Ingress Certificate ARN (Optional):**
    * If HTTPS is enabled in the Terraform Load Balancer module, the `ingress.yaml` needs the `alb.ingress.kubernetes.io/certificate-arn: ${ACM_CERT_ARN}` annotation.
    * The `${ACM_CERT_ARN}` must be passed from Terraform configuration/output into the pipeline for substitution.

## Prerequisites

For these manifests to function correctly, the following must be installed and configured in the EKS cluster **before** deploying these application manifests:

1.  **AWS Load Balancer Controller:** Must be installed and configured with the necessary IRSA permissions to manage ALBs, Target Groups, and related resources based on Ingress objects.
2.  **EFS CSI Driver:** Must be installed and configured with the necessary IRSA permissions to manage EFS Access Points and mount EFS volumes based on StorageClass and PVC definitions.

## Deployment

These manifests are intended to be deployed via the Jenkins CD pipeline defined in `jenkins/pipelines.md` (refer to that file for the exact steps). The pipeline uses Kustomize to build the configuration for the target environment (e.g., `dev`), `envsubst` to inject parameters from Terraform, and `kubectl apply` to deploy the resources to the EKS cluster into the specified namespace.