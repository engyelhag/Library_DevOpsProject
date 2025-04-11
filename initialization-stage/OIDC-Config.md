# OIDC Config

## Sources

- [Create an IAM policy and role for Amazon EKS](https://github.com/kubernetes-sigs/aws-efs-csi-driver/blob/master/docs/iam-policy-create.md)
- [AWS EFS CSI Driver](https://github.com/kubernetes-sigs/aws-efs-csi-driver)

---

## Commands

1. **Describe the EKS cluster OIDC issuer**
   ```bash
   aws eks describe-cluster --name cls-eks-cluster --query "cluster.identity.oidc.issuer" --output text
   ```
   Example output:
   ```
   https://oidc.eks.region-code.amazonaws.com/id/EXAMPLED539D4633E53DE1B71EXAMPLE
   ```

2. **Get the thumbprint**
   ```bash
   THUMBPRINT=$(echo | openssl s_client -connect oidc.eks.eu-west-1.amazonaws.com:443 2>/dev/null | openssl x509 -fingerprint -noout | sed 's/://g' | awk -F= '{print tolower($2)}')
   echo $THUMBPRINT
   ```

3. **Create an OIDC provider**
   ```bash
   aws iam create-open-id-connect-provider \
     --url "https://oidc.eks.eu-west-1.amazonaws.com/id/EXAMPLED539D4633E53DE1B71EXAMPLE" \
     --thumbprint-list "$THUMBPRINT" \
     --client-id-list sts.amazonaws.com
   ```

4. **List OIDC providers**
   ```bash
   aws iam list-open-id-connect-providers
   ```

5. **Create `trust-policy.json`**

   Replace `111122223333` with your AWS account ID, `EXAMPLED539D4633E53DE1B71EXAMPLE` with your OIDC ID, and `region-code` with your region.

   ```json
   {
     "Version": "2012-10-17",
     "Statement": [
       {
         "Effect": "Allow",
         "Principal": {
           "Federated": "arn:aws:iam::111122223333:oidc-provider/oidc.eks.region-code.amazonaws.com/id/EXAMPLED539D4633E53DE1B71EXAMPLE"
         },
         "Action": "sts:AssumeRoleWithWebIdentity",
         "Condition": {
           "StringEquals": {
             "oidc.eks.region-code.amazonaws.com/id/EXAMPLED539D4633E53DE1B71EXAMPLE:sub": "system:serviceaccount:kube-system:efs-csi-controller-sa"
           }
         }
       }
     ]
   }
   ```

6. **Create IAM role**
   ```bash
   aws iam create-role \
     --role-name EKS_EFS_CSI_DriverRole \
     --assume-role-policy-document file://"trust-policy.json"
   ```

7. **Download the IAM policy example**
   ```bash
   curl -O https://raw.githubusercontent.com/kubernetes-sigs/aws-efs-csi-driver/master/docs/iam-policy-example.json
   ```

8. **Create IAM policy**
   ```bash
   aws iam create-policy \
     --policy-name EKS_EFS_CSI_Driver_Policy \
     --policy-document file://iam-policy-example.json
   ```

9. **Attach the policy to the role**
   ```bash
   aws iam attach-role-policy \
     --policy-arn arn:aws:iam::111122223333:policy/EKS_EFS_CSI_Driver_Policy \
     --role-name EKS_EFS_CSI_DriverRole
   ```

10. **Create `efs-service-account.yaml`**

    Replace `111122223333` with your AWS account ID.

    ```yaml
    ---
    apiVersion: v1
    kind: ServiceAccount
    metadata:
      labels:
        app.kubernetes.io/name: aws-efs-csi-driver
      name: efs-csi-controller-sa
      namespace: kube-system
      annotations:
        eks.amazonaws.com/role-arn: arn:aws:iam::111122223333:role/EKS_EFS_CSI_DriverRole
    ```

11. **Update kubeconfig**
    ```bash
    aws eks update-kubeconfig --region eu-west-1 --name cls-eks-cluster
    ```

12. **Apply the service account**
    ```bash
    kubectl apply -f efs-service-account.yaml
    ```

13. **Generate the EFS CSI driver deployment manifest**
    ```bash
    kubectl kustomize "github.com/kubernetes-sigs/aws-efs-csi-driver/deploy/kubernetes/overlays/stable/?ref=release-2.1" > public-ecr-driver.yaml
    ```

14. **Edit `public-ecr-driver.yaml`**

    Remove the lines that create a Kubernetes service account:

    ```yaml
    apiVersion: v1
    kind: ServiceAccount
    metadata:
      labels:
        app.kubernetes.io/name: aws-efs-csi-driver
      name: efs-csi-controller-sa
      namespace: kube-system
    ---
    ```

15. **Apply the edited driver manifest**
    ```bash
    kubectl apply -f public-ecr-driver.yaml
    ```

---

## Useful Commands

- **Get ingress URL**
  ```bash
  kubectl get ingress/lib-ingress -n k8s -o jsonpath='{.status.loadBalancer.ingress[0].hostname}'
  ```

- **Start over by cleaning up resources**
  ```bash
  aws iam detach-role-policy \
    --role-name EKS_EFS_CSI_DriverRole \
    --policy-arn arn:aws:iam::195275674678:policy/EKS_EFS_CSI_Driver_Policy

  aws iam delete-role --role-name EKS_EFS_CSI_DriverRole
  ```
