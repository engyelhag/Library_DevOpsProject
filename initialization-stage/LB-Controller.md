# Load Balancer Controller Setup

**Resources:**  
- [AWS EKS Load Balancer Controller Documentation](https://docs.aws.amazon.com/eks/latest/userguide/lbc-manifest.html)

---

## Steps

1. Download the IAM policy document:

   ```bash
   curl -O https://raw.githubusercontent.com/kubernetes-sigs/aws-load-balancer-controller/v2.11.0/docs/install/iam_policy.json
   ```

2. Create the IAM policy:

   ```bash
   aws iam create-policy \
     --policy-name AWSLoadBalancerControllerIAMPolicy \
     --policy-document file://iam_policy.json
   ```

3. Get the OIDC ID for your cluster:

   ```bash
   oidc_id=$(aws eks describe-cluster --name cls-eks-cluster --query "cluster.identity.oidc.issuer" --output text | cut -d '/' -f 5)
   ```

4. Verify the OIDC provider:

   ```bash
   aws iam list-open-id-connect-providers | grep $oidc_id | cut -d "/" -f4
   ```

5. Create a trust policy file:

   ```bash
   cat >load-balancer-role-trust-policy.json <<EOF
   {
     "Version": "2012-10-17",
     "Statement": [
       {
         "Effect": "Allow",
         "Principal": {
           "Federated": "arn:aws:iam::111122223333:oidc-provider/oidc.eks.eu-west-1.amazonaws.com/id/EXAMPLED539D4633E53DE1B71EXAMPLE"
         },
         "Action": "sts:AssumeRoleWithWebIdentity",
         "Condition": {
           "StringEquals": {
             "oidc.eks.eu-west-1.amazonaws.com/id/EXAMPLED539D4633E53DE1B71EXAMPLE:aud": "sts.amazonaws.com",
             "oidc.eks.eu-west-1.amazonaws.com/id/EXAMPLED539D4633E53DE1B71EXAMPLE:sub": "system:serviceaccount:kube-system:aws-load-balancer-controller"
           }
         }
       }
     ]
   }
   EOF
   ```

6. Create the IAM role:

   ```bash
   aws iam create-role \
     --role-name AmazonEKSLoadBalancerControllerRole \
     --assume-role-policy-document file://"load-balancer-role-trust-policy.json"
   ```

7. Attach the policy to the role:

   ```bash
   aws iam attach-role-policy \
     --policy-arn arn:aws:iam::111122223333:policy/AWSLoadBalancerControllerIAMPolicy \
     --role-name AmazonEKSLoadBalancerControllerRole
   ```

8. Create the Kubernetes service account:

   ```bash
   cat >aws-load-balancer-controller-service-account.yaml <<EOF
   apiVersion: v1
   kind: ServiceAccount
   metadata:
     labels:
       app.kubernetes.io/component: controller
       app.kubernetes.io/name: aws-load-balancer-controller
     name: aws-load-balancer-controller
     namespace: kube-system
     annotations:
       eks.amazonaws.com/role-arn: arn:aws:iam::111122223333:role/AmazonEKSLoadBalancerControllerRole
   EOF
   ```

9. Apply the service account:

   ```bash
   kubectl apply -f aws-load-balancer-controller-service-account.yaml
   ```

10. Install cert-manager:

    ```bash
    kubectl apply \
      --validate=false \
      -f https://github.com/jetstack/cert-manager/releases/download/v1.13.5/cert-manager.yaml
    ```

11. Download the AWS Load Balancer Controller manifest:

    ```bash
    curl -Lo v2_11_0_full.yaml https://github.com/kubernetes-sigs/aws-load-balancer-controller/releases/download/v2.11.0/v2_11_0_full.yaml
    ```

12. Remove unnecessary lines (690-698):

    ```bash
    sed -i.bak -e '690,698d' ./v2_11_0_full.yaml
    ```

13. Update the manifest with your cluster name:

    ```bash
    sed -i.bak -e 's|your-cluster-name|cls-eks-cluster|' ./v2_11_0_full.yaml
    ```

14. Apply the manifest:

    ```bash
    kubectl apply -f v2_11_0_full.yaml
    ```

15. Download the ingress class manifest:

    ```bash
    curl -Lo v2_11_0_ingclass.yaml https://github.com/kubernetes-sigs/aws-load-balancer-controller/releases/download/v2.11.0/v2_11_0_ingclass.yaml
    ```

16. Apply the ingress class manifest:

    ```bash
    kubectl apply -f v2_11_0_ingclass.yaml
    ```

---
