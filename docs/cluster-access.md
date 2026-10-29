# Root Kubernetes access

The EKS Terraform module automatically grants the Terraform caller's persistent IAM identity cluster-administrator access. Access is provisioned with the cluster; no manual access-entry creation or `aws-auth` edit is needed.

AWS console resource visibility requires both AWS permissions, including `eks:AccessKubernetesApi`, and Kubernetes authorization. Sign in with the identity granted access by Terraform. An assumed-role session and the underlying IAM role are different identifiers; access entries use the persistent IAM role ARN.

With the root kubeconfig selected:

```bash
kubectl auth can-i get pods --all-namespaces
kubectl get nodes
kubectl get pods --all-namespaces
```

SSO renewal does not change the role identity. If that role is deleted and recreated, review its access entry through Terraform.

References: [AWS console resource access](https://docs.aws.amazon.com/eks/latest/userguide/view-kubernetes-resources.html), [EKS access policies](https://docs.aws.amazon.com/eks/latest/userguide/access-policy-permissions.html).
