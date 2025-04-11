# Jenkins CI/CD Pipelines Overview

This repository contains two Jenkins pipeline scripts to automate the build and deployment of the **Library Project**.

---

## 1. CI Pipeline (`ci-pipeline.groovy`)

### Purpose:
- Clone the source code from GitHub.
- Build a Docker image.
- Push the Docker image to DockerHub.

### Environment Variables:
| Variable | Description |
| :------ | :----------- |
| `DOCKERHUB_CREDENTIALS_ID` | Jenkins credentials ID for DockerHub authentication. |
| `GITHUB_CREDENTIALS_ID` | Jenkins credentials ID for GitHub authentication. |
| `IMAGE_NAME` | Name of the Docker image to build and push. |
| `IMAGE_TAG` | Docker image tag (default: `latest`). |

### Stages:
1. **Clone Repository**
   - Pulls code from GitHub (branch: `main`).
2. **Build Docker Image**
   - Builds a Docker image from the repository.
3. **Push Docker Image**
   - Pushes the built Docker image to DockerHub.

---

## 2. CD Pipeline (`cd-pipeline.groovy`)

### Purpose:
- Clone the source code from GitHub.
- Set up Kubernetes (EKS) namespace and certificates.
- Deploy the application to EKS using Kustomize.

### Environment Variables:
| Variable | Description |
| :------ | :----------- |
| `K8S_NAMESPACE` | Kubernetes namespace to deploy into (default: `k8s`). |
| `IMAGE_NAME` | Name of the Docker image to deploy. |
| `IMAGE_TAG` | Docker image tag (default: `latest`). |
| `EFS_FILESYSTEM_ID` | Amazon EFS Filesystem ID for storage. |

### Prerequisites:
- Jenkins must have the `aws-credentials` configured.
- Jenkins agent must have `kubectl`, `awscli`, `kustomize`, and `envsubst` installed.

### Stages:
1. **Clone Repository**
   - Pulls code from GitHub (branch: `main`).
2. **Generate Kubeconfig**
   - Creates a temporary kubeconfig for cluster access.
3. **Create Namespace**
   - Creates the Kubernetes namespace if it doesn't exist.
4. **Apply Kube CRT in K8S**
   - Ensures the `kube-root-ca.crt` ConfigMap is available in the namespace.
5. **Deploy to EKS Using Kustomize**
   - Builds and applies manifests using Kustomize.
   - Substitutes `EFS_FILESYSTEM_ID` where needed.
6. **Verify Deployment**
   - Monitors the deployment rollout.
   - Prints the LoadBalancer or Ingress endpoint.

### Post Actions:
- On success: prints a success message.
- On failure: logs failure.
- Always: cleans up the temporary kubeconfig file.

---

## Notes:
- Replace placeholder `EFS_FILESYSTEM_ID` (`fs-xxxxxxxxxxxxxxxxx`) with your actual EFS ID before running the CD pipeline.
- Uncomment and configure the `Update Deployment Manifest` stage if dynamic image tagging is needed.
- Ensure required tools (`kubectl`, `kustomize`, `envsubst`) are available on the Jenkins agent.

---

## Useful Links:
- [IAM policy & role setup for EKS](https://github.com/kubernetes-sigs/aws-efs-csi-driver/blob/master/docs/iam-policy-create.md)
- [Install AWS EFS CSI Driver](https://github.com/kubernetes-sigs/aws-efs-csi-driver)
