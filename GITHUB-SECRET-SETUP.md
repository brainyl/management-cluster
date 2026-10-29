# GitHub credentials

One GitHub token serves the repositories listed in `github_repos`. Each repository gets its own ArgoCD credential Secret because its URL is different.

| Step | Resource | Responsibility |
| --- | --- | --- |
| 1 | `github_token` in ignored `terraform.tfvars` | Operator supplies a token with read access to every configured repository. |
| 2 | Kubernetes Secret `github-credentials-source` in `crossplane-system` | Terraform places the username/token here for Crossplane to read. |
| 3 | Crossplane `Secret` and `SecretVersion` | Create/update AWS Secrets Manager secret `github-org-credentials` and its value. |
| 4 | `ClusterSecretStore/aws-secretsmanager` | Tells External Secrets Operator where to read; AWS access uses Pod Identity and the ESO workload role. |
| 5 | One `ExternalSecret` per repository | Reads the shared AWS credentials and creates `argocd/github-repo-brainyl-<repository>`. |
| 6 | ArgoCD | Discovers Secrets labeled `argocd.argoproj.io/secret-type: repository` and uses their URL, username, and password for Git authentication. |

## Details that matter

- An **ExternalSecret is a sync instruction**, not the credential itself. ArgoCD reads the resulting Kubernetes Secret.
- The source Kubernetes Secret remains after bootstrap. Credential copies also remain in private Terraform inputs/state, AWS Secrets Manager, and the generated ArgoCD Secrets. The bootstrap does not remove them automatically.
- Every repository, including the first/root repository, needs an ExternalSecret.
- Repository sync uses `refreshPolicy: Periodic` and `refreshInterval: 1h`. Changes in AWS propagate automatically on that interval; they are not immediate. See [ESO refresh policies](https://external-secrets.io/latest/api/externalsecret/#update-behavior-with-3-different-refresh-policies).
- This setup **does not issue or renew GitHub tokens**. Obtain a replacement from GitHub, update private `terraform.tfvars`, and run the bootstrap command. Crossplane updates AWS; ESO refreshes the repository Secrets. Updating AWS directly is not the supported source-of-truth path here.

## Verify without displaying credentials

With the project AWS profile and `.local/kubeconfig` selected:

```bash
kubectl get providers.pkg.crossplane.io
kubectl get secrets.secretsmanager.aws.upbound.io,secretversions.secretsmanager.aws.upbound.io
kubectl get clustersecretstore aws-secretsmanager
kubectl -n argocd get externalsecrets
```

Providers should be healthy, Crossplane resources synced/ready, the store valid, and ExternalSecrets `SecretSynced`. ArgoCD should report successful repository connections. The bootstrap verification also checks root repository rendering.
